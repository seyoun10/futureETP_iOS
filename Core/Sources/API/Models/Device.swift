import Foundation

/// `PUT /v1/devices` 응답 `data` (계약 `schemas/device.json`, D-048, D-120)
public struct Device: Codable, Sendable, Equatable, Identifiable {
  /// 서버 기기 행 id. `X-Device-Id`와 같은 값이다
  public let id: UUID
}
