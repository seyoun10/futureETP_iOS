import SwiftUI

extension View {
  /// 스택 화면 title-bar: [←] 바로 오른쪽에 왼쪽 정렬한 제목, 오른쪽에 `trailing` (screens.md 공통 title-bar).
  /// 쓸어서 뒤로 가기를 막으려 시스템 뒤로 버튼을 숨기고 [←]로만 돌아간다 (D-105). [←]는 선택 햅틱을 준다 (D-109)
  public func backTitleBar<Trailing: View>(
    _ title: Text, @ViewBuilder trailing: () -> Trailing = { EmptyView() }
  ) -> some View {
    modifier(BackTitleBar(title: title, trailing: trailing()))
  }

  /// title-bar 아래 1pt `barSeparator` 줄. 화면 내용은 그 아래에서 시작한다(모든 화면 공통, RN `ScreenHeader` 아래 테두리)
  public func titleBarSeparator() -> some View {
    safeAreaInset(edge: .top, spacing: 0) {
      Rectangle()
        .fill(Theme.Colors.barSeparator)
        .frame(height: 1)
        .accessibilityHidden(true)
    }
  }
}

private struct BackTitleBar<Trailing: View>: ViewModifier {
  let title: Text
  let trailing: Trailing
  @State private var backTaps = 0
  @Environment(\.dismiss) private var dismiss

  func body(content: Content) -> some View {
    content
      .titleBarSeparator()
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
