import Foundation

/// `GET`·`PATCH /v1/settings` 응답 `data` (계약 `schemas/settings.json`, D-081).
/// SwiftUI `Settings` scene과 겹치지 않게 서버 테이블 이름(`app_settings`)을 따른다.
/// 기기별 전역 설정이다
public struct AppSettings: Codable, Sendable, Equatable {
  public let locale: AppLanguage
  /// IANA 시간대
  public let timezone: String
  public let basis: Basis
  public let maPeriod: MAPeriod
  public let window: DistributionWindow
  /// 오름차순 5개
  public let rareLevels: [Double]
  /// nil = 알림 꺼짐
  public let alertCommodity: CommodityCode?
  /// nil = 알림 거부 시간 끄기
  public let quietTime: QuietTime?

  public init(
    locale: AppLanguage, timezone: String, basis: Basis, maPeriod: MAPeriod,
    window: DistributionWindow, rareLevels: [Double], alertCommodity: CommodityCode?,
    quietTime: QuietTime?
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

  /// `patch`의 필드를 덮은 값. 서버 확인 전 화면에 먼저 보일 때 쓴다(D-082 낙관적 갱신)
  public func applying(_ patch: SettingsPatch) -> AppSettings {
    AppSettings(
      locale: patch.locale ?? locale,
      timezone: patch.timezone ?? timezone,
      basis: patch.basis ?? basis,
      maPeriod: patch.maPeriod ?? maPeriod,
      window: patch.window ?? window,
      rareLevels: patch.rareLevels?.values ?? rareLevels,
      alertCommodity: patch.alertCommodity ?? alertCommodity,
      quietTime: patch.quietTime ?? quietTime)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    locale = try container.decode(AppLanguage.self, forKey: .locale)
    timezone = try container.decode(String.self, forKey: .timezone)
    basis = try container.decode(Basis.self, forKey: .basis)
    maPeriod = try container.decode(MAPeriod.self, forKey: .maPeriod)
    window = try container.decode(DistributionWindow.self, forKey: .window)
    rareLevels = try container.decode([Double].self, forKey: .rareLevels)
    alertCommodity = try container.decodeIfPresent(CommodityCode.self, forKey: .alertCommodity)
    quietTime = try container.decodeIfPresent(QuietTime.self, forKey: .quietTime)
    guard rareLevels.count == RareLevels.count else {
      throw DecodingError.dataCorruptedError(
        forKey: .rareLevels, in: container,
        debugDescription: "\(rareLevels.count) levels, expected \(RareLevels.count)")
    }
  }
}

/// 알림 거부 시간: 기기 시간대 자정 기준 분. 자정을 넘기면 `startMin > endMin`이다
public struct QuietTime: Codable, Sendable, Equatable {
  public let startMin: Int
  public let endMin: Int

  public init(startMin: Int, endMin: Int) {
    self.startMin = startMin
    self.endMin = endMin
  }
}
