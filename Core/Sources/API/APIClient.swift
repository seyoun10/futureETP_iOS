import Foundation

/// HTTP 메서드. API에 쓰는 것만 둔다
public enum APIMethod: String, Sendable {
  case get = "GET"
  case patch = "PATCH"
  case put = "PUT"
}

/// API 요청 하나. 경로는 `/v1` 뒤 부분(`/commodities`)이다
public struct APIRequest<Response: Decodable & Sendable>: Sendable {
  public let method: APIMethod
  public let path: String
  public let query: [URLQueryItem]
  public let body: (any Encodable & Sendable)?
  /// false면 `Authorization`·`X-Device-Id` 없이 보낸다(`/v1/health`, D-036)
  public let auth: Bool
  /// 저장된 키 대신 보낼 키(B-b에서 저장 전 확인, D-044)
  public let token: String?

  public init(
    _ path: String,
    method: APIMethod = .get,
    query: [URLQueryItem] = [],
    body: (any Encodable & Sendable)? = nil,
    auth: Bool = true,
    token: String? = nil,
    as: Response.Type = Response.self
  ) {
    self.method = method
    self.path = path
    self.query = query
    self.body = body
    self.auth = auth
    self.token = token
  }
}

/// 모든 API 호출의 유일한 경로 (D-042, D-072). 실패는 `AppError`로 던지고, 호출자 취소만 `CancellationError`로 던진다.
/// 캐시는 repository가 맡는다
public struct APIClient: Sendable {
  public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

  public static let deviceIDHeader = "X-Device-Id"

  private let baseURL: URL
  private let accessToken: @Sendable () async -> String?
  private let deviceID: @Sendable () async -> String
  private let transport: Transport
  private let timeout: Duration
  private let retryDelay: @Sendable (_ attempt: Int) -> Duration

  /// - Parameters:
  ///   - accessToken: 저장된 접근 키. 없으면 nil
  ///   - deviceID: installation ID (D-120)
  ///   - timeout: 요청 하나의 전체 시간 제한. 기본 15초
  ///   - retryDelay: n번째 재시도 전 대기. 기본은 TanStack Query와 같이 1초, 2초
  public init(
    baseURL: URL,
    accessToken: @escaping @Sendable () async -> String?,
    deviceID: @escaping @Sendable () async -> String,
    transport: @escaping Transport = { try await URLSession.shared.data(for: $0) },
    timeout: Duration = .seconds(15),
    retryDelay: @escaping @Sendable (_ attempt: Int) -> Duration = {
      .seconds(min(1 << ($0 - 1), 30))
    }
  ) {
    self.baseURL = baseURL
    self.accessToken = accessToken
    self.deviceID = deviceID
    self.transport = transport
    self.timeout = timeout
    self.retryDelay = retryDelay
  }

  /// 조회(GET)는 `NETWORK`·`TIMEOUT`·`INTERNAL`이면 최대 2회 다시 보낸다. 변경 요청은 다시 보내지 않는다 (D-072)
  public func send<Response>(_ request: APIRequest<Response>) async throws -> Response {
    let maxRetries = request.method == .get ? 2 : 0
    var attempt = 0
    while true {
      do {
        return try await sendOnce(request)
      } catch let error as AppError where error.isRetryable && attempt < maxRetries {
        attempt += 1
        try await Task.sleep(for: retryDelay(attempt))
      }
    }
  }

  private func sendOnce<Response>(_ request: APIRequest<Response>) async throws -> Response {
    let urlRequest = try await makeURLRequest(request)
    let (data, response) = try await transportWithTimeout(urlRequest)
    let status = (response as? HTTPURLResponse)?.statusCode
    return try decode(Response.self, from: data, status: status, path: request.path)
  }

  private func makeURLRequest<Response>(_ request: APIRequest<Response>) async throws
    -> URLRequest
  {
    var url = baseURL.appending(path: "v1" + request.path)
    if !request.query.isEmpty { url.append(queryItems: request.query) }
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = request.method.rawValue
    urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
    if request.auth {
      // 키가 없으면 보내도 401이라 요청하지 않는다 (D-072)
      guard let token = await resolvedToken(request.token) else {
        throw AppError(.unauthorized, message: "No access token")
      }
      urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      urlRequest.setValue(await deviceID(), forHTTPHeaderField: Self.deviceIDHeader)
    }
    if let body = request.body {
      urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
      urlRequest.httpBody = try JSONEncoder().encode(body)
    }
    return urlRequest
  }

  private func resolvedToken(_ override: String?) async -> String? {
    let token = if let override { override } else { await accessToken() }
    return token?.isEmpty == false ? token : nil
  }

  private func transportWithTimeout(_ request: URLRequest) async throws -> (Data, URLResponse) {
    let transport = transport
    let timeout = timeout
    do {
      return try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
        group.addTask { try await transport(request) }
        group.addTask {
          try await Task.sleep(for: timeout)
          throw AppError(.timeout, message: "Timed out after \(timeout)")
        }
        defer { group.cancelAll() }
        return try await group.next()!
      }
    } catch let error as AppError {
      throw error
    } catch {
      if Task.isCancelled { throw CancellationError() }
      if let urlError = error as? URLError, urlError.code == .timedOut {
        throw AppError(.timeout, message: urlError.localizedDescription)
      }
      throw AppError(.network, message: String(describing: error))
    }
  }

  private func decode<Response: Decodable>(
    _ type: Response.Type, from data: Data, status: Int?, path: String
  ) throws -> Response {
    let decoder = JSONDecoder()
    guard let head = try? decoder.decode(EnvelopeHead.self, from: data) else {
      // 프록시 오류(502 HTML 등)처럼 봉투가 아닌 응답은 HTTP 상태로 나눈다 (D-042)
      throw AppError(
        (status ?? 0) >= 500 ? .internal : .schemaMismatch, status: status,
        message: "Unexpected response body (HTTP \(status.map(String.init) ?? "?"))")
    }
    guard head.success else {
      // 모르는 에러 코드(서버가 더 새 버전)도 봉투 불일치다
      guard let failure = try? decoder.decode(Failure.self, from: data),
        AppError.Code.server.contains(failure.error.code)
      else {
        throw AppError(.schemaMismatch, status: status, message: "Unknown error envelope")
      }
      throw AppError(failure.error.code, status: status, message: failure.error.message)
    }
    do {
      return try decoder.decode(Success<Response>.self, from: data).data
    } catch {
      throw AppError(
        .schemaMismatch, status: status,
        message: "Response data does not match schema: \(path) (\(error))")
    }
  }

  private struct EnvelopeHead: Decodable {
    let success: Bool
  }

  private struct Success<T: Decodable>: Decodable {
    let data: T
  }

  private struct Failure: Decodable {
    struct Body: Decodable {
      let code: AppError.Code
      let message: String
    }
    let error: Body
  }
}
