import Core
import SwiftUI

/// C-a 이격도차트 탭(screens.md C-a, D-086, D-087). 설정(기준값·이평선·윈도·rare 레벨)을 먼저 읽고 그 값으로 조회한다.
/// 설정이 바뀌면 키가 바뀌어 새 조회와 새 화면 상태로 바꾼다 (RN `DisparityChartScreen`·`useDisparityChart`)
struct DisparityTabView: View {
  let code: CommodityCode
  let settings: SettingsStore
  let queries: CommodityQueries

  var body: some View {
    if let values = settings.data {
      if let query = Self.query(values) {
        DisparityChartContent(paged: queries.disparity(code, query))
          .id(QueryKeys.disparity(code, query: query))
      } else {
        // 서버가 검증한 값이라 생기지 않는다
        ErrorView(AppError(.schemaMismatch)) { Task { await settings.query.refetch() } }
      }
    } else if let error = settings.query.state.error, !settings.query.state.isFetching {
      // 설정을 못 읽으면 C-a 조회를 시작할 수 없어 설정 오류를 보여 준다
      ErrorView(error) { Task { await settings.query.refetch() } }
    } else {
      ChartSkeleton()
    }
  }

  static func query(_ settings: AppSettings) -> DisparityQuery? {
    RareLevels(settings.rareLevels).map {
      DisparityQuery(
        basis: settings.basis, maPeriod: settings.maPeriod, window: settings.window, levels: $0)
    }
  }
}

/// 조회 상태(첫 로딩은 차트 모양 스켈레톤, 오류는 재시도)와 차트
private struct DisparityChartContent: View {
  @State private var model: DisparityScreenModel
  @Environment(ChartPeriods.self) private var periods

  init(paged: PagedQuery<DisparityChart>) {
    _model = State(initialValue: DisparityScreenModel(paged: paged))
  }

  var body: some View {
    QueryStateView(
      model.query.state, retry: { Task { await model.query.refetch() } },
      skeleton: { ChartSkeleton() }
    ) { _ in
      if let chart = model.chart, let latest = model.latest, model.view != nil {
        if chart.bars.isEmpty {
          ChartTabMessage(key: "disparity.noData")
        } else {
          DisparityChartView(model: model, chart: chart, data: latest)
        }
      } else {
        ChartSkeleton()
      }
    }
    .queryLifecycle(model.query)
    .tabFooterTime(model.latest.map { .market($0.freshness) })
    .onChange(of: model.query.dataUpdatedAt, initial: true) {
      model.dataChanged(period: periods.disparity)
    }
  }
}

/// 차트, [↻], 기간 칩. 가로 모드는 기간 칩을 숨긴다 (D-103)
private struct DisparityChartView: View {
  let model: DisparityScreenModel
  let chart: DisparityChartModel
  let data: DisparityChart
  @Environment(ChartPeriods.self) private var periods
  @Environment(DisplaySettings.self) private var display
  @Environment(\.isLandscape) private var isLandscape

  var body: some View {
    let view = model.view
    VStack(spacing: 0) {
      GeometryReader { geometry in
        let width = geometry.size.width
        let plotHeight = max(geometry.size.height - ChartLayout.xLabelHeight, 0)
        if let view {
          ZStack(alignment: .bottom) {
            CanvasCandleChart(
              series: chart.series, viewport: view.viewport, palette: display.palette,
              crosshairIndex: view.crosshairIndex
            )
            .frame(width: width, height: plotHeight)
            .frame(maxHeight: .infinity, alignment: .top)
            ChartGestureSurface { model.view?.handle($0, width: width) }
              .accessibilityIdentifier("disparityChart")
            if view.showsReset {
              ChartResetButton { model.view?.resetView() }
                .padding(.bottom, ChartLayout.xLabelHeight + Theme.Spacing.xs)
            }
          }
        }
      }
      .sensoryFeedback(.selection, trigger: view?.crosshairIndex) { _, new in new != nil }
      if !isLandscape, let view {
        PeriodChips(selected: view.selectedPeriod, nearest: view.nearestPeriod) { period in
          model.view?.select(period)
          periods.disparity = period
        }
      }
    }
    .background(Theme.Colors.background)
  }
}
