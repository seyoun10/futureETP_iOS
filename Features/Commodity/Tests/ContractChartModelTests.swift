import Core
import Foundation
import Testing

@testable import Commodity

/// RN `contractChartModel.test.ts`
private func line(
  _ symbol: String, _ month: String, last: String, front: Bool = false, _ prices: [Double?]
) -> ContractLine {
  ContractLine(
    symbol: symbol, contractMonth: ContractMonth(month)!, lastTradeDate: LocalDate(last)!,
    isFront: front, prices: prices)
}

private func chart(_ contracts: [ContractLine]) -> ContractsChart {
  let dates = ["2026-10-20", "2026-10-21", "2026-10-22"].map { LocalDate($0)! }
  return ContractsChart(
    freshness: Freshness(
      asOf: Date(timeIntervalSince1970: 0), tradeDate: dates[2], delayed: true,
      marketState: .open, nextUpdateAt: nil),
    priceDecimals: 3, dates: dates, hasMore: false, provisional: true, contracts: contracts)
}

private let twoLines = chart([
  line("NGZ26", "2026-12", last: "2026-11-25", front: true, [3.1, 3.2, 3.3]),
  line("NGF27", "2027-01", last: "2026-12-28", [nil, 3.5, nil]),
])

@Suite struct ContractChartModelTests {
  let model = ContractChartModel(twoLines)
  let colors = Theme.ChartColors.contractLines

  @Test func linesUseColorsByMaturityOrder() {
    #expect(model.lines.map(\.id) == ["NGZ26", "NGF27"])
    #expect(model.lines.map(\.color) == [colors[0], colors[1]])
  }

  @Test func envelopeUsesLinesWithValueOnEachDate() {
    #expect(model.high == [3.1, 3.5, 3.3])
    #expect(model.low == [3.1, 3.2, 3.3])
  }

  @Test func legendIsLineColorAndMonthWithFrontMark() {
    #expect(
      model.legend == [
        .init(id: "NGZ26", color: colors[0], label: "DEC26", isFront: true),
        .init(id: "NGF27", color: colors[1], label: "JAN27", isFront: false),
      ])
  }

  @Test func endLabelsAreLastValueOfEachLineInVisibleRange() {
    #expect(
      model.visibleEndLabels(0...2) == [
        .init(id: "NGZ26", price: 3.3, color: colors[0]),
        .init(id: "NGF27", price: 3.5, color: colors[1]),
      ])
    // 과거로 옮기면 그 범위 끝의 값
    #expect(model.visibleEndLabels(0...1).map(\.price) == [3.2, 3.5])
    // 범위 안에 값이 없는 선은 라벨이 없다
    #expect(model.visibleEndLabels(0...0).map(\.id) == ["NGZ26"])
  }

  @Test func lineWithoutValuesHasNoLabels() {
    let empty = ContractChartModel(
      chart([line("NGZ26", "2026-12", last: "2026-11-25", front: true, [nil, nil, nil])]))
    #expect(empty.visibleEndLabels(0...2).isEmpty)
    #expect(empty.widestLabels.isEmpty)
  }

  @Test func widestLabelIsLongestTextIncludingNegatives() {
    let wide = ContractChartModel(
      chart([line("CLK20", "2020-05", last: "2020-04-21", front: true, [18.27, -37.63, 10.01])]))
    #expect(wide.widestLabels.map(\.price) == [-37.63])
    #expect(model.widestLabels.map(\.price) == [3.3, 3.5])
  }

  @Test func linesAfterSixthShareLastColor() {
    let many = ContractChartModel(
      chart(
        (0..<7).map { line("S\($0)", "2027-01", last: "2026-12-28", [1, 1, 1]) }))
    #expect(many.lines[6].color == colors[5])
  }

  @Test func rollYieldIsAnnualizedBetweenEndContractsOfTheDay() throws {
    let m = ContractChartModel(
      chart([
        line("NGZ26", "2026-12", last: "2026-11-25", front: true, [3.3, 3.3, 3.3]),
        line("NGF27", "2027-01", last: "2026-12-28", [nil, 3.0, nil]),
        line("NGG27", "2027-02", last: "2027-01-27", [nil, 3.0, 3.0]),
      ]))
    // 값이 하나뿐이면 없다
    #expect(m.endsRollYieldPct(at: 0) == nil)
    // 가장 먼 값은 NGG27(63일): (3.3 / 3.0 − 1) × 365 / 63 × 100
    let expected = 0.1 * 365 * 100 / 63
    #expect(abs(try #require(m.endsRollYieldPct(at: 1)) - expected) < 1e-9)
    // 가운데 월물이 비어도 양끝으로 센다
    #expect(abs(try #require(m.endsRollYieldPct(at: 2)) - expected) < 1e-9)
  }

  @Test func rollYieldIsNilForNonPositiveValueOrSameMaturity() {
    let m = ContractChartModel(
      chart([
        line("A", "2026-12", last: "2026-11-25", front: true, [-1, 3, 3]),
        line("B", "2027-01", last: "2026-12-28", [3, nil, nil]),
        line("C", "2027-01", last: "2026-11-25", [nil, nil, 3]),
      ]))
    #expect(m.endsRollYieldPct(at: 0) == nil)
    #expect(m.endsRollYieldPct(at: 2) == nil)
    #expect(m.endsRollYieldPct(at: 5) == nil)
  }
}

@Suite struct ContractScreenModelTests {
  private let dates = ["2026-10-20", "2026-10-21", "2026-10-22"].map { LocalDate($0)! }

  @Test func prependedDatesCountsOnlyOlderDatesWithSameLastDate() {
    let older = [LocalDate("2026-10-16")!, LocalDate("2026-10-19")!] + dates
    #expect(ContractScreenModel.prependedDates(previous: dates, next: older) == 2)
    // 새로고침으로 오늘이 붙으면 앞에 붙은 것이 아니다
    #expect(
      ContractScreenModel.prependedDates(previous: dates, next: dates + [LocalDate("2026-10-23")!])
        == 0)
    #expect(ContractScreenModel.prependedDates(previous: nil, next: dates) == 0)
  }

  @Test func yLabelWidthFitsLongestEndValue() {
    let wide = ContractChartModel(
      chart([line("CLK20", "2020-05", last: "2020-04-21", front: true, [18.27, -37.63, 10.01])]))
    #expect(
      wide.yLabelWidth
        == ChartText.width(NumberFormat.price(-37.63, decimals: 3)) + Double(ChartLayout.yLabelPad))
    #expect(!wide.series.isLog)
  }
}
