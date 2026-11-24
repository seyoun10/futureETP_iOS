import Core
import Foundation
import SwiftUI

/// 기기 시간대와 앱 언어가 서버 값과 다르면 PATCH한다 (RN `features/settings/DeviceSettingsSync.tsx`, D-048, D-084, D-137).
/// 서버 언어는 푸시 문구용 사본이라(D-082) 새 기기 행의 기본값(ko)이 앱 언어와 다르면 여기서 맞춘다.
/// 같은 값은 프로세스당 한 번만 보낸다(실패해도 되풀이하지 않고, 오류 줄도 띄우지 않는다)
@MainActor
final class DeviceSettingsSync {
  private var sentTimezone: String?
  private var sentLocale: AppLanguage?

  /// 보낼 변경. 없으면 nil. 돌려준 값은 보낸 것으로 기억한다
  func patch(server: AppSettings, language: AppLanguage, timezone: String?) -> SettingsPatch? {
    var patch = SettingsPatch()
    // IANA 이름으로 알아볼 수 있어야 서버가 받는다(원본 `timezoneSchema`)
    if let timezone, timezone != server.timezone, timezone != sentTimezone,
      TimeZone(identifier: timezone) != nil
    {
      sentTimezone = timezone
      patch.timezone = timezone
    }
    if language != server.locale, language != sentLocale {
      sentLocale = language
      patch.locale = language
    }
    return patch == SettingsPatch() ? nil : patch
  }
}

extension View {
  /// 화면이 보이는 동안 설정을 조회하고(진입·앱 복귀), 받을 때마다 기기 시간대·앱 언어를 서버 값과 맞춘다.
  /// 접근 키가 있을 때 루트에 건다 (D-084)
  public func deviceSettingsSync(_ store: SettingsStore) -> some View {
    modifier(DeviceSettingsSyncModifier(store: store))
  }
}

private struct DeviceSettingsSyncModifier: ViewModifier {
  let store: SettingsStore
  @Environment(DisplaySettings.self) private var displaySettings
  @State private var sync = DeviceSettingsSync()

  func body(content: Content) -> some View {
    content
      .queryLifecycle(store.query)
      .onChange(of: Trigger(store: store, language: displaySettings.language), initial: true) {
        guard let server = store.data,
          let patch = sync.patch(
            server: server, language: displaySettings.language,
            timezone: TimeZone.autoupdatingCurrent.identifier)
        else { return }
        store.update(patch)
      }
  }

  /// 서버 값을 다시 받거나(값이 같아도) 앱 언어가 바뀌면 다시 비교한다
  private struct Trigger: Equatable {
    let timezone: String?
    let locale: AppLanguage?
    let dataUpdatedAt: Date?
    let language: AppLanguage

    init(store: SettingsStore, language: AppLanguage) {
      timezone = store.data?.timezone
      locale = store.data?.locale
      dataUpdatedAt = store.query.dataUpdatedAt
      self.language = language
    }
  }
}
