import Core
import Foundation
import Testing

@testable import Commodity

struct CurveLayoutTests {
  private typealias L = CurveLayout.PctLabel

  @Test func ticksUseNiceStepsLikeRN() {
    // RN `niceTicks`와 같은 값(d3 ticks)
    #expect(AxisTicks.linear(from: 2.7, to: 3.5, count: 5) == [2.8, 3, 3.2, 3.4])
    #expect(AxisTicks.linear(from: 61.3, to: 74.9, count: 6) == [62, 64, 66, 68, 70, 72, 74])
    #expect(AxisTicks.linear(from: 2400, to: 2600, count: 5) == [2400, 2450, 2500, 2550, 2600])
    #expect(AxisTicks.decimals([1, 1.1, 1.2], max: 3) == 1)
    #expect(AxisTicks.decimals([3.65, 3.66, 3.67], max: 4) == 2)
  }

  @Test func labelStrideSkipsWhenSlotIsNarrow() {
    #expect(CurveLayout.labelStride(slotWidth: 40, labelWidth: 30) == 1)
    #expect(CurveLayout.labelStride(slotWidth: 14, labelWidth: 30) == 3)
  }

  @Test func nearestSlotClampsToEnds() {
    #expect(CurveLayout.nearestSlot(x: 45, left: 40, slotWidth: 20, count: 3) == 0)
    #expect(CurveLayout.nearestSlot(x: 99, left: 40, slotWidth: 20, count: 3) == 2)
    #expect(CurveLayout.nearestSlot(x: 39, left: 40, slotWidth: 20, count: 3) == 0)
    #expect(CurveLayout.nearestSlot(x: 100, left: 40, slotWidth: 20, count: 3) == 2)
    #expect(CurveLayout.nearestSlot(x: 50, left: 40, slotWidth: 20, count: 0) == nil)
  }

  private func ys(_ labels: [L], minY: Double = 0, maxY: Double = 200) -> [Double] {
    CurveLayout.placePctLabels(labels, height: 10, gap: 4, minY: minY, maxY: maxY).map(\.y)
  }

  @Test func labelsSitAboveDotsWhenApart() {
    #expect(
      ys([
        L(x: 0, anchor: 15, width: 30, top: 100, bottom: 110),
        L(x: 40, anchor: 55, width: 30, top: 100, bottom: 110),
      ]) == [96, 96])
  }

  @Test func overlappingLabelsArePushedOutwardOnTheSameSide() {
    #expect(
      ys([
        L(x: 0, anchor: 15, width: 30, top: 100, bottom: 110),
        L(x: 20, anchor: 35, width: 30, top: 100, bottom: 110),
        L(x: 10, anchor: 25, width: 30, top: 100, bottom: 110),
      ]) == [96, 82, 68])
  }

  @Test func fallingLabelsGoBelowAndPushDown() {
    #expect(
      ys([
        L(x: 0, anchor: 15, width: 30, top: 100, bottom: 110, below: true),
        L(x: 40, anchor: 55, width: 30, top: 100, bottom: 110),
        L(x: 20, anchor: 35, width: 30, top: 100, bottom: 110, below: true),
      ]) == [124, 96, 138])
  }

  @Test func aboveAndBelowLabelsDoNotPushEachOther() {
    #expect(
      ys([
        L(x: 0, anchor: 15, width: 30, top: 100, bottom: 110),
        L(x: 10, anchor: 25, width: 30, top: 100, bottom: 110, below: true),
      ]) == [96, 124])
  }

  @Test func pushedLabelsStickToTheEdge() {
    #expect(
      ys(
        [
          L(x: 0, anchor: 15, width: 30, top: 100, bottom: 110),
          L(x: 10, anchor: 25, width: 30, top: 100, bottom: 110),
        ], minY: 80, maxY: 120) == [96, 90])
  }

  @Test func labelOnALineMovesSidewaysTheLeast() {
    // 점(15, 100)에서 오른쪽 위로 오르는 선: 위 라벨은 왼쪽으로 비킨다
    let segments = [CurveLayout.Segment(x0: 15, y0: 100, x1: 45, y1: 70)]
    let p = CurveLayout.placePctLabels(
      [L(x: 0, anchor: 15, width: 30, top: 97, bottom: 103)], height: 10, gap: 4, minY: 0,
      maxY: 200, minX: -100, segments: segments)[0]
    #expect(p.y == 93)
    #expect(p.x < 0)
    #expect(p.x >= -15)
  }

  @Test func labelStaysWhenNoFreeSpot() {
    // 점 양쪽으로 가파르게 오르는 골짜기
    let segments = [
      CurveLayout.Segment(x0: -15, y0: 0, x1: 15, y1: 100),
      CurveLayout.Segment(x0: 15, y0: 100, x1: 45, y1: 0),
    ]
    #expect(
      CurveLayout.placePctLabels(
        [L(x: 0, anchor: 15, width: 30, top: 97, bottom: 103)], height: 10, gap: 4, minY: 0,
        maxY: 200, minX: -100, segments: segments) == [.init(x: 0, y: 93)])
  }

  @Test func labelDoesNotMovePastTheLeftEdge() {
    let segments = [CurveLayout.Segment(x0: 15, y0: 100, x1: 45, y1: 70)]
    #expect(
      CurveLayout.placePctLabels(
        [L(x: 0, anchor: 15, width: 30, top: 97, bottom: 103)], height: 10, gap: 4, minY: 0,
        maxY: 200, minX: 0, segments: segments) == [.init(x: 0, y: 93)])
  }

  @Test func segmentHitsBoxUsesVerticalRangeInsideBox() {
    let s = CurveLayout.Segment(x0: 0, y0: 0, x1: 10, y1: 10)
    #expect(CurveLayout.segmentHitsBox(s, left: 4, right: 6, top: 3, bottom: 7))
    #expect(!CurveLayout.segmentHitsBox(s, left: 4, right: 6, top: 7, bottom: 9))
    #expect(!CurveLayout.segmentHitsBox(s, left: 11, right: 20, top: 0, bottom: 10))
  }
}

