import Core
import SwiftUI

/// A 원자재 목록(홈) (screens.md A, D-085, RN `CommodityListScreen`).
/// 원자재와 월물 줄은 서버가 준 순서대로 그린다
public struct CommodityListView: View {
  private let query: Query<Commodities>
  private let alertOff: Bool
  private let onSelect: (CommodityCode) -> Void
  private let onOpenSettings: () -> Void
  private let onOpenCalendar: () -> Void
  @State private var refresh = PullRefresh()

  /// - Parameters:
  ///   - alertOff: 이 기기의 알림 대상 원자재가 없다. [⚙]에 빨간 점을 띄운다 (D-124)
  ///   - onSelect: 원자재 행을 눌렀다. C(C-a 탭)로 간다
  ///   - onOpenCalendar: [📅]을 눌렀다. A-a 휴장 달력으로 간다 (D-143)
  public init(
    query: Query<Commodities>, alertOff: Bool,
    onSelect: @escaping (CommodityCode) -> Void, onOpenSettings: @escaping () -> Void,
    onOpenCalendar: @escaping () -> Void
  ) {
    self.query = query
    self.alertOff = alertOff
    self.onSelect = onSelect
    self.onOpenSettings = onOpenSettings
    self.onOpenCalendar = onOpenCalendar
  }

  public var body: some View {
    QueryStateView(query.state, retry: { Task { await query.refetch() } }) { data in
      list(data)
        .safeAreaInset(edge: .bottom, spacing: 0) {
          FreshnessLine(.market(data.freshness))
        }
    }
    .queryLifecycle(query)
    .background(Theme.Colors.background)
    .titleBarSeparator()
    // A는 [←] 없이 제목을 왼쪽 끝에 둔다 (screens.md 공통 title-bar)
    .navigationTitle(Text(verbatim: "futureETP"))
    .toolbarTitleDisplayMode(.inlineLarge)
    .toolbar {
      // [📅]은 [⚙] 바로 왼쪽이다 (screens.md A)
      ToolbarItemGroup(placement: .topBarTrailing) {
        CalendarButton(action: onOpenCalendar)
        SettingsButton(alertOff: alertOff, action: onOpenSettings)
      }
    }
    // 새로고침 중에는 헤더를 포함한 화면 전체 터치를 막는다 (D-138)
    .blocksTouches(refresh.isRefreshing)
    .sensoryFeedback(.impact(weight: .light), trigger: refresh.pullCount)
    .alert(Text("commodityList.refreshFailedTitle"), isPresented: $refresh.showsFailure) {
      Button("common.confirm", role: .cancel) {}
    } message: {
      Text("commodityList.refreshFailedMessage")
    }
  }

  private func list(_ data: Commodities) -> some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(data.commodities, id: \.code) { commodity in
          CommodityRow(commodity: commodity) { onSelect(commodity.code) }
          Rectangle()
            .fill(Theme.Colors.separator)
            .frame(height: 1)
        }
      }
    }
    .accessibilityIdentifier("commodityList")
    .refreshable {
      await refresh.refresh {
        await query.refetch()
        return query.state.error == nil
      }
    }
  }
}

/// 원자재 하나: 왼쪽 이름·(심볼)·🔔, 오른쪽 월물 줄
private struct CommodityRow: View {
  let commodity: CommoditySummary
  let action: () -> Void
  @State private var taps = 0

  private var nameKey: String { "commodities.\(commodity.code.rawValue)" }

  var body: some View {
    Button {
      taps += 1
      action()
    } label: {
      HStack(spacing: 0) {
        VStack(spacing: Theme.Spacing.xs) {
          // 보간한 리터럴은 `%@` 키가 되므로 문자열로 만든 뒤 키로 쓴다
          Text(LocalizedStringKey(nameKey))
          Text(verbatim: "(\(commodity.code.rawValue))")
          if commodity.alert {
            Text(verbatim: "🔔")
              .font(.system(size: Theme.FontSize.caption))
              .accessibilityLabel(Text("commodityList.alert"))
          }
        }
        .font(.system(size: Theme.FontSize.body))
        .foregroundStyle(Theme.Colors.text)
        .multilineTextAlignment(.center)
        .frame(width: 104)
        VStack(spacing: Theme.Spacing.xs) {
          ForEach(commodity.contracts, id: \.symbol) { quote in
            QuoteLine(quote: quote, decimals: commodity.priceDecimals)
          }
        }
        .frame(maxWidth: .infinity)
      }
      .padding(Theme.Spacing.lg)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .sensoryFeedback(.selection, trigger: taps)
    .accessibilityIdentifier("commodity-\(commodity.code.rawValue)")
  }
}

/// 월물 / 현재가 / 전일 대비 / 등락률. 오늘 값이 없으면 마지막 정산가와 "거래 없음"이다
private struct QuoteLine: View {
  let quote: ContractQuote
  let decimals: Int
  @Environment(DisplaySettings.self) private var display

  var body: some View {
    HStack(spacing: 0) {
      Text(verbatim: NumberFormat.contractMonth(quote.contractMonth) + (quote.isFront ? "●" : " "))
        .foregroundStyle(Theme.Colors.textSecondary)
        .frame(width: 52)
      Text(verbatim: quote.price.map { NumberFormat.price($0, decimals: decimals) } ?? "-")
        .foregroundStyle(Theme.Colors.text)
        .frame(maxWidth: .infinity)
      if quote.noTrade {
        Text("commodityList.noTrade")
          .foregroundStyle(Theme.Colors.neutral)
          .frame(width: 124)
      } else {
        Group {
          Text(verbatim: quote.change.map { NumberFormat.change($0, decimals: decimals) } ?? "-")
            .frame(width: 64)
          Text(verbatim: quote.changePct.map(NumberFormat.changePct) ?? "-")
            .frame(width: 60)
        }
        .foregroundStyle(color)
      }
    }
    .font(.system(size: Theme.FontSize.caption).monospacedDigit())
    .lineLimit(1)
    .minimumScaleFactor(0.8)
  }

  /// 둘 다 0이면 방향 없는 색, 아니면 0이 아닌 쪽 부호 (screens.md 공통 등락 색)
  private var color: Color {
    guard let change = quote.change else { return Theme.Colors.neutral }
    return display.palette.color(
      change: change, changePct: quote.changePct ?? 0, decimals: decimals)
  }
}
