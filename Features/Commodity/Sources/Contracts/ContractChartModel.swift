import Core
import SwiftUI

/// C-c 응답 → 선 차트 입력(선 색·y 자동 맞춤 범위·끝값 라벨)과 범례·롤 수익률. 순수 값이다
/// (RN `contractChartModel.ts`, screens.md C-c, D-092, D-093)
struct ContractChartModel {
  /// 차트 위 선 색 범례 항목(만기순). 대표월물은 A처럼 ● 표식
  struct LegendItem: Equatable, Sendable {
    let id: String
    let color: Color
    let label: String
    let isFront: Bool
  }

  typealias PriceLabel = ChartPriceLabel

  /// 대표월물 표식(A 원자재 목록과 같다)
  static let frontMark = "●"
  static let lineWidth = 1.0

  let chart: ContractsChart
  /// 만기순. 선 id는 월물 심볼
  let lines: [CandleSeries.Line]
  /// 날짜마다 그날 값이 있는 선들의 위·아래 끝. 값이 없는 날은 −∞·+∞
  let high: [Double]
  let low: [Double]
  /// 선마다 글자가 가장 긴 값의 라벨. 이동해도 우측 라벨 자리가 바뀌지 않게 너비만 잰다
  let widestLabels: [PriceLabel]
  let legend: [LegendItem]
  /// 차트 입력(선만 있음). 0 이하 값이 있으면 선형 y축(D-113)
  let series: CandleSeries

  init(_ chart: ContractsChart) {
    self.chart = chart
    lines = chart.contracts.enumerated().map { i, c in
      CandleSeries.Line(
        id: c.symbol, values: c.prices, color: Self.lineColor(i), width: Self.lineWidth)
    }
    var high = chart.dates.map { _ in -Double.infinity }
    var low = chart.dates.map { _ in Double.infinity }
    for c in chart.contracts {
      for (i, value) in c.prices.enumerated() where i < high.count {
        guard let value else { continue }
        if value > high[i] { high[i] = value }
        if value < low[i] { low[i] = value }
      }
    }
    self.high = high
    self.low = low
    series = CandleSeries(lines: lines, high: high, low: low)
    widestLabels = chart.contracts.enumerated().compactMap { i, c in
      let values = c.prices.compactMap(\.self)
      guard let min = values.min(), let max = values.max() else { return nil }
      let width = { (v: Double) in NumberFormat.price(v, decimals: chart.priceDecimals).count }
      return Self.label(chart, i, width(min) > width(max) ? min : max)
    }
    legend = chart.contracts.enumerated().map { i, c in
      LegendItem(
        id: c.symbol, color: Self.lineColor(i),
        label: NumberFormat.contractMonth(c.contractMonth), isFront: c.isFront)
    }
  }

  /// 우측 y축 자리: 가장 긴 끝값 라벨(없으면 `0`) + 여백 (RN `LinesChart` `yLabelWidth`)
  var yLabelWidth: Double {
    let widths = widestLabels.map {
      ChartText.width(NumberFormat.price($0.price, decimals: chart.priceDecimals))
    }
    return max(ChartText.width("0"), widths.max() ?? 0) + Double(ChartLayout.yLabelPad)
  }

  /// 6번째 이후 선은 마지막 색을 같이 쓴다
  static func lineColor(_ index: Int) -> Color {
    let colors = Theme.ChartColors.contractLines
    return colors[min(max(index, 0), colors.count - 1)]
  }

  private static func label(_ chart: ContractsChart, _ index: Int, _ price: Double) -> PriceLabel {
    PriceLabel(id: chart.contracts[index].symbol, price: price, color: lineColor(index))
  }

  /// 보이는 범위 `indices`에서 각 선의 마지막 값(D-093). 범위 안에 값이 없는 선은 라벨도 없다
  func visibleEndLabels(_ indices: ClosedRange<Int>) -> [PriceLabel] {
    chart.contracts.enumerated().compactMap { i, c in
      let upper = min(indices.upperBound, c.prices.count - 1)
      let lower = max(indices.lowerBound, 0)
      guard lower <= upper,
        let price = (lower...upper).reversed().lazy.compactMap({ c.prices[$0] }).first
      else { return nil }
      return Self.label(chart, i, price)
    }
  }

  /// 그날 양끝 월물(값이 있는 가장 가까운·먼 만기)의 연환산 롤 수익률(%).
  /// (near / far − 1) × 365 / 두 최종 거래일 사이 일수 × 100. 양수 = 백워데이션(롤 이익). C-b의 M1→M2 롤 수익률과 같은 식.
  /// 값이 있는 월물이 둘 미만이거나 값이 0 이하이거나 최종 거래일이 같으면 nil
  func endsRollYieldPct(at index: Int) -> Double? {
    // 만기가 같으면 응답 순서(RN의 안정 정렬과 같게)
    let priced = chart.contracts.enumerated()
      .compactMap { i, c -> (order: Int, price: Double, lastTradeDate: LocalDate)? in
        guard c.prices.indices.contains(index), let price = c.prices[index] else { return nil }
        return (i, price, c.lastTradeDate)
      }
      .sorted { ($0.lastTradeDate, $0.order) < ($1.lastTradeDate, $1.order) }
    guard priced.count >= 2, let near = priced.first, let far = priced.last,
      near.price > 0, far.price > 0
    else { return nil }
    let days = near.lastTradeDate.days(to: far.lastTradeDate)
    guard days > 0 else { return nil }
    return (near.price / far.price - 1) * 365 / Double(days) * 100
  }
}
