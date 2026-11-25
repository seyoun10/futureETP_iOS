import SwiftUI

extension View {
  /// 스택 화면 title-bar: [←] 바로 오른쪽에 왼쪽 정렬한 제목, 오른쪽에 `trailing` (screens.md 공통 title-bar).
  /// 쓸어서 뒤로 가기를 막으려 시스템 뒤로 버튼을 숨기고 [←]로만 돌아간다 (D-105). [←]는 선택 햅틱을 준다 (D-109)
  public func backTitleBar<Trailing: View>(
    _ title: Text, @ViewBuilder trailing: () -> Trailing = { EmptyView() }
  ) -> some View {
    backTitleBar(title: { title }, trailing: trailing)
  }

  /// 제목이 여러 조각이거나 [←] 동작이 따로 있는 화면용 `backTitleBar`.
  /// - Parameters:
  ///   - onBack: [←]를 눌렀다. nil이면 `dismiss`
  ///   - titleMaxWidth: 긴 제목을 이 폭 안에서 줄인다. 툴바는 제목에 폭을 주지 않아 nil이면 글자 폭만큼 쓴다
  ///   - trailing: 오른쪽 버튼들. 여러 개면 툴바 항목 하나씩이 된다
  public func backTitleBar<Title: View, Trailing: View>(
    onBack: (() -> Void)? = nil, titleMaxWidth: CGFloat? = nil,
    @ViewBuilder title: () -> Title,
    @ViewBuilder trailing: () -> Trailing = { EmptyView() }
  ) -> some View {
    modifier(
      BackTitleBar(
        title: title(), trailing: trailing(), onBack: onBack, titleMaxWidth: titleMaxWidth))
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

private struct BackTitleBar<Title: View, Trailing: View>: ViewModifier {
  let title: Title
  let trailing: Trailing
  let onBack: (() -> Void)?
  let titleMaxWidth: CGFloat?
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
              if let onBack { onBack() } else { dismiss() }
            } label: {
              Image(systemName: "chevron.left")
                .foregroundStyle(Theme.Colors.text)
            }
            .accessibilityLabel(Text("common.back"))
            .accessibilityIdentifier("back")
            titleView
          }
        }
        ToolbarItemGroup(placement: .topBarTrailing) { trailing }
      }
      .sensoryFeedback(.selection, trigger: backTaps)
  }

  @ViewBuilder private var titleView: some View {
    let styled =
      title
      .font(.system(size: Theme.FontSize.title, weight: .semibold))
      .foregroundStyle(Theme.Colors.text)
      .lineLimit(1)
    Group {
      if let titleMaxWidth {
        styled.frame(maxWidth: titleMaxWidth, alignment: .leading)
      } else {
        styled
      }
    }
    .fixedSize()
    .accessibilityAddTraits(.isHeader)
  }
}
