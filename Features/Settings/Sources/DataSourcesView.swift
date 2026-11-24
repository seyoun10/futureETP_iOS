import Core
import SwiftUI

/// B > 데이터 출처 (screens.md B, RN `DataSourcesScreen`). 업체 약관의 출처 표기를 지키는 읽기 전용 화면이다(D-011).
/// 상표·로고 없이 이름만 쓰고, 소스가 바뀌면 문구(`dataSources.*`)도 바꾼다
public struct DataSourcesView: View {
  /// 줄 순서는 screens.md 데이터 출처 그대로다
  static let sections: [(title: String, rows: [String])] = [
    ("futures", ["exchange", "settlement", "intraday", "history"]),
    ("etp", ["etpKr", "etpUs"]),
  ]

  @Environment(\.locale) private var locale

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        ForEach(Self.sections, id: \.title) { section in
          SectionHeader(title: t("dataSources.sections.\(section.title)"))
          ForEach(section.rows, id: \.self) { row in
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
              Text(verbatim: t("dataSources.rows.\(row).label"))
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize()
              Text(verbatim: t("dataSources.rows.\(row).value"))
                .foregroundStyle(Theme.Colors.text)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: Theme.FontSize.body))
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .overlay(alignment: .bottom) {
              Rectangle().fill(Theme.Colors.separator).frame(height: 1)
            }
          }
        }
        Text("dataSources.notice")
          .font(.system(size: Theme.FontSize.caption))
          .foregroundStyle(Theme.Colors.textSecondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(Theme.Spacing.lg)
      }
    }
    .background(Theme.Colors.background)
    .backTitleBar(Text("settings.dataSources"))
    .accessibilityIdentifier("dataSources")
  }

  private func t(_ key: String) -> String {
    L10n.string(key, locale: locale)
  }
}
