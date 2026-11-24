import Observation
import UIKit
import UserNotifications

/// 알림 권한 상태 (RN `push/usePushPermission.ts`). OS 설정에서 바꾸고 돌아올 수 있어 앱이 다시 활성화될 때마다 새로 읽는다.
/// 다시 물을 수 있으면(아직 묻지 않음) 권한 창을 띄우고, 아니면 이 앱의 알림 설정 화면을 연다
@MainActor
@Observable
final class PushPermission {
  struct State: Equatable {
    var granted: Bool
    var canAskAgain: Bool
  }

  /// 읽기 전이면 nil
  private(set) var state: State?

  func refresh() async {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    state = Self.state(for: settings.authorizationStatus)
  }

  func request() async {
    guard let state else { return }
    if state.canAskAgain {
      _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [
        .alert, .sound, .badge,
      ])
      await refresh()
    } else if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
      await UIApplication.shared.open(url)
    }
  }

  /// expo-notifications `getPermissionsAsync`와 같은 규칙: 임시·잠깐 허용도 허용이고, 아직 묻지 않았을 때만 다시 묻는다
  nonisolated static func state(for status: UNAuthorizationStatus) -> State {
    switch status {
    case .authorized, .provisional, .ephemeral: State(granted: true, canAskAgain: false)
    case .notDetermined: State(granted: false, canAskAgain: true)
    case .denied: State(granted: false, canAskAgain: false)
    @unknown default: State(granted: false, canAskAgain: false)
    }
  }
}
