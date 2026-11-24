import Testing

@testable import Commodity

struct ChartViewStateTests {
  // 봉 756개, 6M(126봉). 폭 126pt라 봉 하나가 1pt
  private let width = 126.0
  private func make() -> ChartViewState { ChartViewState(period: .m6, barCount: 756) }

  @Test func startsAtTheRecentEndOfThePeriod() {
    let state = make()
    #expect(state.viewport == CandleViewport(barCount: 756, lower: 630, upper: 756))
    #expect(state.selectedPeriod == .m6)
    #expect(state.nearestPeriod == nil)
    #expect(!state.showsReset)
  }

  @Test func periodLongerThanTheDataShowsAllBars() {
    let state = ChartViewState(period: .m12, barCount: 100)
    #expect(state.viewport == CandleViewport(barCount: 100, lower: 0, upper: 100))
  }

  @Test func panAwayKeepsTheSelectionAndShowsReset() {
    var state = make()
    state.handle(.dragged(deltaX: 30, x: 60), width: width)
    #expect(state.viewport.lower == 600)
    #expect(state.selectedPeriod == .m6)
    #expect(state.showsReset)
  }

  @Test func pushingPastTheRecentEndIsNotAway() {
    var state = make()
    state.handle(.dragged(deltaX: -30, x: 60), width: width)
    #expect(!state.showsReset)
  }

  @Test func panningBackHomeClearsAway() {
    var state = make()
    state.handle(.dragged(deltaX: 30, x: 60), width: width)
    state.handle(.dragged(deltaX: -30, x: 60), width: width)
    #expect(!state.showsReset)
  }

  @Test func pinchClearsTheSelectionAndMarksTheNearestPeriod() {
    var state = make()
    state.handle(.pinched(scale: 0.5, startFocalX: 63, focalX: 63), width: width)
    #expect(state.viewport.span == 252)
    #expect(state.selectedPeriod == nil)
    #expect(state.nearestPeriod == .m12)
    #expect(state.showsReset)
    // 핀치 뒤 끌어도 선택 표시를 되살리지 않는다
    state.handle(.pinchEnded, width: width)
    state.handle(.dragged(deltaX: 10, x: 60), width: width)
    #expect(state.selectedPeriod == nil)
  }

  @Test func pinchAfterPanBecomesZoom() {
    var state = make()
    state.handle(.dragged(deltaX: 30, x: 60), width: width)
    state.handle(.pinched(scale: 2, startFocalX: 63, focalX: 63), width: width)
    #expect(state.selectedPeriod == nil)
  }

  @Test func dragWithACrosshairMovesOnlyTheCrosshair() {
    var state = make()
    state.handle(.pressed(x: 10), width: width)
    state.handle(.dragged(deltaX: 30, x: 40), width: width)
    #expect(state.crosshairIndex == 670)
    #expect(!state.showsReset)
  }

  @Test func selectAndResetGoHomeAndClearTheCrosshair() {
    var state = make()
    state.handle(.pinched(scale: 0.5, startFocalX: 63, focalX: 63), width: width)
    state.handle(.pinchEnded, width: width)
    state.handle(.pressed(x: 10), width: width)
    state.select(.m2)
    #expect(state.viewport == CandleViewport(barCount: 756, lower: 714, upper: 756))
    #expect(state.selectedPeriod == .m2)
    #expect(state.crosshairIndex == nil)
    state.handle(.dragged(deltaX: 30, x: 60), width: width)
    state.handle(.pressed(x: 10), width: width)
    state.resetView()
    #expect(!state.showsReset)
    #expect(state.crosshairIndex == nil)
    #expect(state.viewport.lower == 714)
  }

  @Test func dataChangeAtHomeRefitsTheRecentEnd() {
    var state = make()
    state.handle(.pressed(x: 10), width: width)
    state.dataChanged(barCount: 757, prepended: 0)
    #expect(state.viewport == CandleViewport(barCount: 757, lower: 631, upper: 757))
    #expect(state.crosshairIndex == nil)
  }

  @Test func dataChangeAwayKeepsTheViewedDates() {
    var state = make()
    state.handle(.dragged(deltaX: 126, x: 60), width: width)
    #expect(state.viewport.lower == 504)
    state.dataChanged(barCount: 1_512, prepended: 756)
    #expect(state.viewport == CandleViewport(barCount: 1_512, lower: 1_260, upper: 1_386))
    #expect(state.showsReset)
  }
}
