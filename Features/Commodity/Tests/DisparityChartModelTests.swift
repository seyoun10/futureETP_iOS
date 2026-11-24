import Core
import Foundation
import Testing

@testable import Commodity

/// 봉 하나. 기본은 시=종, 고=종+1, 저=종−1, 이평선 없음 (RN `disparitySeries.test.ts`)
private func bar(
  _ date: String, _ close: Double, ma: Double? = nil, inRoll: Bool = false,
  holdings: [(String, Double)] = [], closeIsNull: Bool = false
) -> [String: Any] {
  [
    "tradeDate": date, "open": close, "high": close + 1, "low": close - 1,
    "close": closeIsNull ? NSNull() : close, "ma": ma ?? NSNull(), "disparity": NSNull(),
    "inRoll": inRoll,
    "holdings": holdings.map { ["contractMonth": $0.0, "weight": $0.1] },
  ]
}

private func decode<T: Decodable>(_ type: T.Type, _ object: Any) throws -> T {
  try JSONDecoder.api().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
}

private func rare(_ direction: String, _ level: Double, _ disparity: Double) -> [String: Any] {
  ["direction": direction, "level": level, "disparity": disparity, "price": NSNull()]
}

private func model(
  basis: Basis = .kr, _ bars: [[String: Any]], rareLevels: [[String: Any]] = []
) throws -> DisparityChartModel {
  DisparityChartModel(
    basis: basis, bars: try decode([DisparityBar].self, bars),
    rareLevels: try decode([RareLevelLine].self, rareLevels))
}

private let fourLevels = [
  rare("UP", 5, 10), rare("UP", 25, 4), rare("DOWN", 5, -10), rare("DOWN", 25, -4),
]

@Suite struct DisparitySeriesTests {
  @Test func dropsBarsWithoutOHLC() throws {
    let m = try model([
      bar("2026-10-20", 10), bar("2026-10-21", 11, closeIsNull: true), bar("2026-10-22", 12),
    ])
    #expect(m.bars.map(\.tradeDate.description) == ["2026-10-20", "2026-10-22"])
  }

  @Test func bandsFollowMovingAverageAndRankByRarity() throws {
    let m = try model(
      [bar("2026-10-20", 10), bar("2026-10-21", 11, ma: 100)],
      rareLevels: [rare("UP", 5, 20), rare("UP", 10, 10), rare("DOWN", 5, -20)])
    let bands = DisparityChartModel.bandLines(
      bars: m.bars,
      rareLevels: try decode(
        [RareLevelLine].self, [rare("UP", 5, 20), rare("UP", 10, 10), rare("DOWN", 5, -20)]))
    #expect(bands[0].values == [nil, 120])
    #expect(bands[2].values == [nil, 80])
    #expect(bands.map(\.id) == ["UP-5", "UP-10", "DOWN-5"])
    #expect(bands.map(\.rank) == [1, 0, 0])
  }

  @Test func envelopeIncludesLines() throws {
    let m = try model(
      [bar("2026-10-20", 10), bar("2026-10-21", 100, ma: 100)],
      rareLevels: [rare("UP", 5, 20), rare("DOWN", 5, -20)])
    #expect(m.series.high == [11, 120])
    #expect(m.series.low == [9, 80])
  }

  @Test func rollSegmentsJoinRuns() throws {
    let m = try model(
      [false, true, true, false, true].enumerated().map {
        bar("2026-10-1\($0.offset)", 10, inRoll: $0.element)
      })
    #expect(m.roll == .init(shading: [1...2, 4...4]))
  }

  @Test func frontSwitchIsDayBeforeHoldingChange() throws {
    let bars = try model([
      bar("2026-10-20", 10), bar("2026-10-21", 10, holdings: [("2026-12", 1)]),
      bar("2026-10-22", 10, holdings: [("2026-12", 1)]),
      bar("2026-10-23", 10, holdings: [("2027-02", 1)]),
    ]).bars
    let switches = DisparityChartModel.frontSwitches(bars)
    #expect(switches.map(\.index) == [2])
    #expect(switches.map(\.contractMonth.description) == ["2027-02"])
  }

  @Test func visibleStatsUseVisibleBarsOnly() throws {
    let m = try model([
      bar("2026-10-20", 10), bar("2026-10-21", 21), bar("2026-10-22", 5), bar("2026-10-23", 15),
    ])
    let stats = try #require(m.visibleStats(0...3))
    #expect(stats.highIndex == 1)
    #expect(stats.lowIndex == 2)
    #expect(abs(stats.fromLowPct - 275) < 1e-9)
    #expect(abs(stats.fromHighPct - -31.818) < 1e-3)
    let later = try #require(m.visibleStats(2...3))
    #expect(later.highIndex == 3)
    #expect(later.lowIndex == 2)
    #expect(m.visibleStats(3...9) == nil)
  }
}

