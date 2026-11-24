import SwiftUI
import UIKit

/// 앱은 세로로 잠그고, C-a~C-c의 [⟲]만 가로로 잠근다 (screens.md C, D-076, RN `lib/orientation.ts`).
/// 기기가 잠금을 거부해도(iPhone Mirroring 등 크기 조절 창) 레이아웃은 창 모양(`\.isLandscape`)을
/// 따르므로 실패는 무시한다
@MainActor
public enum OrientationLock {
  /// 지금 허용하는 방향. 앱 delegate의 `supportedInterfaceOrientationsFor`가 돌려준다.
  /// 시작 방향은 세로
  public private(set) static var mask: UIInterfaceOrientationMask = .portrait

  public static func lockPortrait() {
    lock(.portrait)
  }

  public static func lockLandscape() {
    lock(.landscape)
  }

  /// [⟲]: 잠금 상태가 아니라 지금 창 모양의 반대 방향으로 잠근다
  public static func toggle(isLandscape: Bool) {
    lock(mask(togglingFrom: isLandscape))
  }

  static func mask(togglingFrom isLandscape: Bool) -> UIInterfaceOrientationMask {
    isLandscape ? .portrait : .landscape
  }

  private static func lock(_ newMask: UIInterfaceOrientationMask) {
    mask = newMask
    for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
      // 허용 방향을 다시 묻게 한 뒤 회전을 요청한다
      for window in scene.windows {
        window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
      }
      scene.requestGeometryUpdate(.iOS(interfaceOrientations: newMask)) { _ in
        // 거부는 무시한다
      }
    }
  }
}

extension EnvironmentValues {
  /// 창 너비가 높이보다 크면 가로. title-bar·tab-bar 높이 등 가로 레이아웃은 이 값으로 정한다 (D-076)
  @Entry public var isLandscape = false
}

extension View {
  /// 이 뷰의 크기로 `\.isLandscape`를 정해 아래 화면에 넣는다. 루트에서 한 번 쓴다
  public func providesIsLandscape() -> some View {
    modifier(IsLandscapeProvider())
  }
}

private struct IsLandscapeProvider: ViewModifier {
  @State private var isLandscape = false

  func body(content: Content) -> some View {
    content
      .environment(\.isLandscape, isLandscape)
      .onGeometryChange(for: Bool.self) {
        $0.size.width > $0.size.height
      } action: {
        isLandscape = $0
      }
  }
}
