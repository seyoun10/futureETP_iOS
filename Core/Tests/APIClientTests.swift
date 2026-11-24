import Core
import Foundation
import Testing

/// 받은 요청을 모으고 정해 둔 응답을 차례로 돌려주는 가짜 전송
private actor FakeTransport {
  enum Reply {
    case body(Int, String)
    case failure(any Error)
    case hang
  }

  private var replies: [Reply]
  private(set) var requests: [URLRequest] = []

  init(_ replies: [Reply]) {
    self.replies = replies
  }

  func handle(_ request: URLRequest) async throws -> (Data, URLResponse) {
    requests.append(request)
    let reply = replies.count > 1 ? replies.removeFirst() : replies[0]
    switch reply {
    case .body(let status, let body):
      let response = HTTPURLResponse(
        url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
      return (Data(body.utf8), response)
    case .failure(let error):
      throw error
    case .hang:
      try await Task.sleep(for: .seconds(60))
      throw CancellationError()
    }
  }
}

private struct Price: Decodable, Sendable, Equatable {
  let price: Double
}

private struct LocalePatch: Encodable, Sendable {
  let locale: String
}

private let deviceID = "00000000-0000-4000-8000-000000000001"
private let ok = #"{"success":true,"data":{"price":1.5}}"#

private func client(
  _ transport: FakeTransport, token: String? = "dev-token", timeout: Duration = .seconds(15)
) -> APIClient {
  APIClient(
    baseURL: URL(string: "http://api.test")!,
    accessToken: { token },
    deviceID: { deviceID },
    transport: { try await transport.handle($0) },
    timeout: timeout,
    retryDelay: { _ in .zero }
  )
}

private func appError(_ body: () async throws -> Void) async -> AppError? {
  do {
    try await body()
    return nil
  } catch {
    return error as? AppError
  }
}

struct APIClientTests {
  @Test func returnsDataWithHeadersAndQuery() async throws {
    let transport = FakeTransport([.body(200, ok)])
    let price = try await client(transport).send(
      APIRequest(
        "/commodities/GC/disparity",
        query: [URLQueryItem(name: "basis", value: "KR"), URLQueryItem(name: "ma", value: "200")],
        as: Price.self))
    #expect(price == Price(price: 1.5))

    let request = try #require(await transport.requests.first)
    #expect(
      request.url?.absoluteString == "http://api.test/v1/commodities/GC/disparity?basis=KR&ma=200")
    #expect(request.httpMethod == "GET")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer dev-token")
    #expect(request.value(forHTTPHeaderField: "X-Device-Id") == deviceID)
    #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
  }

  @Test func sendsBodyAsJSON() async throws {
    let transport = FakeTransport([.body(200, ok)])
    _ = try await client(transport).send(
      APIRequest("/settings", method: .patch, body: LocalePatch(locale: "ko"), as: Price.self))
    let request = try #require(await transport.requests.first)
    #expect(request.httpMethod == "PATCH")
    #expect(request.httpBody == Data(#"{"locale":"ko"}"#.utf8))
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
  }

  @Test func skipsAuthHeadersWhenAuthIsFalse() async throws {
    let transport = FakeTransport([.body(200, ok)])
    _ = try await client(transport, token: nil).send(
      APIRequest("/health", auth: false, as: Price.self))
    let request = try #require(await transport.requests.first)
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(request.value(forHTTPHeaderField: "X-Device-Id") == nil)
  }

  @Test func tokenOverrideReplacesStoredKey() async throws {
    let transport = FakeTransport([.body(200, ok)])
    _ = try await client(transport, token: nil).send(
      APIRequest("/settings", token: "new-key", as: Price.self))
    let request = try #require(await transport.requests.first)
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer new-key")
  }

  @Test(arguments: [nil, ""])
  func missingKeyFailsWithoutRequest(token: String?) async {
    let transport = FakeTransport([.body(200, ok)])
    let error = await appError {
      _ = try await client(transport, token: token).send(APIRequest("/settings", as: Price.self))
    }
    #expect(error?.code == .unauthorized)
    #expect(await transport.requests.isEmpty)
  }

  @Test func errorEnvelopeKeepsCodeStatusAndMessage() async {
    let transport = FakeTransport([
      .body(404, #"{"success":false,"error":{"code":"NOT_FOUND","message":"no ETP"}}"#)
    ])
    let error = await appError {
      _ = try await client(transport).send(APIRequest("/etps/1", as: Price.self))
    }
    #expect(error == AppError(.notFound, status: 404, message: "no ETP"))
  }

  @Test func dataMismatchIsSchemaMismatch() async {
    let transport = FakeTransport([.body(200, #"{"success":true,"data":{"price":"1.5"}}"#)])
    let error = await appError {
      _ = try await client(transport).send(APIRequest("/x", as: Price.self))
    }
    #expect(error?.code == .schemaMismatch)
    #expect(error?.status == 200)
  }

  @Test(arguments: [
    (502, "<html>Bad Gateway</html>", AppError.Code.internal),
    (200, "<html></html>", .schemaMismatch),
    // 모르는 에러 코드(서버가 더 새 버전)
    (418, #"{"success":false,"error":{"code":"TEAPOT","message":"x"}}"#, .schemaMismatch),
    // 앱 전용 코드는 서버가 보내지 않는다
    (500, #"{"success":false,"error":{"code":"NETWORK","message":"x"}}"#, .schemaMismatch),
  ])
  func nonEnvelopeBodies(status: Int, body: String, code: AppError.Code) async {
    let transport = FakeTransport([.body(status, body)])
    let error = await appError {
      _ = try await client(transport).send(APIRequest("/x", method: .patch, as: Price.self))
    }
    #expect(error?.code == code)
    #expect(error?.status == status)
  }

  @Test func transportFailureIsNetwork() async {
    let transport = FakeTransport([.failure(URLError(.notConnectedToInternet))])
    let error = await appError {
      _ = try await client(transport).send(APIRequest("/x", method: .put, as: Price.self))
    }
    #expect(error?.code == .network)
  }

  @Test func urlSessionTimeoutIsTimeout() async {
    let transport = FakeTransport([.failure(URLError(.timedOut))])
    let error = await appError {
      _ = try await client(transport).send(APIRequest("/x", method: .put, as: Price.self))
    }
    #expect(error?.code == .timeout)
  }

  @Test func slowResponseIsTimeout() async {
    let transport = FakeTransport([.hang])
    let error = await appError {
      _ = try await client(transport, timeout: .milliseconds(50)).send(
        APIRequest("/x", method: .put, as: Price.self))
    }
    #expect(error?.code == .timeout)
  }

  @Test func callerCancellationIsNotAppError() async {
    let transport = FakeTransport([.hang])
    let task = Task {
      try await client(transport).send(APIRequest("/x", as: Price.self))
    }
    while await transport.requests.isEmpty { await Task.yield() }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(await transport.requests.count == 1)
  }

  @Test func retriesRetryableGetUpToTwice() async throws {
    let internalError = #"{"success":false,"error":{"code":"INTERNAL","message":"x"}}"#
    let transport = FakeTransport([
      .failure(URLError(.networkConnectionLost)), .body(500, internalError), .body(200, ok),
    ])
    let price = try await client(transport).send(APIRequest("/x", as: Price.self))
    #expect(price == Price(price: 1.5))
    #expect(await transport.requests.count == 3)
  }

  @Test func givesUpAfterTwoRetries() async {
    let transport = FakeTransport([.failure(URLError(.notConnectedToInternet))])
    let error = await appError {
      _ = try await client(transport).send(APIRequest("/x", as: Price.self))
    }
    #expect(error?.code == .network)
    #expect(await transport.requests.count == 3)
  }

  @Test(arguments: [
    (APIMethod.patch, 500, "INTERNAL"),
    (.put, 500, "INTERNAL"),
    (.get, 404, "NOT_FOUND"),
    (.get, 429, "RATE_LIMITED"),
  ])
  func doesNotRetry(method: APIMethod, status: Int, code: String) async {
    let body = #"{"success":false,"error":{"code":"\#(code)","message":"x"}}"#
    let transport = FakeTransport([.body(status, body)])
    _ = await appError {
      _ = try await client(transport).send(APIRequest("/x", method: method, as: Price.self))
    }
    #expect(await transport.requests.count == 1)
  }
}
