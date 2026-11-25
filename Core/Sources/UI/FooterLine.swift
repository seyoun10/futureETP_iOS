import SwiftUI

/// 화면 최하단 안내 한 줄(A·C 기준 시각 줄, B 앱 번들 줄). 높이를 아끼려고 홈 인디케이터 여백 위쪽에 겹쳐 둔다
/// (여백 34pt면 줄 아래 여백만 남고 인디케이터는 맨 아래 약 13pt 안). 여백이 줄보다 낮으면 줄만큼 차지한다.
/// 내용이 없어도 빈 줄로 자리를 지켜 위의 tab-bar가 흔들리거나 탭마다 위치가 달라지지 않게 한다
/// (screens.md 공통 규칙, RN `components/FooterLine.tsx`)
public struct FooterLine: View {
  private let text: String?
  @State private var lineHeight: CGFloat = 0
  @Environment(\.homeIndicatorInset) private var homeIndicatorInset

  public init(_ text: String?) {
    self.text = text
  }

  public var body: some View {
    // 빈 줄도 같은 Text로 그려 기기 글자 크기와 줄 높이가 맞는다
    Text(verbatim: text ?? " ")
      .font(.system(size: Theme.FontSize.caption))
      .foregroundStyle(Theme.Colors.textSecondary)
      .lineLimit(1)
      .multilineTextAlignment(.center)
      .padding(.horizontal, Theme.Spacing.lg)
      .padding(.vertical, 1)
      .onGeometryChange(for: CGFloat.self) {
        $0.size.height
      } action: {
        lineHeight = $0
      }
      .frame(maxWidth: .infinity)
      .background(Theme.Colors.background)
      // 겹치는 만큼 차지하는 높이를 줄여 위 화면이 여백 바로 위까지 내려오고, 줄은 여백 안으로 그려진다
      .padding(.bottom, -Self.overlap(inset: homeIndicatorInset, lineHeight: lineHeight))
  }

  /// 홈 인디케이터 여백에 겹치는 높이. 여백이 줄보다 낮으면 여백만큼만 겹친다
  nonisolated static func overlap(inset: CGFloat, lineHeight: CGFloat) -> CGFloat {
    min(max(inset, 0), lineHeight)
  }
}

extension EnvironmentValues {
  /// 창 아래 safe area(홈 인디케이터 여백). `FooterLine`이 이 여백에 겹쳐 앉는다
  @Entry public var homeIndicatorInset: CGFloat = 0
}

extension View {
  /// 이 뷰의 아래 safe area로 `\.homeIndicatorInset`을 정해 아래 화면에 넣는다. 루트에서 한 번 쓴다.
  /// 줄 자리에서 여백을 읽으면 줄의 패딩이 다시 위치를 바꿔 레이아웃이 끝없이 되풀이되므로(C 화면) 루트에서 읽는다
  public func providesHomeIndicatorInset() -> some View {
    modifier(HomeIndicatorInsetProvider())
  }
}

private struct HomeIndicatorInsetProvider: ViewModifier {
  @State private var inset: CGFloat = 0

  func body(content: Content) -> some View {
    content
      .environment(\.homeIndicatorInset, inset)
      .onGeometryChange(for: CGFloat.self) {
        $0.safeAreaInsets.bottom
      } action: {
        inset = $0
      }
  }
}
