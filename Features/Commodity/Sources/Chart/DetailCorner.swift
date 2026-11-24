import CoreGraphics

/// 십자선 상세 박스를 둘 차트 귀퉁이(screens.md C-a 길게 누르기, RN `charts/detailCorner.ts`)
struct DetailCorner: Equatable {
  enum Vertical { case top, bottom }
  enum Horizontal { case left, right }

  let vertical: Vertical
  let horizontal: Horizontal

  /// 박스 영역과 겹치는 표시(봉·선)의 세로 길이 합이 가장 작은 귀퉁이. 십자선 x를 덮는 귀퉁이는 다른 곳이 없을 때만 고른다.
  /// 같으면 손가락 반대편, 위쪽 순이다. `marksIn(x0, x1)`은 화면 x 구간에 그려진 표시의 세로 구간들이다
  static func leastCovered(
    area: CGRect, box: CGSize, crosshairX: Double,
    marksIn: (Double, Double) -> [ClosedRange<Double>]
  ) -> Self {
    let opposite: Horizontal = crosshairX < area.midX ? .right : .left
    let near: Horizontal = opposite == .right ? .left : .right
    let corners = [
      Self(vertical: .top, horizontal: opposite),
      Self(vertical: .bottom, horizontal: opposite),
      Self(vertical: .top, horizontal: near),
      Self(vertical: .bottom, horizontal: near),
    ]
    var best = corners[0]
    var bestScore = Double.infinity
    for corner in corners {
      let r = corner.rect(in: area, box: box)
      var score = crosshairX >= r.minX && crosshairX <= r.maxX ? 1e9 : 0
      for span in marksIn(r.minX, r.maxX) {
        score += max(0, min(span.upperBound, r.maxY) - max(span.lowerBound, r.minY))
      }
      if score < bestScore {
        best = corner
        bestScore = score
      }
    }
    return best
  }

  func rect(in area: CGRect, box: CGSize) -> CGRect {
    CGRect(
      x: horizontal == .left ? area.minX : area.maxX - box.width,
      y: vertical == .top ? area.minY : area.maxY - box.height,
      width: box.width, height: box.height)
  }
}

extension CandleSeries {
  /// 화면 x 구간 `[x0, x1]`에 그려진 봉(고가~저가)과 선(굵기만큼)의 세로 구간. 상세 박스 귀퉁이 고르기용.
  /// `size`는 봉을 그리는 영역이고, 봉·선은 그 위쪽 `insetTop`을 비켜 그린다(`CanvasCandleChart`와 같음)
  func markSpans(
    x0: Double, x1: Double, viewport: CandleViewport, scale: PriceScale, size: CGSize,
    insetTop: Double = 0
  ) -> [ClosedRange<Double>] {
    guard let first = viewport.barIndex(atX: x0, width: size.width),
      let last = viewport.barIndex(atX: x1, width: size.width)
    else { return [] }
    let height = max(size.height - insetTop, 1)
    let y = { (price: Double) in insetTop + scale.y(price, height: height) }
    var spans: [ClosedRange<Double>] = []
    for i in first...last {
      if bars.indices.contains(i) {
        spans.append(y(bars[i].high)...y(bars[i].low))
      }
      for line in lines {
        guard let value = line.values[i], value > 0 || !isLog else { continue }
        let lineY = y(value)
        spans.append((lineY - line.width / 2)...(lineY + line.width / 2))
      }
    }
    return spans
  }
}
