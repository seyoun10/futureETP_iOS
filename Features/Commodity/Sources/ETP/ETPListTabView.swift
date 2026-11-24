import Core
import SwiftUI

/// C-d ETP 목록 탭(screens.md C-d, D-017, RN `EtpListScreen`). 필터·정렬은 받은 목록 안에서 하고 기억하지 않는다.
/// 수집 시각은 다른 탭의 기준 시각 줄 자리(tab-bar 아래)에 쓴다. 거래일·장 상태는 없다
struct ETPListTabView: View {
  private let query: Query<ETPList>
  private let onOpen: (UUID) -> Void
  @State private var filters = ETPFilters()
  @State private var sort = ETPSort.default

  init(code: CommodityCode, queries: CommodityQueries, onOpen: @escaping (UUID) -> Void) {
    query = queries.etps(code)
    self.onOpen = onOpen
  }

  var body: some View {
    QueryStateView(query.state, retry: { Task { await query.refetch() } }) { data in
      if data.etps.isEmpty {
        ETPMessage(key: "etp.empty")
      } else {
        list(data.etps)
      }
    }
    .queryLifecycle(query)
    .tabFooterTime(query.state.data?.asOf.map { .asOf($0) })
    .background(Theme.Colors.background)
  }

  private func list(_ etps: [ETPSummary]) -> some View {
    let rows = ETPListModel.sort(ETPListModel.filter(etps, by: filters), by: sort)
    return ScrollView {
      LazyVStack(spacing: 0) {
        ETPFilterSection(etps: etps, filters: $filters, sort: $sort)
        Separator()
        if rows.isEmpty {
          ETPMessage(key: "etp.noMatch")
        }
        ForEach(rows) { etp in
          ETPRow(etp: etp, sort: sort) { onOpen(etp.id) }
          Separator()
        }
      }
    }
    .accessibilityIdentifier("etpList")
  }
}

/// 시장·유형·배수·환헤지 필터와 정렬
private struct ETPFilterSection: View {
  /// 배수 선택지가 이보다 많으면 이름을 위에 두고 전체 폭을 쓴다
  static let inlineLeverageOptions = 4

  let etps: [ETPSummary]
  @Binding var filters: ETPFilters
  @Binding var sort: ETPSort
  @Environment(\.locale) private var locale

  var body: some View {
    let leverages = ETPListModel.leverageOptions(etps)
    VStack(spacing: 0) {
      SegmentedRow(
        t("etp.market"),
        options: [all()] + ETPMarket.allCases.map { .init($0, $0.rawValue) },
        value: Optional(filters.market)
      ) { filters.market = $0 }
      SegmentedRow(
        t("etp.type"),
        options: [all()] + ETPType.allCases.map { .init($0, $0.rawValue) },
        value: Optional(filters.type)
      ) { filters.type = $0 }
      SegmentedRow(
        t("etp.leverage"),
        options: [all()] + leverages.map { .init($0, ETPText.leverage($0, t: t)) },
        value: Optional(filters.leverage),
        stacked: leverages.count > Self.inlineLeverageOptions
      ) { filters.leverage = $0 }
      SegmentedRow(
        t("etp.fxHedge"),
        options: [all()] + FXHedge.allCases.map { .init($0, t("etp.fxHedges.\($0.rawValue)")) },
        value: Optional(filters.fxHedge),
        stacked: true
      ) { filters.fxHedge = $0 }
      SegmentedRow(
        t("etp.sort"),
        options: ETPSort.allCases.map { .init($0, t("etp.sorts.\($0.rawValue)")) },
        value: sort
      ) { sort = $0 }
    }
  }

  /// 전체(nil)
  private func all<T>() -> SegmentedRow<T?>.Option { .init(nil, t("etp.all")) }

  private func t(_ key: String, _ values: [String: String] = [:]) -> String {
    L10n.string(key, values, locale: locale)
  }
}

/// 한 줄: 이름(미국 상장은 티커 + 이름), 시장 · 유형 · 배수 · 환헤지 [· 정렬 값]
private struct ETPRow: View {
  let etp: ETPSummary
  let sort: ETPSort
  let action: () -> Void
  @State private var taps = 0
  @Environment(\.locale) private var locale

  var body: some View {
    Button {
      taps += 1
      action()
    } label: {
      HStack(spacing: Theme.Spacing.sm) {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
          Text(verbatim: ETPText.title(etp))
            .font(.system(size: Theme.FontSize.body))
            .foregroundStyle(Theme.Colors.text)
          Text(verbatim: ETPText.attributes(etp, sort: sort, t: t))
            .font(.system(size: Theme.FontSize.caption))
            .foregroundStyle(Theme.Colors.textSecondary)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        Image(systemName: "chevron.right")
          .foregroundStyle(Theme.Colors.textSecondary)
      }
      .padding(.horizontal, Theme.Spacing.lg)
      .padding(.vertical, Theme.Spacing.md)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .sensoryFeedback(.selection, trigger: taps)
  }

  private func t(_ key: String, _ values: [String: String]) -> String {
    L10n.string(key, values, locale: locale)
  }
}

private struct ETPMessage: View {
  let key: LocalizedStringKey

  var body: some View {
    Text(key)
      .font(.system(size: Theme.FontSize.body))
      .foregroundStyle(Theme.Colors.textSecondary)
      .multilineTextAlignment(.center)
      .padding(Theme.Spacing.xl)
      .frame(maxWidth: .infinity)
  }
}

private struct Separator: View {
  var body: some View {
    Rectangle().fill(Theme.Colors.separator).frame(height: 1)
  }
}
