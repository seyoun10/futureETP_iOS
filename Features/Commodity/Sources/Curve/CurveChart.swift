import Core
import SwiftUI

/// C-b 월물커브 선차트(screens.md C-b, RN `charts/CurveChart.tsx`). 기준일은 실선 + 빈 점, 비교일은 점선 + 찬 점,
/// 변화율은 등락 색으로 오르면 점 위·내리면 점 아래(반올림해 0이면 위).
/// 확대·이동이 없어 `Canvas`에 직접 그린다. 십자선은 C-a와 같다(D-056): 길게 누르면 나타나 끄는 대로 월물에 붙고(햅틱),
/// 손을 떼도 남아 있는 동안은 길게 누르지 않고 끌어도 따라오며, 한 번 더 누르면 사라진다
struct CurveChart<Top: View, Floating: View>: View {
  let points: [CurveChartLayout.Point]
  let priceDecimals: Int
  let palette: UpDownPalette
  /// 십자선이 붙은 월물의 상세 박스 줄. 위치는 점·선을 가장 적게 가리는 귀퉁이로 정한다
  let detailRows: (Int) -> [DetailRow]
  /// 있으면 `floating` 아래(x축 라벨 위)에 되돌리기 버튼을 띄운다. 누르면 십자선·상세 박스도 지운다
  var onReset: (() -> Void)?
  var resetLabel: LocalizedStringKey = "chart.resetView"
  /// 차트 안 위쪽에 겹치는 정보 줄. 선·점은 줄을 비켜 그린다
  @ViewBuilder let overlayTop: () -> Top
  /// x축 라벨 위에 띄우는 안내
  @ViewBuilder let floating: () -> Floating

  @Environment(\.locale) private var locale
  @Environment(\.displayScale) private var displayScale
  /// 십자선이 붙은 월물. nil이면 십자선이 없다
  @State private var selected: Int?
  @State private var insetTop: CGFloat = 0
  @State private var boxSize: CGSize?

  var body: some View {
    GeometryReader { geometry in
      let layout = CurveChartLayout(
        points: points, priceDecimals: priceDecimals, size: geometry.size,
        insetTop: insetTop)
      let pctLabels = layout?.pctLabels() ?? []
      ZStack(alignment: .bottom) {
        if let layout {
          canvas(layout, pctLabels: pctLabels, size: geometry.size)
          ChartGestureSurface { handle($0, layout: layout) }
            .accessibilityIdentifier("curveChart")
        }
        overlayTop()
          .padding(.vertical, Theme.Spacing.xs)
          .frame(maxWidth: .infinity)
          .background(Theme.Colors.overlay)
          .onGeometryChange(for: CGFloat.self, of: \.size.height) { insetTop = $0 }
          .frame(maxHeight: .infinity, alignment: .top)
        VStack(spacing: Theme.Spacing.sm) {
          floating()
          if let onReset {
            ChartResetButton(label: resetLabel) {
              selected = nil
              onReset()
            }
          }
        }
        .padding(.bottom, ChartLayout.xLabelHeight + Theme.Spacing.xs)
        if let layout, let selected, points.indices.contains(selected) {
          detail(selected, layout: layout, pctLabels: pctLabels)
        }
      }
    }
    .sensoryFeedback(.selection, trigger: selected) { _, new in new != nil }
  }

  private func handle(_ event: ChartGestureSurface.Event, layout: CurveChartLayout) {
    switch event {
    case .pressed(let x): snap(x, layout: layout)
    // 십자선이 있으면 길게 누르지 않고 끌어도 바로 따라온다
    case .dragged(_, let x) where selected != nil: snap(x, layout: layout)
    case .tapped: selected = nil
    default: break
    }
  }

  /// 손가락 x에 가장 가까운 월물에 십자선을 붙인다
  private func snap(_ x: Double, layout: CurveChartLayout) {
    guard let index = layout.nearestIndex(x: x), index != selected else { return }
    selected = index
  }

