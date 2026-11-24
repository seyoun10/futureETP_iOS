import Core
import Foundation
import Observation

/// B 설정 화면 Model (RN `SettingsScreen`). 저장 실패 줄은 이 화면에서 보낸 마지막 변경의 결과만 보인다
/// (RN `useUpdateSettings` 한 벌). 새 변경을 보내면 지운다
@MainActor
@Observable
final class SettingsScreenModel {
  let store: SettingsStore
  private(set) var saveError: (any Error)?
  @ObservationIgnored private var latest = 0

  init(store: SettingsStore) {
    self.store = store
  }

  @discardableResult
  func save(_ patch: SettingsPatch) -> Task<Void, Never> {
    latest += 1
    let id = latest
    saveError = nil
    let update = store.update(patch)
    return Task {
      let error = await update.value
      if id == latest { saveError = error }
    }
  }

  /// 표시·이격도차트 설정만 기본값으로 되돌린다. 알림(B-a)과 접근 키는 그대로 둔다.
  /// 언어는 푸시 문구에 쓰므로 함께 보낸다
  @discardableResult
  func reset(display: DisplaySettings) -> Task<Void, Never> {
    display.reset()
    var patch = SettingsPatch.disparityDefaults
    patch.locale = display.language
    return save(patch)
  }
}
