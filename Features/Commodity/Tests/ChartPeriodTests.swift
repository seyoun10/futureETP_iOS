import Testing

@testable import Commodity

/// RN `charts/chartPeriods.test.ts`와 같은 경우
struct ChartPeriodTests {
  @Test func nearestPicksTheClosestRatio() {
    #expect(ChartPeriod.nearest(visibleBars: 126, totalBars: 4000) == .m6)
    #expect(ChartPeriod.nearest(visibleBars: 140, totalBars: 4000) == .m6)
    #expect(ChartPeriod.nearest(visibleBars: 30, totalBars: 4000) == .m2)
  }

  @Test func widerThanTheLongestPeriodIs12M() {
    #expect(ChartPeriod.nearest(visibleBars: 1000, totalBars: 4000) == .m12)
  }

  @Test func periodsLongerThanTheDataShrinkToItAndTiesPickTheShorter() {
    // 봉 150개: 8M(168)·10M·12M은 모두 150개로 같다
    #expect(ChartPeriod.nearest(visibleBars: 150, totalBars: 150) == .m8)
    #expect(ChartPeriod.nearest(visibleBars: 120, totalBars: 150) == .m6)
  }

  @Test func eachCommodityStartsAt6M() {
    let periods = ChartPeriods()
    #expect(periods.disparity == .m6)
    #expect(periods.contract == .m6)
  }

  @Test func onlyChartTabsRotate() {
    #expect(CommodityTab.allCases.filter(\.canRotate) == [.disparity, .contracts, .curve])
  }
}