  /// 상세 박스: 정보 줄 아래 그림 영역의 네 귀퉁이 중 점·선·변화율을 가장 적게 가리는 곳(C-a와 같다).
  /// 처음 잰 크기로 귀퉁이를 고르고, 재기 전에는 감춘다. 터치는 차트로 흘려보낸다
  private func detail(
    _ index: Int, layout: CurveChartLayout, pctLabels: [CurveChartLayout.PctLabel]
  ) -> some View {
    let box = DetailBox(rows: detailRows(index))
      .onGeometryChange(for: CGSize.self, of: \.size) { boxSize = $0 }
    let area = CGRect(
      x: layout.left, y: layout.dataTop, width: layout.right - layout.left,
      height: max(layout.plotBottom - layout.dataTop, 0)
    ).insetBy(dx: Theme.Spacing.sm, dy: Theme.Spacing.sm)
    return Group {
      if let boxSize {
        let rect = DetailCorner.leastCovered(area: area, box: boxSize, crosshairX: layout.x(index))
        {
          layout.markSpans(x0: $0, x1: $1, pctLabels: pctLabels)
        }.rect(in: area, box: boxSize)
        box.offset(x: rect.minX, y: rect.minY)
      } else {
        box.hidden()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .allowsHitTesting(false)
    .accessibilityIdentifier("curveDetail")
  }

  private func canvas(
    _ layout: CurveChartLayout, pctLabels: [CurveChartLayout.PctLabel], size: CGSize
  ) -> some View {
    let monthLabels = points.map {
      MonthTicks.label(year: $0.contractMonth.year, month: $0.contractMonth.month, locale: locale)
    }
    // x축 라벨은 겹치지 않게 n개마다 하나씩 쓰고, 첫 1월(연도)이 빠지지 않게 그 칸에 맞춘다
    let stride = CurveLayout.labelStride(
      slotWidth: layout.slot,
      labelWidth: ChartText.widestMonthLabel(locale: locale) + CurveChartLayout.labelGap)
    let firstJanuary = points.firstIndex { $0.contractMonth.month == 1 }
    let anchor = (firstJanuary ?? 0) % stride
    let hairline = 1 / displayScale
    let selected = selected
    let palette = palette
    let priceDecimals = priceDecimals
    return Canvas { context, _ in
      let text = { (string: String, color: Color) in
        Text(verbatim: string).font(ChartText.font).foregroundStyle(color)
      }
      let top = CurveChartLayout.top
      // 격자·y축 눈금
      var grid = Path()
      for (i, tick) in layout.ticks.enumerated() {
        let y = layout.y(tick)
        guard y >= top, y <= layout.plotBottom else { continue }
        grid.move(to: CGPoint(x: layout.left, y: y))
        grid.addLine(to: CGPoint(x: layout.right, y: y))
        context.draw(
          text(layout.tickLabels[i], Theme.ChartColors.tick),
          at: CGPoint(x: layout.right + CurveChartLayout.yLabelGap, y: y), anchor: .leading)
      }
      context.stroke(grid, with: .color(Theme.ChartColors.grid), lineWidth: hairline)

      // 기준일 실선·비교일 점선
      for (key, color, dash) in [
        (\CurveChartLayout.Point.base, Theme.ChartColors.curveBase, [Double]()),
        (\.current, Theme.ChartColors.curveCurrent, CurveChartLayout.curveDash),
      ] {
        var path = Path()
        var drawing = false
        for (i, p) in points.enumerated() {
          guard let v = p[keyPath: key] else {
            drawing = false
            continue
          }
          let point = CGPoint(x: layout.x(i), y: layout.y(v))
          if drawing { path.addLine(to: point) } else { path.move(to: point) }
          drawing = true
        }
        context.stroke(
          path, with: .color(color),
          style: StrokeStyle(
            lineWidth: CurveChartLayout.seriesStroke, lineJoin: .round,
            dash: dash.map { CGFloat($0) }))
      }

      // 점(기준일 빈 점·비교일 찬 점)과 x축 월 라벨
      let dot = CurveChartLayout.dot
      for (i, p) in points.enumerated() {
        let x = layout.x(i)
        if let base = p.base {
          context.stroke(
            Path(
              ellipseIn: CGRect(
                x: x - dot, y: layout.y(base) - dot, width: 2 * dot, height: 2 * dot)),
            with: .color(Theme.ChartColors.curveBase), lineWidth: CurveChartLayout.seriesStroke)
        }
        if let current = p.current {
          context.fill(
            Path(
              ellipseIn: CGRect(
                x: x - dot, y: layout.y(current) - dot, width: 2 * dot, height: 2 * dot)),
            with: .color(Theme.ChartColors.curveCurrent))
        }
        if i % stride == anchor {
          let label = monthLabels[i]
          context.draw(
            text(label, Theme.ChartColors.tick),
            at: CGPoint(
              x: layout.textX(i, width: ChartText.width(label)), y: layout.plotBottom + 4),
            anchor: .topLeading)
        }
      }

      // 변화율
      for label in pctLabels {
        context.draw(
          text(label.text, palette.color(for: label.pct, decimals: CurveFormat.pctDecimals)),
          at: CGPoint(x: label.x, y: label.y - Double(ChartLayout.fontSize) / 2),
          anchor: .leading)
      }

      // 십자선: 점선 두 줄과 흰 가격·월물 라벨 상자(D-056)
      guard let selected, let value = layout.crosshairValue(selected) else { return }
      let x = layout.x(selected)
      let y = layout.y(value)
      var cross = Path()
      cross.move(to: CGPoint(x: x, y: top))
      cross.addLine(to: CGPoint(x: x, y: layout.plotBottom))
      cross.move(to: CGPoint(x: layout.left, y: y))
      cross.addLine(to: CGPoint(x: layout.right, y: y))
      context.stroke(
        cross, with: .color(Theme.ChartColors.crosshairLine),
        style: StrokeStyle(lineWidth: 1, dash: ChartLayout.guideDash))
      let height = ChartText.labelHeight
      let pad = Double(ChartLayout.labelPad)
      let ink = Theme.ChartColors.crosshairText
      let priceBox = CGRect(
        x: layout.right + 1, y: y - height / 2, width: size.width - layout.right - 1,
        height: height)
      context.fill(Path(priceBox), with: .color(Theme.ChartColors.crosshair))
      context.draw(
        text(NumberFormat.price(value, decimals: priceDecimals), ink),
        at: CGPoint(x: priceBox.minX + pad, y: y), anchor: .leading)
      let month = points[selected].label
      let monthWidth = ChartText.width(month) + 2 * pad
      let monthBox = CGRect(
        x: min(max(x - monthWidth / 2, layout.left), layout.right - monthWidth),
        y: layout.plotBottom + 2, width: monthWidth, height: height)
      context.fill(Path(monthBox), with: .color(Theme.ChartColors.crosshair))
      context.draw(
        text(month, ink), at: CGPoint(x: monthBox.midX, y: monthBox.midY), anchor: .center)
    }
    .clipped()
  }
}
