import SwiftUI

extension View {
  /// 스택 화면 title-bar: [←] 바로 오른쪽에 왼쪽 정렬한 제목, 오른쪽에 `trailing` (screens.md 공통 title-bar).
  /// 쓸어서 뒤로 가기를 막으려 시스템 뒤로 버튼을 숨기고 [←]로만 돌아간다 (D-105). [←]는 선택 햅틱을 준다 (D-109)
  public func backTitleBar<Trailing: View>(
    _ title: Text, @ViewBuilder trailing: () -> Trailing = { EmptyView() }
  ) -> some View {
    modifier(BackTitleBar(title: title, trailing: trailing()))
  }
}

private struct BackTitleBar<Trailing: View>: ViewModifier {
  let title: Text
  let trailing: Trailing
  @State private var backTaps = 0
  @Environment(\.dismiss) private var dismiss

  func body(content: Content) -> some View {
    content
      .navigationBarBackButtonHidden()
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          HStack(spacing: Theme.Spacing.sm) {
            Button {
              backTaps += 1
              dismiss()
            } label: {
              Image(systemName: "chevron.left")
                .foregroundStyle(Theme.Colors.text)
            }
            .accessibilityLabel(Text("common.back"))
            .accessibilityIdentifier("back")
            title
              .font(.system(size: Theme.FontSize.title, weight: .semibold))
              .foregroundStyle(Theme.Colors.text)
              .lineLimit(1)
              .fixedSize()
              .accessibilityAddTraits(.isHeader)
          }
        }
        ToolbarItem(placement: .topBarTrailing) { trailing }
      }
      .sensoryFeedback(.selection, trigger: backTaps)
  }
}
