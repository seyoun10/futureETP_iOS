import Core
import SwiftUI

/// SwiftUI `Canvas`로 봉·선을 직접 그리는 캔들 차트(C-a 스파이크 후보 A)
struct CanvasCandleChart: View {
  let series: CandleSeries
  let viewport: CandleViewport
  let palette: UpDownPalette
  /// 십자선을 붙인 봉. 세로선은 봉 가운데, 가로선은 종가에 긋는다(D-056)
  var crosshairIndex: Int?
  /// 차트 위에 겹친 정보 줄 높이. 봉·선은 이만큼 아래에서 시작하고, 십자선 세로선은 위까지 긋는다 (D-117)
  var insetTop: Double = 0
  @Environment(\.displayScale) private var displayScale

  var body: some View {
    Canvas { context, size in
      guard let scale = PriceScale(series: series, indices: viewport.visibleIndices),
        let indices = viewport.visibleIndices
      else { return }
      let width = size.width
      let top = insetTop
      let plotHeight = max(size.height - top, 1)
      let y = { (price: Double) in top + scale.y(price, height: plotHeight) }
      let hairline = 1 / displayScale
      let barWidth = width / viewport.span
      // 봉 몸통은 칸의 70%, 1px보다 좁아지면 1px
      let bodyWidth = max(barWidth * 0.7, hairline)

      var upWicks = Path()
      var downWicks = Path()
      var upBodies = Path()
      var downBodies = Path()
      for i in indices {
        let bar = series.bars[i]
        let x = viewport.centerX(ofBar: i, width: width)
        let high = y(bar.high)
        let low = y(bar.low)
        let open = y(bar.open)
        let close = y(bar.close)
        let body = CGRect(
          x: x - bodyWidth / 2, y: min(open, close), width: bodyWidth,
          height: max(abs(open - close), hairline))
        if bar.isUp {
          upWicks.move(to: CGPoint(x: x, y: high))
          upWicks.addLine(to: CGPoint(x: x, y: low))
          upBodies.addRect(body)
        } else {
          downWicks.move(to: CGPoint(x: x, y: high))
          downWicks.addLine(to: CGPoint(x: x, y: low))
          downBodies.addRect(body)
        }
      }
      context.stroke(upWicks, with: .color(palette.up), lineWidth: hairline)
      context.stroke(downWicks, with: .color(palette.down), lineWidth: hairline)
      context.fill(upBodies, with: .color(palette.up))
      context.fill(downBodies, with: .color(palette.down))

      guard let samples = LineSample.indices(viewport: viewport, width: width) else { return }
      for line in series.lines {
        var path = Path()
        var drawing = false
        for i in samples {
          guard let value = line.values[i] else {
            drawing = false
            continue
          }
          let point = CGPoint(
            x: viewport.centerX(ofBar: i, width: width), y: y(value))
          if drawing {
            path.addLine(to: point)
          } else {
            path.move(to: point)
            drawing = true
          }
        }
        context.stroke(
          path, with: .color(line.color),
          style: StrokeStyle(lineWidth: line.width, lineJoin: .round))
      }

      if let index = crosshairIndex, series.bars.indices.contains(index) {
        let x = viewport.centerX(ofBar: index, width: width)
        let closeY = y(series.bars[index].close)
        var cross = Path()
        cross.move(to: CGPoint(x: x, y: 0))
        cross.addLine(to: CGPoint(x: x, y: size.height))
        cross.move(to: CGPoint(x: 0, y: closeY))
        cross.addLine(to: CGPoint(x: width, y: closeY))
        // 점선 간격은 RN `GUIDE_DASH`
        context.stroke(
          cross, with: .color(Theme.ChartColors.crosshairLine),
          style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
      }
    }
    .clipped()
  }
}
