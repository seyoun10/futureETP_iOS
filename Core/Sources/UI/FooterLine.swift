import SwiftUI

/// 화면 최하단 안내 한 줄(A·C 기준 시각 줄, B 앱 번들 줄). 내용이 없어도 빈 줄로 자리를 지켜
/// 위의 tab-bar가 흔들리거나 탭마다 위치가 달라지지 않게 한다 (RN `components/FooterLine.tsx`)
public struct FooterLine: View {
  private let text: String?

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
      .frame(maxWidth: .infinity)
      .background(Theme.Colors.background)
  }
}
