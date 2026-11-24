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
        DisparityChartContent(
          code: code, requestedBasis: values.basis, paged: queries.disparity(code, query)
        )
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
  let code: CommodityCode
  let requestedBasis: Basis
  @State private var model: DisparityScreenModel
  @Environment(ChartPeriods.self) private var periods

  init(code: CommodityCode, requestedBasis: Basis, paged: PagedQuery<DisparityChart>) {
    self.code = code
    self.requestedBasis = requestedBasis
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
          DisparityChartView(
            code: code, requestedBasis: requestedBasis, model: model, chart: chart, data: latest)
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
  let code: CommodityCode
  let requestedBasis: Basis
  let model: DisparityScreenModel
  let chart: DisparityChartModel
  let data: DisparityChart
  @Environment(ChartPeriods.self) private var periods
  @Environment(DisplaySettings.self) private var display
  @Environment(\.isLandscape) private var isLandscape
  @Environment(\.locale) private var locale
  /// 정보 줄 높이. 봉·선을 이만큼 비켜 그린다
  @State private var infoHeight: CGFloat = 0

  var body: some View {
    let view = model.view
    VStack(spacing: 0) {
      GeometryReader { geometry in
        if let view {
          let axes = axes(visible: view.viewport.visibleIndices)
          // 제스처는 y축 자리를 뺀 그림 영역 폭으로 봉을 센다
          let plotWidth = max(geometry.size.width - axes.yLabelWidth, 1)
          ZStack(alignment: .bottom) {
            CanvasCandleChart(
              series: chart.series, viewport: view.viewport, palette: display.palette,
              crosshairIndex: view.crosshairIndex, insetTop: infoHeight, axes: axes
            )
            ChartGestureSurface { model.view?.handle($0, width: plotWidth) }
              .accessibilityIdentifier("disparityChart")
            DisparityInfoLines(
              code: code, requestedBasis: requestedBasis, data: data, chart: chart,
              visible: view.viewport.visibleIndices, onHeight: { infoHeight = $0 }
            )
            .frame(maxHeight: .infinity, alignment: .top)
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

  /// 축 입력. y축 라벨·점선은 보이는 마지막 봉 값이다 (RN `DisparityChartView` `labelIndex`)
  private func axes(visible: ClosedRange<Int>?) -> CandleAxes {
    let index = min(visible?.upperBound ?? chart.bars.count - 1, chart.bars.count - 1)
    let guides: [(price: Double, color: Color)] =
      chart.bars.indices.contains(index) && !chart.bars.isEmpty
      ? [
        (chart.bars[index].close, Theme.ChartColors.currentPrice),
        // 마지막 봉이 보이면 두 점선이 겹치므로 흰색을 위에 그린다
        (chart.bars[chart.bars.count - 1].close, Theme.ChartColors.lastPrice),
      ] : []
    return CandleAxes(
      dates: chart.dates, priceDecimals: data.priceDecimals,
      labels: chart.priceLabels(at: index), guides: guides,
      yLabelWidth: chart.yLabelWidth(decimals: data.priceDecimals),
      monthLabelWidth: ChartText.widestMonthLabel(locale: locale), locale: locale,
      roll: chart.roll,
      extremes: guides.first.map { gray in
        .init(currentPrice: chart.bars[chart.bars.count - 1].close, guidePrice: gray.price)
      })
  }
}

/// 차트 위에 반투명 배경으로 겹친 정보 줄 두 줄(가운데 정렬, D-117). 첫 줄은 기준값 · 오늘 시고저종이고 십자선과 상관없이
/// 오늘 값이다. 기준값을 누르면 안내가 열린다. 둘째 줄은 이격도(꼬리 백분위) · 저점대비 · 고점대비(보이는 봉 기준)
private struct DisparityInfoLines: View {
  let code: CommodityCode
  let requestedBasis: Basis
  let data: DisparityChart
  let chart: DisparityChartModel
  let visible: ClosedRange<Int>?
  /// 정보 줄(안내 상자 제외) 높이
  let onHeight: (CGFloat) -> Void
  @State private var showsHint = false
  @Environment(\.locale) private var locale

  var body: some View {
    let t: DisparityInfo.Translate = { L10n.string($0, $1, locale: locale) }
    VStack(spacing: 0) {
      lines(t: t)
      // 안내는 첫 줄 바로 아래부터 차트 위에 겹친다
      if showsHint {
        hint(t: t)
          .padding(.top, -InfoLineStyle.lineHeight)
      }
    }
  }

  private func lines(t: DisparityInfo.Translate) -> some View {
    VStack(spacing: 0) {
      if let today = chart.bars.last {
        HStack(spacing: 0) {
          Button {
            showsHint.toggle()
          } label: {
            Text(verbatim: DisparityInfo.basisLabel(data, today: today, t: t))
              .fontWeight(.semibold)
              .underline()
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("disparityBasis")
          Text(verbatim: " · " + DisparityInfo.ohlc(today, decimals: data.priceDecimals, t: t))
        }
        .modifier(InfoLineStyle())
      }
      Text(verbatim: DisparityInfo.stats(data, chart: chart, visible: visible, t: t))
        .modifier(InfoLineStyle())
        .accessibilityIdentifier("disparityStats")
    }
    .frame(maxWidth: .infinity)
    .background(Theme.Colors.overlay)
    .onGeometryChange(for: CGFloat.self, of: \.size.height, action: onHeight)
  }

  private func hint(t: DisparityInfo.Translate) -> some View {
    Button {
      showsHint = false
    } label: {
      VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
        ForEach(
          DisparityInfo.hints(data, code: code, requestedBasis: requestedBasis, t: t), id: \.self
        ) { Text(verbatim: $0) }
      }
      .font(.system(size: Theme.FontSize.caption))
      .foregroundStyle(Theme.Colors.text)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(Theme.Spacing.md)
      .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Spacing.sm))
    }
    .buttonStyle(.plain)
    .padding(.horizontal, Theme.Spacing.lg)
    .accessibilityIdentifier("disparityHint")
  }
}

/// 정보 줄 한 줄: 작은 글자, 숫자 고정폭, 넘치면 줄여서 한 줄
private struct InfoLineStyle: ViewModifier {
  /// 한 줄 높이 어림(안내 상자를 둘째 줄 위에 겹칠 때)
  static let lineHeight = Theme.FontSize.caption + 2 * Theme.Spacing.xs + 3

  func body(content: Content) -> some View {
    content
      .font(.system(size: Theme.FontSize.caption).monospacedDigit())
      .foregroundStyle(Theme.Colors.text)
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .padding(.horizontal, Theme.Spacing.lg)
      .padding(.vertical, Theme.Spacing.xs)
  }
}
