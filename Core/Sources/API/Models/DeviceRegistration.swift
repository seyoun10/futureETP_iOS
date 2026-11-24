import Foundation

/// `PUT /v1/devices` 본문 (계약 `schemas/deviceRegistration.json`, D-048, D-120). 세 필드 모두 늘 보내고 없으면 `null`이다
public struct DeviceRegistration: Encodable, Sendable, Equatable {
  public static let pushTokenMaxLength = 4096
  public static let appVersionMaxLength = 64

  /// APNs 기기 토큰(hex). 못 받으면 nil (D-037)
  public let pushToken: String?
  public let platform: Platform
  /// `ios-<버전>` (IOS-002). 모르면 nil
  public let appVersion: String?

  /// - Parameters:
  ///   - pushToken: 앞뒤 공백을 지우고, 비었거나 4096자를 넘으면 nil로 보낸다
  ///   - version: 앱 버전(`CFBundleShortVersionString`). `ios-` 접두사를 붙이고, 64자를 넘으면 nil로 보낸다
  public init(pushToken: String?, version: String?) {
    let token = pushToken?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.pushToken =
      if let token, !token.isEmpty, token.count <= Self.pushTokenMaxLength { token } else { nil }
    platform = .ios
    let appVersion = version.map { "ios-\($0)" }
    self.appVersion =
      if let appVersion, appVersion.count <= Self.appVersionMaxLength { appVersion } else { nil }
  }

  private enum CodingKeys: String, CodingKey {
    case pushToken, platform, appVersion
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    // encodeIfPresent가 아니라 encode: nil도 null로 보낸다(필수 필드)
    try container.encode(pushToken, forKey: .pushToken)
    try container.encode(platform, forKey: .platform)
    try container.encode(appVersion, forKey: .appVersion)
  }
}
