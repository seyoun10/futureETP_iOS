import SwiftUI

/// 화면이 전체(헤더 포함) 터치를 막아 달라고 루트에 알리는 값 (RN `refresh-touch-blocker`, D-138)
struct BlocksTouchesKey: PreferenceKey {
  static let defaultValue = false

  static func reduce(value: inout Bool, nextValue: () -> Bool) {
    value = value || nextValue()
  }
}

extension View {
  /// `blocks`인 동안 화면 전체(title-bar 포함) 터치를 막는다. 루트의 `.touchBlocker()`가 덮는다.
  /// 투명이라 아래 인디케이터는 보인다
  public func blocksTouches(_ blocks: Bool) -> some View {
    preference(key: BlocksTouchesKey.self, value: blocks)
  }

  /// 안쪽 화면이 `.blocksTouches(true)`면 투명 막으로 덮는다. `NavigationStack` 바깥에 붙여 title-bar까지 덮는다
  public func touchBlocker() -> some View {
    overlayPreferenceValue(BlocksTouchesKey.self) { blocks in
      if blocks {
        Color.clear
          .contentShape(.rect)
          .ignoresSafeArea()
          .accessibilityHidden(true)
          .accessibilityIdentifier("touchBlocker")
      }
    }
  }
}
