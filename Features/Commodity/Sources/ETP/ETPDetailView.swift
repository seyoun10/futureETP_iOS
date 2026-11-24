import Core
import SwiftUI

/// C-d-a ETP 상세(탭 밖 스택, screens.md C-d-a, D-047, RN `EtpDetailScreen`).
/// 값은 자동 수집 정보라 원문 언어 그대로 보여 준다
public struct ETPDetailView: View {
  private let query: Query<ETPDetail>
  @State private var backTaps = 0
  @Environment(\.dismiss) private var dismiss

  public init(query: Query<ETPDetail>) {
    self.query = query
  }

  public var body: some View {
    QueryStateView(query.state, retry: { Task { await query.refetch() } }) { etp in
      ETPFields(etp: etp)
    }
    .queryLifecycle(query)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.Colors.background)
    // 뒤로 가기는 [←]로만 한다(D-105)
    .navigationBarBackButtonHidden()
    .toolbar {
      ToolbarItem(placement: .topBarLeading) { titleBar }
    }
    .sensoryFeedback(.selection, trigger: backTaps)
    .accessibilityIdentifier("etpDetail")
  }

  static let titleMaxWidth: CGFloat = 280

  private var titleBar: some View {
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
      Group {
        if let name = query.state.data?.name {
          Text(verbatim: name)
        } else {
          Text("etp.detailTitle")
        }
      }
      .font(.system(size: Theme.FontSize.title, weight: .semibold))
      .foregroundStyle(Theme.Colors.text)
      .lineLimit(1)
      // 툴바는 제목에 폭을 주지 않아 글자 폭만큼 쓰되, 긴 이름은 [←] 옆 남은 폭 안에서 줄인다
      .frame(maxWidth: Self.titleMaxWidth, alignment: .leading)
      .fixedSize()
      .accessibilityAddTraits(.isHeader)
    }
  }
}

private struct ETPFields: View {
  let etp: ETPDetail
  @Environment(\.locale) private var locale
  @Environment(\.openURL) private var openURL

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        ForEach(ETPDetailRows.rows(etp, t: t), id: \.label) { row in
          HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
            Text(verbatim: row.label)
              .foregroundStyle(Theme.Colors.textSecondary)
              .frame(width: 88, alignment: .leading)
            Text(verbatim: row.value)
              .foregroundStyle(Theme.Colors.text)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .font(.system(size: Theme.FontSize.body))
        }
        if let url = ETPDetailRows.issuerURL(etp) {
          Button {
            openURL(url)
          } label: {
            Text("etp.openIssuer")
              .font(.system(size: Theme.FontSize.body))
              .foregroundStyle(Theme.Colors.text)
              .padding(.horizontal, Theme.Spacing.lg)
              .padding(.vertical, Theme.Spacing.sm)
              .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Spacing.sm))
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(.isLink)
          .padding(.top, Theme.Spacing.md)
        }
        Group {
          Text("etp.sourceNote")
          Text(
            verbatim: t(
              "freshness.asOf", ["time": DateTimeFormat.localDateTime(etp.collectedAt)]))
        }
        .font(.system(size: Theme.FontSize.caption))
        .foregroundStyle(Theme.Colors.textSecondary)
      }
      .padding(Theme.Spacing.lg)
    }
  }

  private func t(_ key: String, _ values: [String: String]) -> String {
    L10n.string(key, values, locale: locale)
  }
}

/// 상세 필드 줄. 값이 없으면 `—`
enum ETPDetailRows {
  struct Row: Equatable {
    let label: String
    let value: String
  }

  static func rows(_ etp: ETPDetail, t: ETPText.Translate) -> [Row] {
    let dash = t("etp.noValue", [:])
    func row(_ key: String, _ value: String?) -> Row {
      Row(label: t(key, [:]), value: value ?? dash)
    }
    return [
      row("etp.commodity", t("commodities.\(etp.commodityCode.rawValue)", [:])),
      row("etp.market", etp.market.rawValue),
      row("etp.type", etp.type.rawValue),
      row("etp.leverage", ETPText.leverage(etp.leverage, t: t)),
      row("etp.fxHedge", t("etp.fxHedges.\(etp.fxHedge.rawValue)", [:])),
      row("etp.issuer", etp.issuer),
      row("etp.underlyingIndex", etp.underlyingIndex),
      row(
        "etp.expenseRatio",
        etp.expenseRatio.map { t("etp.expenseRatioValue", ["n": ETPText.number($0)]) }),
      row("etp.listedDate", etp.listedDate?.description),
      row(
        "etp.ticker",
        etp.series.isEmpty ? nil : etp.series.map { seriesLine($0, t: t) }.joined(separator: "\n")),
    ]
  }

  /// ETN 후속 시리즈는 줄마다 `B 시리즈 · 530031 · 만기 2031-03-15`(screens.md C-d-a). ETF는 종목코드만
  static func seriesLine(_ series: ETPSeries, t: ETPText.Translate) -> String {
    [
      series.seriesCode.map { t("etp.seriesCode", ["code": $0]) },
      series.ticker,
      series.maturityDate.map { t("etp.maturity", ["date": $0.description]) },
    ].compactMap(\.self).joined(separator: " · ")
  }

  /// 수집한 주소라도 웹 페이지(http·https)만 연다
  static func issuerURL(_ etp: ETPDetail) -> URL? {
    guard let text = etp.issuerUrl, let url = URL(string: text),
      let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https"
    else { return nil }
    return url
  }
}
