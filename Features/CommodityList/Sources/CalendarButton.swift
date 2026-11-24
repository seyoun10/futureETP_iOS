import Core
import SwiftUI

/// A title-bar의 [📅]. 휴장 달력 화면으로 간다 (screens.md A, D-143, RN `CalendarHeaderButton`).
/// 누르면 선택 햅틱을 준다 (D-109)
struct CalendarButton: View {
  let action: () -> Void
  @State private var taps = 0

  var body: some View {
    Button {
      taps += 1
      action()
    } label: {
      Image(systemName: "calendar")
        .foregroundStyle(Theme.Colors.text)
    }
    .sensoryFeedback(.selection, trigger: taps)
    .accessibilityLabel(Text("calendar.title"))
    .accessibilityIdentifier("openCalendar")
  }
}
