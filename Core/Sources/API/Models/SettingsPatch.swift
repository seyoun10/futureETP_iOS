import Foundation

/// `PATCH /v1/settings` 본문 (계약 `schemas/settingsPatch.json`, D-081). 바꿀 필드만 보낸다.
/// nil 필드는 보내지 않는다. `alertCommodity`·`quietTime`은 `.some(nil)`이면 `null`(끄기)을 보낸다
public struct SettingsPatch: Encodable, Sendable, Equatable {
  public var locale: AppLanguage?
  /// IANA 시간대 (D-084)
  public var timezone: String?
  public var basis: Basis?
  public var maPeriod: MAPeriod?
  public var window: DistributionWindow?
  public var rareLevels: RareLevels?
  public var alertCommodity: CommodityCode??
  public var quietTime: QuietTime??

  public init(
    locale: AppLanguage? = nil,
    timezone: String? = nil,
    basis: Basis? = nil,
    maPeriod: MAPeriod? = nil,
    window: DistributionWindow? = nil,
    rareLevels: RareLevels? = nil,
    alertCommodity: CommodityCode?? = nil,
    quietTime: QuietTime?? = nil
  ) {
    self.locale = locale
    self.timezone = timezone
    self.basis = basis
    self.maPeriod = maPeriod
    self.window = window
    self.rareLevels = rareLevels
    self.alertCommodity = alertCommodity
    self.quietTime = quietTime
  }

  private enum CodingKeys: String, CodingKey {
    case locale, timezone, basis, maPeriod, window, rareLevels, alertCommodity, quietTime
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(locale, forKey: .locale)
    try container.encodeIfPresent(timezone, forKey: .timezone)
    try container.encodeIfPresent(basis, forKey: .basis)
    try container.encodeIfPresent(maPeriod, forKey: .maPeriod)
    try container.encodeIfPresent(window, forKey: .window)
    try container.encodeIfPresent(rareLevels, forKey: .rareLevels)
    // 바깥 Optional만 벗긴다. 안쪽 nil은 JSON null로 나간다
    if let alertCommodity { try container.encode(alertCommodity, forKey: .alertCommodity) }
    if let quietTime { try container.encode(quietTime, forKey: .quietTime) }
  }
}

extension QuietTime {
  public static let stepMinutes = 30
  public static let maxMinute = 24 * 60 - stepMinutes

  /// PATCH 규칙(원본 `quietTimeSchema`): 0...1410, 30분 단위, 시작과 끝이 달라야 한다. 자정 넘김은 허용
  public var isValidForPatch: Bool {
    let valid = { (minute: Int) in
      (0...Self.maxMinute).contains(minute) && minute % Self.stepMinutes == 0
    }
    return valid(startMin) && valid(endMin) && startMin != endMin
  }
}
