import Core
import Observation

/// C-a 화면 Model: 받은 페이지 → 차트 계열(`DisparityChartModel`)과 기간·제스처 상태(`ChartViewState`).
/// 데이터가 바뀌면 계열을 다시 만들고, 과거 봉이 앞에 붙었으면 보던 날짜 범위를 유지한다 (D-104, RN `DisparityChartScreen`)
@MainActor
@Observable
final class DisparityScreenModel {
  let paged: PagedQuery<DisparityChart>
  /// 최근 페이지(봉 밖 값: 기준값·rare 레벨·freshness 등)
  private(set) var latest: DisparityChart?
  private(set) var chart: DisparityChartModel?
  /// 첫 데이터가 와서 기간을 맞춘 뒤 생긴다. 그 전에는 차트 대신 스켈레톤
  var view: ChartViewState?

  @ObservationIgnored private var pages: [DisparityChart] = []

  init(paged: PagedQuery<DisparityChart>) {
    self.paged = paged
  }

  var query: Query<ChartPages<DisparityChart>> { paged.query }

  /// 조회 데이터가 바뀌었다. 같은 값이면(자동 새로고침으로 바뀐 것이 없음) 십자선·범위를 건드리지 않는다
  func dataChanged(period: ChartPeriod) {
    guard let data = query.state.data, data.pages != pages else { return }
    pages = data.pages
    let previous = chart?.bars
    let next = DisparityChartModel(
      basis: data.latest.basis, bars: data.joined(\.bars), rareLevels: data.latest.rareLevels)
    latest = data.latest
    chart = next
    if view == nil {
      view = ChartViewState(period: period, barCount: next.bars.count)
    } else {
      view?.dataChanged(
        barCount: next.bars.count,
        prepended: Self.prependedBars(previous: previous, next: next.bars))
    }
  }

  /// 앞에 붙은 봉 수. 첫 날짜가 앞당겨지고 마지막 날짜가 같을 때만이다(새로고침으로 오늘 봉이 붙는 경우와 구분)
  /// (RN `viewportChange.ts` `prependedBars`)
  static func prependedBars(
    previous: [DisparityChartModel.Bar]?, next: [DisparityChartModel.Bar]
  ) -> Int {
    guard let previous, let oldFirst = previous.first?.tradeDate,
      let newFirst = next.first?.tradeDate, newFirst < oldFirst,
      previous.last?.tradeDate == next.last?.tradeDate
    else { return 0 }
    return next.count - previous.count
  }
}
