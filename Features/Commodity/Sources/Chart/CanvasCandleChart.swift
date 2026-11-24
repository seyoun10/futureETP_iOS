import Core
import SwiftUI

/// C-a 축 입력(D-056). 우측 y축(눈금·특수 라벨·가격 점선)과 아래 x축(월 눈금), 십자선 날짜·가격 라벨을 그린다
struct CandleAxes {
  /// 봉 순번별 거래일
  let dates: [LocalDate]
  let priceDecimals: Int
  /// y축 특수 라벨. 겹치면 모두 남긴 채 위·아래로 민다
  let labels: [ChartPriceLabel]
  /// 수평 점선(뒤에 둔 것이 위에 그려진다)
  let guides: [(price: Double, color: Color)]
  /// 우측 y축 라벨 자리
  let yLabelWidth: Double
  /// 가장 넓은 월 라벨 폭
  let monthLabelWidth: Double
  let locale: Locale
  /// 롤 음영·대표월물 전환일 점선(봉 뒤)
  var roll = ChartRollMarks()
  /// 보이는 봉 중 최고가·최저가 봉의 꼬리표. 없으면 그리지 않는다
  var extremes: ExtremeTags?

  struct ExtremeTags {
    /// 꼬리표 %의 기준(마지막 봉 종가)
    let currentPrice: Double
    /// 꼬리표가 비켜 갈 회색 점선 가격
    let guidePrice: Double
  }

  /// 우측 y축 자리: 가장 큰 가격 라벨 + 여백 (RN `CandleChart` `yLabelWidth`)
  static func yLabelWidth(maxPrice: Double, decimals: Int) -> Double {
    ChartText.width(NumberFormat.price(max(maxPrice, 1), decimals: decimals))
      + Double(ChartLayout.yLabelPad)
  }
}

/// SwiftUI `Canvas`로 봉·선·축을 직접 그리는 캔들 차트(IOS-008)
struct CanvasCandleChart: View {
  let series: CandleSeries
  let viewport: CandleViewport
  let palette: UpDownPalette
  /// 십자선을 붙인 봉. 세로선은 봉 가운데, 가로선은 종가에 긋는다(D-056)
  var crosshairIndex: Int?
  /// 차트 위에 겹친 정보 줄 높이. 봉·선은 이만큼 아래에서 시작하고, 십자선 세로선은 위까지 긋는다 (D-117)
  var insetTop: Double = 0
  /// 없으면 축 없이 전체 크기에 봉·선만 그린다(스파이크)
  var axes: CandleAxes?
  @Environment(\.displayScale) private var displayScale

  var body: some View {
    Canvas { context, size in
      guard let scale = PriceScale(series: series, indices: viewport.visibleIndices),
        let indices = viewport.visibleIndices
      else { return }
      let plot = CGRect(
        x: 0, y: 0, width: max(size.width - (axes?.yLabelWidth ?? 0), 1),
        height: max(size.height - (axes == nil ? 0 : ChartLayout.xLabelHeight), 1))
      let frame = Frame(
        plot: plot, insetTop: insetTop, scale: scale, viewport: viewport,
        hairline: 1 / displayScale)
      let crosshair = crosshairIndex.flatMap { index in
        series.bars.indices.contains(index)
          ? (index: index, x: frame.x(index), y: frame.y(series.bars[index].close)) : nil
      }

      var axisContext = context
      if let axes {
        drawGrid(axes, frame: frame, in: &axisContext)
      }
      var plotContext = context
      plotContext.clip(to: Path(plot))
      if let axes {
        drawRoll(axes.roll, frame: frame, in: &plotContext)
      }
      drawBars(indices, frame: frame, in: &plotContext)
      drawLines(frame: frame, in: &plotContext)
      if let axes {
        drawGuides(axes, frame: frame, in: &plotContext)
        if let extremes = axes.extremes {
          drawExtremeTags(extremes, axes: axes, frame: frame, in: &plotContext)
        }
      }
      if let crosshair {
        var cross = Path()
        cross.move(to: CGPoint(x: crosshair.x, y: 0))
        cross.addLine(to: CGPoint(x: crosshair.x, y: plot.maxY))
        cross.move(to: CGPoint(x: 0, y: crosshair.y))
        cross.addLine(to: CGPoint(x: plot.maxX, y: crosshair.y))
        plotContext.stroke(
          cross, with: .color(Theme.ChartColors.crosshairLine),
          style: StrokeStyle(lineWidth: 1, dash: ChartLayout.guideDash))
      }
      if let axes {
        drawLabels(axes, frame: frame, size: size, crosshair: crosshair, in: &axisContext)
      }
    }
    .clipped()
  }

