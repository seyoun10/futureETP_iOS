import Core
import Foundation
import Testing

@testable import Commodity

struct AxisTicksTests {
  @Test func narrowLogRangeFallsBackToLinearTicks() {
    // 범위 안 k·10^n이 2000 하나라 d3처럼 선형 눈금을 쓴다
    #expect(AxisTicks.log(from: 2000, to: 2500) == [2000, 2100, 2200, 2300, 2400, 2500])
  }

  @Test func wideLogRangeUsesPowerMultiples() {
    #expect(AxisTicks.log(from: 50, to: 200) == [50, 60, 70, 80, 90, 100, 200])
    #expect(AxisTicks.log(from: 200, to: 50) == [50, 60, 70, 80, 90, 100, 200])
  }

  @Test func nonPositiveRangeHasNoTicks() {
    #expect(AxisTicks.log(from: 0, to: 10).isEmpty)
  }

  @Test func linearTicksUseNiceSteps() {
    #expect(
      AxisTicks.linear(from: 0.12, to: 0.18, count: 6) == [
        0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18,
      ])
    #expect(AxisTicks.linear(from: 1, to: 1, count: 6) == [1])
  }

  @Test func decimalsFollowTickStepUpToPriceDecimals() {
    #expect(AxisTicks.decimals([2000, 2100, 2200], max: 2) == 0)
    #expect(AxisTicks.decimals([0.12, 0.13], max: 4) == 2)
    #expect(AxisTicks.decimals([0.12, 0.13], max: 1) == 1)
    #expect(AxisTicks.decimals([5], max: 3) == 3)
  }
}

struct PriceLabelLayoutTests {
  @Test func clampKeepsHalfHeightInside() {
    #expect(PriceLabelLayout.clampY(0, height: 14, top: 0, bottom: 500) == 7)
    #expect(PriceLabelLayout.clampY(250, height: 14, top: 0, bottom: 500) == 250)
    #expect(PriceLabelLayout.clampY(500, height: 14, top: 0, bottom: 500) == 493)
  }

  @Test func overlapIsCloserThanHeight() {
    #expect(PriceLabelLayout.overlapsAny(110, [100], height: 14))
    #expect(!PriceLabelLayout.overlapsAny(114, [100], height: 14))
  }

  @Test func overlappingLabelsArePushedDown() {
    let stacked = PriceLabelLayout.stack(
      [("b", 105), ("a", 100), ("c", 200)], height: 14, top: 0, bottom: 500)
    #expect(stacked.map(\.label) == ["a", "b", "c"])
    #expect(stacked.map(\.y) == [100, 114, 200])
  }

  @Test func labelsPastTheBottomArePushedBackUp() {
    let stacked = PriceLabelLayout.stack(
      [("a", 490), ("b", 495), ("c", 500)], height: 14, top: 0, bottom: 500)
    #expect(stacked.map(\.y) == [465, 479, 493])
  }

  @Test func labelsOutsideTheChartAreDropped() {
    let stacked = PriceLabelLayout.stack(
      [("above", -5), ("in", 50), ("in2", 55)], height: 14, top: 0, bottom: 500)
    #expect(stacked.map(\.label) == ["in", "in2"])
  }
}

struct MonthTicksTests {
  /// 2010-06-01부터 평일 4,000개(휴장일은 무시)
  static let dates: [LocalDate] = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    var day = calendar.date(from: DateComponents(year: 2010, month: 6, day: 1))!
    var dates: [LocalDate] = []
    while dates.count < 4000 {
      let c = calendar.dateComponents([.year, .month, .day, .weekday], from: day)
      if c.weekday != 1, c.weekday != 7 {
        dates.append(LocalDate(year: c.year!, month: c.month!, day: c.day!)!)
      }
      day = calendar.date(byAdding: .day, value: 1, to: day)!
    }
    return dates
  }()

  static func index(_ string: String) -> Int {
    let date = LocalDate(string)!
    return dates.firstIndex { $0 >= date }!
  }

  @Test func everyMonthWhenWideEnough() {
    let ticks = MonthTicks.ticks(
      dates: Self.dates, range: Self.index("2010-11-01")...Self.index("2011-03-15"), minGap: 10)
    #expect(
      ticks.map { [$0.year, $0.month] } == [
        [2010, 11], [2010, 12], [2011, 1], [2011, 2], [2011, 3],
      ]
    )
  }

  @Test func widerStepWhenNeighborsAreTooClose() {
    let ticks = MonthTicks.ticks(
      dates: Self.dates, range: Self.index("2010-11-01")...Self.index("2011-08-15"), minGap: 30)
    #expect(
      ticks.map { [$0.year, $0.month] } == [
        [2010, 11], [2011, 1], [2011, 3], [2011, 5], [2011, 7],
      ]
    )
  }

  @Test func longRangeKeepsMinimumGap() {
    let ticks = MonthTicks.ticks(dates: Self.dates, range: 0...(Self.dates.count - 1), minGap: 300)
    #expect(!ticks.isEmpty)
    #expect(zip(ticks, ticks.dropFirst()).allSatisfy { $1.index - $0.index >= 300 })
  }

  @Test func ticksSitOnFirstTradingDayOfMonth() {
    for tick in MonthTicks.ticks(dates: Self.dates, range: 0...500, minGap: 1) {
      #expect(Self.dates[tick.index].month != Self.dates[tick.index - 1].month)
    }
  }

  @Test func januaryShowsTheYear() {
    #expect(MonthTicks.label(year: 2027, month: 1, locale: Locale(identifier: "ko")) == "2027")
  }
}

struct PriceScaleInverseTests {
  @Test func priceAtYInvertsY() {
    let scale = PriceScale(logLow: log(100), logHigh: log(200))
    for price in [100.0, 137.5, 200] {
      #expect(abs(scale.price(atY: scale.y(price, height: 300), height: 300) - price) < 1e-9)
    }
  }
}
