import Foundation

/// `GET /v1/health` 응답 `data` (계약 `schemas/health.json`)
public struct Health: Decodable, Sendable, Equatable {
  /// 계약상 항상 `"ok"`
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

public struct LiveHealthRepository: HealthRepository {
  private let client: APIClient

  public init(client: APIClient) {
    self.client = client
  }

  public func fetch() async throws -> Health {
    let health = try await client.send(APIRequest("/health", auth: false, as: Health.self))
    // 계약의 const "ok"를 벗어나면 모델 불일치다 (D-042)
    guard health.status == "ok" else {
      throw AppError(.schemaMismatch, message: "health.status is \(health.status)")
    }
    return health
  }
}
