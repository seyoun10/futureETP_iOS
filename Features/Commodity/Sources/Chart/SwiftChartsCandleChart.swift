import Charts
import Core
import SwiftUI

/// Swift Charts로 그리는 캔들 차트(C-a 스파이크 후보 B). 보이는 봉만 마크로 넘기고, x·y 도메인을 보이는 범위로 정한다
struct SwiftChartsCandleChart: View {
  let series: CandleSeries
  let viewport: CandleViewport
  let palette: UpDownPalette

  private struct LinePoint: Identifiable {
    let id: Int
    let value: Double
  }

  var body: some View {
    GeometryReader { geometry in
      if let scale = PriceScale(series: series, indices: viewport.visibleIndices),
        let indices = viewport.visibleIndices
      {
        let barWidth = geometry.size.width / viewport.span
        let samples =
          LineSample.indices(viewport: viewport, width: geometry.size.width)
          .map(Array.init) ?? []
        Chart {
          ForEach(Array(indices), id: \.self) { i in
            let bar = series.bars[i]
            let color = bar.isUp ? palette.up : palette.down
            RuleMark(
              x: .value("bar", Double(i) + 0.5),
              yStart: .value("low", bar.low),
              yEnd: .value("high", bar.high)
            )
            .lineStyle(StrokeStyle(lineWidth: 0.5))
            .foregroundStyle(color)
            RectangleMark(
              x: .value("bar", Double(i) + 0.5),
              yStart: .value("open", bar.open),
              yEnd: .value("close", bar.close),
              width: .fixed(max(barWidth * 0.7, 0.5))
            )
            .foregroundStyle(color)
          }
          ForEach(series.lines) { line in
            ForEach(points(of: line, at: samples)) { point in
              LineMark(
                x: .value("bar", Double(point.id) + 0.5),
                y: .value("price", point.value),
                series: .value("line", line.id)
              )
              .lineStyle(StrokeStyle(lineWidth: line.width, lineJoin: .round))
              .foregroundStyle(line.color)
            }
          }
        }
        .chartXScale(domain: viewport.lower...viewport.upper, range: .plotDimension(padding: 0))
        .chartYScale(domain: scale.paddedDomain, type: .log)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartPlotStyle { $0.clipped() }
      }
    }
  }

  private func points(of line: CandleSeries.Line, at samples: [Int]) -> [LinePoint] {
    samples.compactMap { i in line.values[i].map { LinePoint(id: i, value: $0) } }
  }
}
