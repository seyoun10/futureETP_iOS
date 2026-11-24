import CoreGraphics
import Testing

@testable import Commodity

struct ChartInteractionTests {
  // 봉 100개 중 [0, 20)이 폭 200에 보인다 → 봉 하나가 10pt
  private func make() -> ChartInteraction {
    ChartInteraction(viewport: CandleViewport(barCount: 100, lower: 0, upper: 20))
  }

  @Test func pressSnapsToTheBarUnderTheFinger() {
    var interaction = make()
    interaction.pressed(atX: 57, width: 200)
    #expect(interaction.crosshairIndex == 5)
  }

  @Test func crosshairStaysAfterLiftingAndATapHidesIt() {
    var interaction = make()
    interaction.pressed(atX: 57, width: 200)
    interaction.touchSequenceBegan()
    #expect(interaction.crosshairIndex == 5)
    interaction.tapped()
    #expect(interaction.crosshairIndex == nil)
  }

  @Test func dragPansWithoutACrosshair() {
    var interaction = make()
    interaction.dragged(byX: 50, atX: 100, width: 200)
    #expect(interaction.viewport == CandleViewport(barCount: 100, lower: 0, upper: 20))
    interaction.viewport = CandleViewport(barCount: 100, lower: 50, upper: 70)
    // 오른쪽으로 50pt 끌면 과거 쪽으로 5봉
    interaction.dragged(byX: 50, atX: 100, width: 200)
    #expect(interaction.viewport.lower == 45)
  }

  @Test func dragMovesTheCrosshairInsteadOfPanningWhileItIsShown() {
    var interaction = make()
    interaction.viewport = CandleViewport(barCount: 100, lower: 50, upper: 70)
    interaction.pressed(atX: 5, width: 200)
    interaction.touchSequenceBegan()
    interaction.dragged(byX: 30, atX: 135, width: 200)
    #expect(interaction.viewport.lower == 50)
    #expect(interaction.crosshairIndex == 63)
  }

  @Test func noCrosshairInATouchThatPinched() {
    var interaction = make()
    interaction.pinched(scale: 1.2, startFocalX: 100, focalX: 100, width: 200)
    interaction.pinchEnded()
    // 손가락 하나를 남긴 채 멈춰도 십자선이 뜨지 않는다
    interaction.pressed(atX: 100, width: 200)
    #expect(interaction.crosshairIndex == nil)
    // 손을 모두 떼고 다시 누르면 뜬다
    interaction.touchSequenceBegan()
    interaction.pressed(atX: 100, width: 200)
    #expect(interaction.crosshairIndex != nil)
  }

  @Test func pinchFollowsTheMovingFocalPoint() {
    var interaction = ChartInteraction(
      viewport: CandleViewport(barCount: 100, lower: 40, upper: 60))
    // 가운데(봉 50)에서 시작해 배율 1로 손가락 가운데를 오른쪽으로 50pt(5봉) 옮기면 범위가 과거로 5봉
    interaction.pinched(scale: 1, startFocalX: 100, focalX: 150, width: 200)
    #expect(interaction.viewport.lower == 35)
    // 같은 핀치 안에서는 시작 범위 기준이라 쌓이지 않는다
    interaction.pinched(scale: 1, startFocalX: 100, focalX: 150, width: 200)
    #expect(interaction.viewport.lower == 35)
    // 핀치 중에는 한 손가락 끌기가 범위를 옮기지 않는다
    interaction.dragged(byX: 40, atX: 0, width: 200)
    #expect(interaction.viewport.lower == 35)
  }

  @Test func newDataClearsTheCrosshair() {
    var interaction = make()
    interaction.pressed(atX: 57, width: 200)
    interaction.dataChanged(viewport: CandleViewport(barCount: 200, lower: 100, upper: 120))
    #expect(interaction.crosshairIndex == nil)
    #expect(interaction.viewport.barCount == 200)
  }
}

struct DetailCornerTests {
  private let area = CGRect(x: 0, y: 0, width: 300, height: 200)
  private let box = CGSize(width: 80, height: 60)

  @Test func prefersTheTopCornerAwayFromTheFinger() {
    let corner = DetailCorner.leastCovered(area: area, box: box, crosshairX: 50) { _, _ in [] }
    #expect(corner == DetailCorner(vertical: .top, horizontal: .right))
    let left = DetailCorner.leastCovered(area: area, box: box, crosshairX: 250) { _, _ in [] }
    #expect(left == DetailCorner(vertical: .top, horizontal: .left))
  }

  @Test func picksTheCornerCoveringTheLeastMarks() {
    // 오른쪽 위에 봉이 있으면 오른쪽 아래
    let corner = DetailCorner.leastCovered(area: area, box: box, crosshairX: 50) { x0, _ in
      x0 > 150 ? [10...40] : []
    }
    #expect(corner == DetailCorner(vertical: .bottom, horizontal: .right))
  }

  @Test func avoidsCoveringTheCrosshair() {
    // 반대편이 가린 양이 많아도 십자선을 덮는 귀퉁이보다 낫다
    let corner = DetailCorner.leastCovered(area: area, box: box, crosshairX: 260) { x0, _ in
      x0 < 150 ? [0...200] : []
    }
    #expect(corner.horizontal == .left)
  }

  @Test func rectSitsInTheCorner() {
    let rect = DetailCorner(vertical: .bottom, horizontal: .right).rect(in: area, box: box)
    #expect(rect == CGRect(x: 220, y: 140, width: 80, height: 60))
  }
}
