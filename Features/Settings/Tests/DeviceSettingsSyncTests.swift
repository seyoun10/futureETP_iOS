import Core
import Foundation
import Testing

@testable import Settings

private func server(locale: AppLanguage = .ko, timezone: String = "Asia/Seoul") -> AppSettings {
  AppSettings(
    locale: locale, timezone: timezone, basis: .front, maPeriod: .days50, window: .years5,
    rareLevels: [1, 2.5, 5, 10, 20], alertCommodity: nil, quietTime: nil)
}

// RN `DeviceSettingsSync.test.tsx`와 같은 경우
@MainActor
@Suite struct DeviceSettingsSyncTests {
  @Test func sendsNothingWhenSame() {
    let sync = DeviceSettingsSync()
    #expect(sync.patch(server: server(), language: .ko, timezone: "Asia/Seoul") == nil)
  }

  @Test func sendsTimezoneAndLocaleInOnePatch() {
    let sync = DeviceSettingsSync()
    let patch = sync.patch(server: server(), language: .en, timezone: "America/Chicago")
    #expect(patch == SettingsPatch(locale: .en, timezone: "America/Chicago"))
  }

  @Test func sendsSameValueOnlyOnce() {
    let sync = DeviceSettingsSync()
    _ = sync.patch(server: server(), language: .en, timezone: "America/Chicago")
    // 실패해 서버 값이 그대로여도 되풀이하지 않는다
    #expect(sync.patch(server: server(), language: .en, timezone: "America/Chicago") == nil)
    // 다른 값은 다시 보낸다
    #expect(
      sync.patch(server: server(), language: .en, timezone: "Europe/London")
        == SettingsPatch(timezone: "Europe/London"))
  }

  @Test func skipsUnknownOrMissingTimezone() {
    let sync = DeviceSettingsSync()
    #expect(sync.patch(server: server(), language: .ko, timezone: "Mars/Olympus") == nil)
    #expect(sync.patch(server: server(), language: .ko, timezone: nil) == nil)
  }

  @Test func followsServerChangedElsewhere() {
    let sync = DeviceSettingsSync()
    // 서버 값이 다른 기기·초기값으로 어긋나 있으면 맞춘다
    #expect(
      sync.patch(server: server(locale: .en), language: .ko, timezone: "Asia/Seoul")
        == SettingsPatch(locale: .ko))
  }
}