  /// 화면 좌표 변환
  private struct Frame {
    let plot: CGRect
    let insetTop: Double
    let scale: PriceScale
    let viewport: CandleViewport
    let hairline: Double

    private var plotHeight: Double { max(plot.height - insetTop, 1) }
    func x(_ index: Int) -> Double { viewport.centerX(ofBar: index, width: plot.width) }
    func y(_ price: Double) -> Double { insetTop + scale.y(price, height: plotHeight) }
    func price(atY y: Double) -> Double { scale.price(atY: y - insetTop, height: plotHeight) }
  }

  private func drawBars(
    _ indices: ClosedRange<Int>, frame: Frame, in context: inout GraphicsContext
  ) {
    let barWidth = frame.plot.width / viewport.span
    // 봉 몸통은 칸의 70%, 1px보다 좁아지면 1px
    let bodyWidth = max(barWidth * 0.7, frame.hairline)
    var upWicks = Path()
    var downWicks = Path()
    var upBodies = Path()
    var downBodies = Path()
    for i in indices {
      let bar = series.bars[i]
      let x = frame.x(i)
      let high = frame.y(bar.high)
      let low = frame.y(bar.low)
      let open = frame.y(bar.open)
      let close = frame.y(bar.close)
      let body = CGRect(
        x: x - bodyWidth / 2, y: min(open, close), width: bodyWidth,
        height: max(abs(open - close), frame.hairline))
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
    context.stroke(upWicks, with: .color(palette.up), lineWidth: frame.hairline)
    context.stroke(downWicks, with: .color(palette.down), lineWidth: frame.hairline)
    context.fill(upBodies, with: .color(palette.up))
    context.fill(downBodies, with: .color(palette.down))
  }

  private func drawLines(frame: Frame, in context: inout GraphicsContext) {
    guard let samples = LineSample.indices(viewport: viewport, width: frame.plot.width) else {
      return
    }
    for line in series.lines {
      var path = Path()
      var drawing = false
      for i in samples {
        guard let value = line.values[i] else {
          drawing = false
          continue
        }
        let point = CGPoint(x: frame.x(i), y: frame.y(value))
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
  }

  // MARK: - 축

  /// y 눈금 가격(그림 영역 위 끝~아래 끝)
  private func priceTicks(frame: Frame) -> [Double] {
    AxisTicks.log(from: frame.price(atY: frame.plot.maxY), to: frame.price(atY: frame.plot.minY))
  }

  private func monthTicks(_ axes: CandleAxes, frame: Frame) -> [MonthTicks.Tick] {
    guard let range = viewport.visibleIndices else { return [] }
    let barWidth = frame.plot.width / viewport.span
    return MonthTicks.ticks(
      dates: axes.dates, range: range,
      minGap: (axes.monthLabelWidth + MonthTicks.gap) / barWidth)
  }

  /// 격자선: y 눈금 가로선과 월 눈금 세로선(봉 뒤)
  private func drawGrid(_ axes: CandleAxes, frame: Frame, in context: inout GraphicsContext) {
    var grid = Path()
    for price in priceTicks(frame: frame) {
      let y = frame.y(price)
      guard y >= frame.plot.minY, y <= frame.plot.maxY else { continue }
      grid.move(to: CGPoint(x: 0, y: y))
      grid.addLine(to: CGPoint(x: frame.plot.maxX, y: y))
    }
    for tick in monthTicks(axes, frame: frame) {
      let x = frame.x(tick.index)
      guard x >= 0, x <= frame.plot.maxX else { continue }
      grid.move(to: CGPoint(x: x, y: 0))
      grid.addLine(to: CGPoint(x: x, y: frame.plot.maxY))
    }
    context.stroke(grid, with: .color(Theme.ChartColors.grid), lineWidth: frame.hairline)
  }

  /// 가격 점선(현재가·마지막 봉 종가)
  private func drawGuides(_ axes: CandleAxes, frame: Frame, in context: inout GraphicsContext) {
    for guide in axes.guides {
      let y = frame.y(guide.price)
      var path = Path()
      path.move(to: CGPoint(x: 0, y: y))
      path.addLine(to: CGPoint(x: frame.plot.maxX, y: y))
      context.stroke(
        path, with: .color(guide.color),
        style: StrokeStyle(lineWidth: 1, dash: ChartLayout.guideDash))
    }
  }

  /// 롤 기간 음영과 대표월물 전환일 세로 점선 (RN `RollLayer`)
  private func drawRoll(_ roll: ChartRollMarks, frame: Frame, in context: inout GraphicsContext) {
    let plot = frame.plot
    let half = plot.width / viewport.span / 2
    var shade = Path()
    for segment in roll.shading {
      let left = frame.x(segment.lowerBound) - half
      let right = frame.x(segment.upperBound) + half
      guard right >= plot.minX, left <= plot.maxX else { continue }
      shade.addRect(CGRect(x: left, y: plot.minY, width: right - left, height: plot.height))
    }
    context.fill(shade, with: .color(Theme.ChartColors.rollShade))
    var switches = Path()
    for index in roll.switches {
      let x = frame.x(index)
      guard x >= plot.minX, x <= plot.maxX else { continue }
      switches.move(to: CGPoint(x: x, y: plot.minY))
      switches.addLine(to: CGPoint(x: x, y: plot.maxY))
    }
    context.stroke(
      switches, with: .color(Theme.ChartColors.rollSwitch),
      style: StrokeStyle(lineWidth: 1, dash: ChartLayout.guideDash))
  }

  /// 보이는 봉(가운데가 화면 안) 중 최고가·최저가 봉의 꼬리표 `고가 가격(현재가 대비 %, 날짜)` (RN `ExtremeTagsLayer`)
  private func drawExtremeTags(
    _ extremes: CandleAxes.ExtremeTags, axes: CandleAxes, frame: Frame,
    in context: inout GraphicsContext
  ) {
    guard let indices = viewport.centerIndices, extremes.currentPrice > 0 else { return }
    var high = indices.lowerBound
    var low = indices.lowerBound
    for i in indices {
      if series.bars[i].high > series.bars[high].high { high = i }
      if series.bars[i].low < series.bars[low].low { low = i }
    }
    let plot = frame.plot
    let lineY = frame.y(extremes.guidePrice)
    let height = ChartText.lineHeight
    for (index, kind) in [(high, ExtremeTagLayout.Kind.high), (low, .low)] {
      let bar = series.bars[index]
      let price = kind == .high ? bar.high : bar.low
      let date = axes.dates.indices.contains(index) ? axes.dates[index] : nil
      let text = L10n.string(
        kind == .high ? "chart.highTag" : "chart.lowTag",
        [
          "price": NumberFormat.price(price, decimals: axes.priceDecimals),
          "pct": NumberFormat.changePct((price / extremes.currentPrice - 1) * 100),
          "date": date.map { String(format: "%02d/%02d", $0.month, $0.day) } ?? "",
        ], locale: axes.locale)
      // 화살표 위치와 상관없이 글자 수가 같아 너비도 같다
      let width = ChartText.width(kind.arrow + text)
      let placed = ExtremeTagLayout.left(
        kind, x: frame.x(index), width: width, arrowWidth: ChartText.width(kind.arrow),
        left: plot.minX, right: plot.maxX)
      let top = ExtremeTagLayout.top(
        kind, y: frame.y(price), height: height, lineY: lineY, top: plot.minY, bottom: plot.maxY)
      context.draw(
        Text(verbatim: placed.arrowFirst ? kind.arrow + text : text + kind.arrow)
          .font(ChartText.font).foregroundStyle(Theme.ChartColors.extremeTag),
        at: CGPoint(x: placed.left, y: top), anchor: .topLeading)
    }
  }

  /// y축 눈금·특수 라벨, x축 월 라벨, 십자선 가격·날짜 라벨. 특수 라벨과 겹치는 눈금 글자와
  /// 십자선 라벨과 겹치는 글자는 숨긴다 (RN `YAxisLayer`·`XAxisLayer`·`CrosshairLayer`)
  private func drawLabels(
    _ axes: CandleAxes, frame: Frame, size: CGSize,
    crosshair: (index: Int, x: Double, y: Double)?, in context: inout GraphicsContext
  ) {
    let height = ChartText.labelHeight
    let plot = frame.plot
    let labelX = plot.maxX + 4
    let hiddenByCrosshair = { (y: Double) in crosshair.map { abs(y - $0.y) < height } ?? false }
    let text = { (string: String, color: Color) in
      Text(verbatim: string).font(ChartText.font).foregroundStyle(color)
    }

    let special = PriceLabelLayout.stack(
      axes.labels.map { ($0, frame.y($0.price)) }, height: height, top: plot.minY,
      bottom: plot.maxY)
    let specialYs = special.map(\.y)
    let ticks = priceTicks(frame: frame)
    let decimals = AxisTicks.decimals(ticks, max: axes.priceDecimals)
    for price in ticks {
      let y = frame.y(price)
      guard y >= plot.minY, y <= plot.maxY,
        // 끝에 붙은 눈금 글자는 잘리므로 격자선만 그린다
        y == PriceLabelLayout.clampY(y, height: height, top: plot.minY, bottom: plot.maxY),
        !PriceLabelLayout.overlapsAny(y, specialYs, height: height), !hiddenByCrosshair(y)
      else { continue }
      context.draw(
        text(NumberFormat.price(price, decimals: decimals), Theme.ChartColors.tick),
        at: CGPoint(x: labelX, y: y), anchor: .leading)
    }
    for label in special where !hiddenByCrosshair(label.y) {
      context.draw(
        text(
          NumberFormat.price(label.label.price, decimals: axes.priceDecimals), label.label.color),
        at: CGPoint(x: labelX, y: label.y), anchor: .leading)
    }

    let labelTop = plot.maxY + 4
    for tick in monthTicks(axes, frame: frame) {
      let x = frame.x(tick.index)
      guard x >= 0, x <= plot.maxX else { continue }
      let label = MonthTicks.label(year: tick.year, month: tick.month, locale: axes.locale)
      let width = ChartText.width(label)
      let left = min(max(x - width / 2, 0), plot.maxX - width)
      if let crosshair,
        abs(left + width / 2 - crosshair.x) < width / 2 + ChartText.dateBoxWidth / 2 + 2
      {
        continue
      }
      context.draw(
        text(label, Theme.ChartColors.tick), at: CGPoint(x: left, y: labelTop), anchor: .topLeading)
    }

    guard let crosshair else { return }
    let pad = Double(ChartLayout.labelPad)
    // 점선과 라벨 상자는 흰색이라 기본 눈금(회색)과 구분된다(D-056)
    let box = Theme.ChartColors.crosshair
    let ink = Theme.ChartColors.crosshairText
    let priceBox = CGRect(
      x: plot.maxX + 1, y: crosshair.y - height / 2, width: size.width - plot.maxX - 1,
      height: height)
    context.fill(Path(priceBox), with: .color(box))
    context.draw(
      text(
        NumberFormat.price(series.bars[crosshair.index].close, decimals: axes.priceDecimals), ink),
      at: CGPoint(x: priceBox.minX + pad, y: crosshair.y), anchor: .leading)
    if axes.dates.indices.contains(crosshair.index) {
      let dateWidth = ChartText.dateBoxWidth
      let dateBox = CGRect(
        x: min(max(crosshair.x - dateWidth / 2, 0), plot.maxX - dateWidth), y: plot.maxY + 2,
        width: dateWidth, height: height)
      context.fill(Path(dateBox), with: .color(box))
      context.draw(
        text(axes.dates[crosshair.index].description, ink),
        at: CGPoint(x: dateBox.midX, y: dateBox.midY), anchor: .center)
    }
  }
}
