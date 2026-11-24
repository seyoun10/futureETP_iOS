import Foundation

/// 입력한 키를 저장하기 전에 서버가 받는지 확인한다 (D-044, D-081)
public protocol AccessKeyVerifier: Sendable {
  /// 받으면 그냥 끝나고, 거절하면 `AppError(.unauthorized)`를 던진다
  func verify(_ key: String) async throws
}

/// `GET /v1/settings`를 저장된 키 대신 `key`로 한 번 부른다
public struct LiveAccessKeyVerifier: AccessKeyVerifier {
  private let client: APIClient

  public init(client: APIClient) {
    self.client = client
  }

  public func verify(_ key: String) async throws {
    _ = try await client.send(APIRequest("/settings", token: key, as: AppSettings.self))
  }
}
