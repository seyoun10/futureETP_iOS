import Foundation
import Testing

@testable import Commodity

struct CandleViewportTests {
  @Test func lastBarsShowsTheEnd() {
    let viewport = CandleViewport.lastBars(252, of: 756)
    #expect(viewport.lower == 504)
    #expect(viewport.upper == 756)
    #expect(viewport.visibleIndices == 504...755)
  }

  @Test func spanIsClampedBetweenMinimumAndAll() {
    #expect(CandleViewport(barCount: 756, lower: 100, upper: 105).span == 20)
    #expect(CandleViewport(barCount: 756, lower: -100, upper: 900).span == 756)
    // 봉이 최소 봉 수보다 적으면 전체
    #expect(CandleViewport(barCount: 8, lower: 0, upper: 2).span == 8)
  }

  @Test func panStopsAtDataEdges() {
    let viewport = CandleViewport.lastBars(252, of: 756)
    #expect(viewport.panned(byBars: 50).upper == 756)
    let past = viewport.panned(byBars: -1_000)
    #expect(past.lower == 0)
    #expect(past.span == 252)
  }

  @Test func zoomKeepsTheAnchorBarUnderTheFingers() {
    let viewport = CandleViewport(barCount: 756, lower: 200, upper: 400)
    // 가운데(0.5)를 2배 확대하면 가운데 봉(300)이 그대로 가운데에 남는다
    let zoomed = viewport.zoomed(scale: 2, startAnchor: 0.5, anchor: 0.5)
    #expect(zoomed.lower == 250)
    #expect(zoomed.upper == 350)
    // 최대 확대를 넘겨도 앵커 기준으로 최소 봉 수에서 멈춘다
    let maxed = viewport.zoomed(scale: 100, startAnchor: 0.5, anchor: 0.5)
    #expect(maxed.lower == 290)
    #expect(maxed.upper == 310)
  }

  @Test func zoomOutBeyondAllShowsAll() {
    let viewport = CandleViewport(barCount: 756, lower: 600, upper: 700)
    let zoomed = viewport.zoomed(scale: 0.01, startAnchor: 0.9, anchor: 0.9)
    #expect(zoomed.lower == 0)
    #expect(zoomed.upper == 756)
  }

  @Test func partialBarsAtTheEdgesAreVisible() {
    let viewport = CandleViewport(barCount: 100, lower: 10.5, upper: 40.2)
    #expect(viewport.visibleIndices == 10...40)
  }

  @Test func barCenterAndHitTestAreInverse() {
    let viewport = CandleViewport(barCount: 100, lower: 10, upper: 30)
    let x = viewport.centerX(ofBar: 15, width: 200)
    #expect(x == 55)
    #expect(viewport.barIndex(atX: x, width: 200) == 15)
    #expect(viewport.barIndex(atX: -50, width: 200) == 5)
    #expect(viewport.barIndex(atX: 10_000, width: 200) == 99)
  }

  @Test func emptySeriesHasNoVisibleBars() {
    let viewport = CandleViewport(barCount: 0, lower: 0, upper: 0)
    #expect(viewport.visibleIndices == nil)
    #expect(viewport.barIndex(atX: 10, width: 100) == nil)
  }
}

struct PriceScaleTests {
  private let series = CandleSeries(
    bars: [
      .init(open: 100, high: 110, low: 90, close: 105),
      .init(open: 105, high: 200, low: 100, close: 190),
      .init(open: 190, high: 195, low: 180, close: 185),
    ],
    lines: [.init(id: "ma", values: [nil, 80, 400], color: .yellow, width: 1)]
  )

  @Test func envelopeIncludesLines() {
    #expect(series.high == [110, 200, 400])
    #expect(series.low == [90, 80, 180])
  }

  @Test func fitsVisibleBarsOnALogScaleWithPadding() throws {
    let scale = try #require(PriceScale(series: series, indices: 0...1))
    #expect(scale.logHigh == log(200))
    #expect(scale.logLow == log(80))
    // 끝 가격은 위·아래 6% 여백 자리에 온다
    #expect(abs(scale.y(200, height: 100) - 6) < 1e-9)
    #expect(abs(scale.y(80, height: 100) - 94) < 1e-9)
    // log 축: 기하평균이 가운데
    #expect(abs(scale.y((200 * 80).squareRoot(), height: 100) - 50) < 1e-9)
  }

  @Test func paddedDomainMatchesThePixelPadding() throws {
    let scale = try #require(PriceScale(series: series, indices: 0...1))
    let domain = scale.paddedDomain
    #expect(abs(scale.y(domain.upperBound, height: 100)) < 1e-9)
    #expect(abs(scale.y(domain.lowerBound, height: 100) - 100) < 1e-9)
  }

  @Test func noScaleWithoutBars() {
    #expect(PriceScale(series: series, indices: nil) == nil)
  }
}

struct LineSampleTests {
  @Test func drawsEveryBarWhenBarsAreWiderThanAPoint() throws {
    let viewport = CandleViewport(barCount: 756, lower: 100, upper: 200)
    let samples = try #require(LineSample.indices(viewport: viewport, width: 300))
    let indices = Array(samples)
    // 화면 밖은 앞뒤 1봉만
    #expect(indices.first == 99)
    #expect(indices.last == 201)
    #expect(indices.count == 103)
  }

  @Test func skipsByPowersOfTwoOnMultiplesOfTheStep() throws {
    // 756봉 / 300pt = 봉당 0.4pt → 2봉 간격
    let viewport = CandleViewport(barCount: 756, lower: 0, upper: 756)
    let indices = Array(try #require(LineSample.indices(viewport: viewport, width: 300)))
    #expect(indices.first == 0)
    #expect(indices[1] == 2)
    #expect(indices.allSatisfy { $0 % 2 == 0 })
    // 3,024봉 / 300pt = 봉당 0.1pt → 8봉 간격
    let long = CandleViewport(barCount: 3_024, lower: 0, upper: 3_024)
    let longIndices = Array(try #require(LineSample.indices(viewport: long, width: 300)))
    #expect(longIndices[1] == 8)
  }
}
