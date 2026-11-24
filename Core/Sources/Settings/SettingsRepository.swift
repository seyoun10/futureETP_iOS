import Foundation

/// 서버 설정 `GET`·`PATCH /v1/settings` (D-081, D-120 기기별)
public protocol SettingsRepository: Sendable {
  func fetch() async throws -> AppSettings
  /// 변경 요청이라 자동 재시도하지 않는다 (D-072). 응답은 반영 뒤 서버 값이다
  func update(_ patch: SettingsPatch) async throws -> AppSettings
}

public struct LiveSettingsRepository: SettingsRepository {
  private let client: APIClient

  public init(client: APIClient) {
    self.client = client
  }

  public func fetch() async throws -> AppSettings {
    try await client.send(APIRequest("/settings", as: AppSettings.self))
  }

  public func update(_ patch: SettingsPatch) async throws -> AppSettings {
    try await client.send(
      APIRequest("/settings", method: .patch, body: patch, as: AppSettings.self))
  }
}
