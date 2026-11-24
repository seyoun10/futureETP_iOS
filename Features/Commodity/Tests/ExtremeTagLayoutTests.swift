import Testing

@testable import Commodity

/// RN `extremeTagLayout.test.ts`와 같은 사례
struct ExtremeTagLayoutTests {
  // 차트 0~500, 글자 높이 14, 간격 3
  static func place(_ kind: ExtremeTagLayout.Kind, _ y: Double, _ lineY: Double?) -> Double {
    ExtremeTagLayout.top(kind, y: y, height: 14, gap: 3, lineY: lineY, top: 0, bottom: 500)
  }

  // 차트 0~500, 꼬리표 너비 100, 화살표 너비 10
  static func placeX(_ kind: ExtremeTagLayout.Kind, _ x: Double, right: Double = 500) -> [Double] {
    let placed = ExtremeTagLayout.left(
      kind, x: x, width: 100, arrowWidth: 10, left: 0, right: right)
    return [placed.left, placed.arrowFirst ? 1 : 0]
  }

  @Test func highAboveLowBelow() {
    #expect(Self.place(.high, 200, nil) == 183)
    #expect(Self.place(.low, 200, nil) == 203)
  }

  @Test func farGuideLineKeepsPlace() {
    #expect(Self.place(.high, 200, 300) == 183)
    #expect(Self.place(.low, 200, 100) == 203)
  }

  @Test func guideLineThroughTextMovesOutside() {
    #expect(Self.place(.high, 200, 190) == 173)
    #expect(Self.place(.low, 200, 210) == 213)
  }

  @Test func outsideBeyondChartMovesTowardBar() {
    #expect(Self.place(.high, 10, 8) == 11)
    #expect(Self.place(.low, 495, 490) == 473)
  }

  @Test func arrowCenterSitsOnBar() {
    #expect(Self.placeX(.high, 250) == [155, 0])
    #expect(Self.placeX(.low, 250) == [245, 1])
  }

  @Test func arrowFlipsAtChartEdges() {
    #expect(Self.placeX(.high, 40) == [35, 1])
    #expect(Self.placeX(.low, 460) == [365, 0])
    #expect(Self.placeX(.high, 3) == [0, 1])
    #expect(Self.placeX(.low, 498) == [400, 0])
  }

  @Test func bothSidesOverflowPicksSmallerAndPushesIn() {
    #expect(Self.placeX(.high, 50, right: 120) == [20, 1])
    #expect(Self.placeX(.high, 80, right: 120) == [0, 0])
  }
}