@Suite struct DisparityChartModelTests {
  private func ma(
    _ date: String, _ close: Double, holdings: [(String, Double)] = [("2026-12", 1)],
    inRoll: Bool = false
  ) -> [String: Any] {
    bar(date, close, ma: close, inRoll: inRoll, holdings: holdings)
  }

  @Test func bandColorsByRankAndMovingAverageOnTop() throws {
    let m = try model([ma("2026-10-21", 100), ma("2026-10-22", 102)], rareLevels: fourLevels)
    let colors = Theme.ChartColors.rareLevels
    #expect(m.series.lines.map(\.id) == ["UP-5", "UP-25", "DOWN-5", "DOWN-25", "ma"])
    #expect(
      m.series.lines.map(\.color) == [
        colors[1], colors[0], colors[1], colors[0], Theme.ChartColors.movingAverage,
      ])
    #expect(m.series.lines[4].width > m.series.lines[0].width)
    #expect(m.lineLabels.first == .band(direction: .up, level: 5))
    #expect(m.lineLabels.last == .movingAverage)
  }

  @Test func priceLabelsAtLastBar() throws {
    let m = try model([ma("2026-10-21", 100), ma("2026-10-22", 102)], rareLevels: fourLevels)
    let labels = m.priceLabels(at: 1)
    #expect(labels.first == .init(id: "last", price: 102, color: Theme.ChartColors.lastPrice))
    #expect(!labels.contains { $0.id == "current" })
    #expect(
      labels.first { $0.id == "ma" }
        == .init(id: "ma", price: 102, color: Theme.ChartColors.movingAverage))
    #expect(labels.first { $0.id == "UP-5" }?.color == Theme.ChartColors.rareLevels[1])
  }

  @Test func priceLabelsAtVisibleBarSkipMissingLines() throws {
    let m = try model(
      [bar("2026-10-21", 100, holdings: [("2026-12", 1)]), ma("2026-10-22", 102)],
      rareLevels: fourLevels)
    #expect(
      m.priceLabels(at: 0) == [
        .init(id: "last", price: 102, color: Theme.ChartColors.lastPrice),
        .init(id: "current", price: 100, color: Theme.ChartColors.currentPrice),
      ])
    let up5 = try #require(m.priceLabels(at: 1).first { $0.id == "UP-5" })
    #expect(abs(up5.price - 112.2) < 1e-9)
    #expect(m.priceLabels(at: 5).isEmpty)
  }

  @Test func rollShadingForKRAndSwitchesForFront() throws {
    let rolling = [
      ma("2026-10-20", 100), ma("2026-10-21", 101, inRoll: true),
      ma("2026-10-22", 102, holdings: [("2027-02", 1)]),
    ]
    let kr = try model(rolling, rareLevels: fourLevels)
    #expect(kr.roll == .init(shading: [1...1]))
    #expect(kr.frontSwitchAt.isEmpty)
    let front = try model(basis: .front, rolling, rareLevels: fourLevels)
    #expect(front.roll == .init(switches: [1]))
    #expect(front.frontSwitchAt == [1: "FEB27"])
  }

  @Test func holdingsText() throws {
    let b = try model([ma("2026-10-22", 100, holdings: [("2026-12", 0.6), ("2027-01", 0.4)])]).bars[
      0]
    #expect(DisparityChartModel.holdingsText(b, basis: .kr) == "DEC26 60% · JAN27 40%")
    #expect(DisparityChartModel.holdingsText(b, basis: .front) == "DEC26")
    let first = try model([bar("2026-10-22", 100)]).bars[0]
    #expect(DisparityChartModel.holdingsText(first, basis: .kr) == nil)
  }

  @Test func tailPct() {
    #expect(DisparityChartModel.tailPct(9.4) == "9")
    #expect(DisparityChartModel.tailPct(0.42) == "0.4")
  }
}

@Suite struct PrependedBarsTests {
  private func bars(_ dates: [String]) throws -> [DisparityChartModel.Bar] {
    try model(dates.map { bar($0, 10) }).bars
  }

  @Test func countsBarsAddedBeforeTheSameLastDate() throws {
    let previous = try bars(["2026-01-05", "2026-01-06"])
    let next = try bars(["2026-01-01", "2026-01-02", "2026-01-05", "2026-01-06"])
    #expect(DisparityScreenModel.prependedBars(previous: previous, next: next) == 2)
  }

  @Test func refreshWithANewLastBarIsNotPrepended() throws {
    let previous = try bars(["2026-01-05", "2026-01-06"])
    let next = try bars(["2026-01-05", "2026-01-06", "2026-01-07"])
    #expect(DisparityScreenModel.prependedBars(previous: previous, next: next) == 0)
    #expect(DisparityScreenModel.prependedBars(previous: nil, next: next) == 0)
  }
}