struct CurveFormatTests {
  private let current = LocalDate(year: 2026, month: 11, day: 23)!

  @Test func datesShowYearOnlyWhenDifferentFromD() {
    let sameYear = LocalDate(year: 2026, month: 10, day: 16)!
    let pastYear = LocalDate(year: 2020, month: 4, day: 20)!
    #expect(CurveFormat.fullDate(sameYear) == "2026/10/16")
    #expect(CurveFormat.legendDate(sameYear, current: current) == "10/16")
    #expect(CurveFormat.legendDate(pastYear, current: current) == "2020/04/20")
  }

  @Test func weekdayFollowsLanguage() {
    let friday = LocalDate(year: 2026, month: 10, day: 16)!
    #expect(CurveFormat.weekday(friday, locale: Locale(identifier: "ko")) == "금")
    #expect(CurveFormat.weekday(friday, locale: Locale(identifier: "en")) == "Fri")
  }

  @Test func pctHasOneDecimalAndSign() {
    #expect(CurveFormat.pct(1.234) == "+1.2%")
    #expect(CurveFormat.pct(-0.04) == "0.0%")
  }

  @Test func rollLineUsesCompareCurveOrUnavailable() throws {
    let t: DisparityInfo.Translate = { key, values in
      "\(key)" + values.sorted { $0.key < $1.key }.map { "[\($0.value)]" }.joined()
    }
    func curve(_ current: Any) throws -> Curve {
      let freshness: [String: Any] = [
        "asOf": "2026-11-24T04:05:37.044Z", "tradeDate": "2026-11-23", "delayed": false,
        "marketState": "CLOSED", "nextUpdateAt": NSNull(),
      ]
      let object: [String: Any] = [
        "freshness": freshness, "priceDecimals": 2, "baseDate": "2026-11-20", "baseOffset": 1,
        "prevBaseDate": "2026-11-19", "nextBaseDate": NSNull(), "minBaseDate": "2010-06-07",
        "maxBaseDate": "2026-11-20", "compareDate": "2026-11-23", "points": [],
        "current": current, "base": NSNull(),
      ]
      return try JSONDecoder.api().decode(
        Curve.self, from: JSONSerialization.data(withJSONObject: object))
    }
    let stats: [String: Any] = [
      "m1ContractMonth": "2027-01", "m2ContractMonth": "2027-02", "state": "BACKWARDATION",
      "spreadPct": -1.5, "rollYieldPct": 12.34,
    ]
    #expect(
      CurveFormat.rollLine(try curve(stats), t: t) == "curve.rollYield[curve.perYear[+12.3%]]")
    #expect(
      CurveFormat.rollLine(try curve(NSNull()), t: t) == "curve.rollYield[curve.unavailable]")
  }
}
