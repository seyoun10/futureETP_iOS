import Foundation

/// `GET /v1/health` 응답 `data` (계약 `schemas/health.json`)
public struct Health: Decodable, Sendable, Equatable {
  public let status: String
  public let commit: String?

  public init(status: String, commit: String?) {
    self.status = status
    self.commit = commit
  }
}

/// 서버 연결 확인. 인증 헤더 없이 부른다 (D-036)
public protocol HealthRepository: Sendable {
  func fetch() async throws -> Health
}

/// 2단계 연결 확인용 최소 구현. 3단계 API client가 생기면 그쪽으로 옮긴다
public struct LiveHealthRepository: HealthRepository {
  public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

  private let baseURL: URL
  private let transport: Transport

  public init(
    baseURL: URL,
    transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }
  ) {
    self.baseURL = baseURL
    self.transport = transport
  }

  public func fetch() async throws -> Health {
    var request = URLRequest(url: baseURL.appending(path: "v1/health"), timeoutInterval: 15)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let (data, _) = try await transport(request)
    let envelope = try JSONDecoder().decode(Envelope.self, from: data)
    guard envelope.success, let health = envelope.data, health.status == "ok" else {
      throw HealthError.notOK
    }
    return health
  }

  private struct Envelope: Decodable {
    let success: Bool
    let data: Health?
  }
}

public enum HealthError: Error, Equatable {
  case notOK
}
