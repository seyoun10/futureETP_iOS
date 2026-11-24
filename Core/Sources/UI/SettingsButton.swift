import SwiftUI

/// A·C title-bar [⚙]. 이 기기의 알림 대상 원자재가 없으면 오른쪽 위에 빨간 점을 띄운다 (D-124).
/// 누르면 선택 햅틱을 준다 (D-109)
public struct SettingsButton: View {
  private let alertOff: Bool
  private let action: () -> Void
  @State private var taps = 0

  public init(alertOff: Bool, action: @escaping () -> Void) {
    self.alertOff = alertOff
    self.action = action
  }

  public var body: some View {
    Button {
      taps += 1
      action()
    } label: {
      Image(systemName: "gearshape")
        .foregroundStyle(Theme.Colors.text)
        .overlay(alignment: .topTrailing) {
          if alertOff {
            Circle()
              .fill(Theme.Colors.badge)
              .frame(width: 8, height: 8)
              .offset(x: 3, y: -3)
          }
        }
    }
    .sensoryFeedback(.selection, trigger: taps)
    .accessibilityLabel(Text("settings.title"))
    .accessibilityHint(alertOff ? Text("settings.alertOffBadge") : Text(verbatim: ""))
    .accessibilityIdentifier("openSettings")
  }
}
