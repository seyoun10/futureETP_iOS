import Core
import SwiftUI

/// C-c 월물차트 탭(screens.md C-c, D-092, D-093, D-118). 조회 상태(첫 로딩은 차트 모양 스켈레톤, 오류는 재시도)와 차트
/// (RN `ContractChartScreen`)
struct ContractTabView: View {
  @State private var model: ContractScreenModel
  @Environment(ChartPeriods.self) private var periods

  init(code: CommodityCode, queries: CommodityQueries) {
    _model = State(initialValue: ContractScreenModel(paged: queries.contracts(code)))
  }

  var body: some View {
    QueryStateView(
      model.query.state, retry: { Task { await model.query.refetch() } },
      skeleton: { ChartSkeleton() }
    ) { _ in
      if let chart = model.chart, model.view != nil {
        if chart.chart.dates.isEmpty || chart.lines.isEmpty {
          ChartTabMessage(key: "contracts.noData")
        } else {
          ContractChartView(model: model, chart: chart)
        }
      } else {
        ChartSkeleton()
      }
    }
    .queryLifecycle(model.query)
    .tabFooterTime(model.query.state.data.map { .market($0.latest.freshness) })
    .onChange(of: model.query.dataUpdatedAt, initial: true) {
      model.dataChanged(period: periods.contract)
    }
  }
}

/// 겹친 선 차트, 범례, [↻], 기간 칩. 가로 모드는 기간 칩을 숨긴다 (D-103)
private struct ContractChartView: View {
  let model: ContractScreenModel
  let chart: ContractChartModel
  @Environment(ChartPeriods.self) private var periods
  @Environment(DisplaySettings.self) private var display
  @Environment(\.isLandscape) private var isLandscape
  @Environment(\.locale) private var locale
  /// 범례 높이. 선을 이만큼 비켜 그린다
  @State private var legendHeight: CGFloat = 0

  var body: some View {
    let view = model.view
    VStack(spacing: 0) {
      GeometryReader { geometry in
        if let view {
          let axes = axes()
          // 제스처는 y축 자리를 뺀 그림 영역 폭으로 날짜를 센다
          let plotWidth = max(geometry.size.width - axes.yLabelWidth, 1)
          ZStack(alignment: .bottom) {
            CanvasCandleChart(
              series: chart.series, viewport: view.viewport, palette: display.palette,
              crosshairIndex: view.crosshairIndex, insetTop: legendHeight, axes: axes
            )
            ChartGestureSurface { model.handle($0, width: plotWidth) }
              .accessibilityIdentifier("contractChart")
            ContractLegend(chart: chart)
              .onGeometryChange(for: CGFloat.self, of: \.size.height) { legendHeight = $0 }
              .frame(maxHeight: .infinity, alignment: .top)
            if view.showsReset {
              ChartResetButton { model.view?.resetView() }
                .padding(.bottom, ChartLayout.xLabelHeight + Theme.Spacing.xs)
            }
            if model.older.isLoading {
              OlderDataIndicator()
            }
          }
        }
      }
      .sensoryFeedback(.selection, trigger: view?.crosshairIndex) { _, new in new != nil }
      .sensoryFeedback(.impact(weight: .light), trigger: model.older.startCount)
      if !isLandscape, let view {
        // 기간 선택은 C-a와 따로 기억한다(screens.md C-c)
        PeriodChips(selected: view.selectedPeriod, nearest: view.nearestPeriod) { period in
          model.view?.select(period)
          periods.contract = period
        }
      }
    }
    .background(Theme.Colors.background)
    .onChange(
      of: OlderTrigger(reports: view?.rangeReports, hasOlder: model.paged.hasOlder), initial: true
    ) {
      Task { await model.rangeReported() }
    }
    .onDisappear { model.older.cancel() }
    // 받는 동안 title-bar·tab-bar·기간 칩까지 막는다 (D-139)
    .blocksTouches(model.older.isLoading)
    .alert(
      Text("chart.olderFailedTitle"), isPresented: Bindable(model.older).showsFailure
    ) {
      Button("common.confirm", role: .cancel) {}
    } message: {
      Text("chart.olderFailedMessage")
    }
  }

  /// 보이는 범위를 알리거나 더 받을 것이 바뀌면 이전 3년을 확인한다 (RN `useOlderPages` effect `[range, hasNextPage]`)
  private struct OlderTrigger: Equatable {
    let reports: Int?
    let hasOlder: Bool
  }

  /// 축 입력. y축 라벨은 각 선의 보이는 범위 끝값을 선 색으로(D-093), 가격 점선은 없다
  private func axes() -> CandleAxes {
    CandleAxes(
      dates: chart.chart.dates, priceDecimals: chart.chart.priceDecimals,
      labels: model.endLabels(), guides: [], yLabelWidth: chart.yLabelWidth,
      monthLabelWidth: ChartText.widestMonthLabel(locale: locale), locale: locale)
  }
}

/// 차트 위 선 색 범례(가운데 정렬, 넘치면 줄바꿈). y축 끝값 라벨은 값만 쓰고 월물은 이 범례로 읽는다.
/// 대표월물 ●은 선 색이 아니라 A 목록과 같은 회색이다 (D-118)
private struct ContractLegend: View {
  let chart: ContractChartModel

  var body: some View {
    CenteredFlowLayout(spacing: Theme.Spacing.md) {
      ForEach(chart.legend, id: \.id) { item in
        HStack(spacing: Theme.Spacing.xs) {
          LegendLine(color: item.color)
          HStack(spacing: 0) {
            Text(verbatim: item.label).foregroundStyle(Theme.Colors.text)
            if item.isFront {
              Text(verbatim: ContractChartModel.frontMark)
                .foregroundStyle(Theme.Colors.textSecondary)
            }
          }
        }
      }
    }
    .font(.system(size: Theme.FontSize.caption).monospacedDigit())
    .padding(.horizontal, Theme.Spacing.lg)
    .padding(.vertical, Theme.Spacing.xs)
    .frame(maxWidth: .infinity)
    .background(Theme.Colors.overlay)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("contractsLegend")
  }
}
