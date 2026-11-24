import Core
import Foundation

/// C-b 커브 차트 한 장의 좌표. 크기·위쪽 정보 줄 높이가 정해진 뒤 만든다 (RN `charts/CurveChart.tsx` `layout`·`pctLabels`)
/// - y축은 C-a처럼 log(값의 비율이 같은 높이)이고, 0 이하 값이 있으면(2020-04 CL 음수 정산) 선형이다
/// - 선·점은 정보 줄 아래(`dataTop`~`plotBottom`)에 맞추고, 격자·눈금은 그림 영역 전체(`top`~`plotBottom`)에 그린다
struct CurveChartLayout {
  /// 만기순 월물 하나. 그 커브에 없으면 nil
  struct Point: Equatable {
    /// 십자선 라벨(`YYMM`)
    let label: String
    let contractMonth: ContractMonth
    let base: Double?
    let current: Double?
    let changePct: Double?
  }

  /// 놓은 변화율 라벨. `y`는 글자 아래 끝(높이 `ChartLayout.fontSize`)
  struct PctLabel: Equatable {
    let index: Int
    let pct: Double
    let text: String
    let x: Double
    let y: Double
    let width: Double
  }

  static let tickCount = 5
  /// 그림 영역 위 여백(가장 위 눈금 글자 자리)
  static let top = Double(ChartLayout.fontSize + Theme.Spacing.sm)
  /// x축 라벨 자리. C-a·C-c와 같게 둔다(되돌리기 버튼·하단 줄 위치를 세 탭이 맞춘다)
  static let bottom = Double(ChartLayout.xLabelHeight)
  /// 그림 영역 오른쪽 끝과 y축 눈금 글자 사이
  static let yLabelGap = 4.0
  /// 점 반지름
  static let dot = 3.0
  /// 라벨 사이 최소 여백
  static let labelGap = 4.0
  /// 기준일 실선·비교일 점선 굵기
  static let seriesStroke = 1.0
  /// 비교일 점선의 선·빈칸 길이
  static let curveDash: [Double] = [3, 2]

  let points: [Point]
  let ticks: [Double]
  let tickLabels: [String]
  let left = 0.0
  let right: Double
  let plotBottom: Double
  /// 선·점을 그리는 위 끝(정보 줄 바로 아래)
  let dataTop: Double
  /// 월물 칸 너비
  let slot: Double
  let isLog: Bool
  private let yMax: Double
  private let perPx: Double

  /// - Parameters:
  ///   - insetTop: 차트 위에 겹친 정보 줄 높이
  ///   - measure: 차트 글자 너비
  init?(
    points: [Point], priceDecimals: Int, size: CGSize, insetTop: Double,
    measure: @MainActor (String) -> Double = ChartText.width
  ) {
    let prices = points.flatMap { [$0.base, $0.current] }.compactMap(\.self)
    guard let lo = prices.min(), let hi = prices.max(), size.width > 0 else { return nil }
    let isLog = lo > 0
    let toAxis: (Double) -> Double = isLog ? { Foundation.log($0) } : { $0 }
    let fromAxis: (Double) -> Double = isLog ? { Foundation.exp($0) } : { $0 }
    // 위아래 여백(축 공간). 모두 같은 값이면 값의 2% 폭을 기준으로 둔다
    let span = toAxis(hi) - toAxis(lo)
    let fallback = isLog ? 0.02 : abs(hi) * 0.02
    let pad = (span != 0 ? span : fallback != 0 ? fallback : 1) * 0.08
    let yMin = toAxis(lo) - pad
    let yMax = toAxis(hi) + pad
    let plotBottom = Double(size.height) - Self.bottom
    let dataTop = Self.top + insetTop
    let perPx = (yMax - yMin) / max(plotBottom - dataTop, 1)
    // 눈금 값은 1·2·5 간격(커브는 한 자릿수 배 안쪽이라 log 눈금 대신 C-a처럼 고른 값)
    let ticks = AxisTicks.linear(
      from: fromAxis(yMin), to: fromAxis(yMax + (dataTop - Self.top) * perPx),
      count: Self.tickCount)
    let tickDecimals = AxisTicks.decimals(ticks, max: priceDecimals)
    let tickLabels = ticks.map { NumberFormat.price($0, decimals: tickDecimals) }
    // 축 폭은 눈금 글자와 십자선 가격 라벨(가격 자릿수 전부) 중 넓은 쪽. 눈금만 보면 `86.85`가 잘린다
    let tickWidth = (tickLabels.map(measure).max() ?? 0) + Double(ChartLayout.yLabelPad)
    let crosshairWidth =
      (points.compactMap { $0.current ?? $0.base }
        .map { measure(NumberFormat.price($0, decimals: priceDecimals)) }.max() ?? 0)
      + 2 * Double(ChartLayout.labelPad) + 1
    self.points = points
    self.ticks = ticks
    self.tickLabels = tickLabels
    self.right = Double(size.width) - max(tickWidth, crosshairWidth)
    self.plotBottom = plotBottom
    self.dataTop = dataTop
    self.slot = (right - left) / Double(max(points.count, 1))
    self.isLog = isLog
    self.yMax = yMax
    self.perPx = perPx
  }

  /// 월물 칸 가운데
  func x(_ index: Int) -> Double { left + slot * (Double(index) + 0.5) }

  func y(_ value: Double) -> Double {
    dataTop + (yMax - (isLog ? Foundation.log(value) : value)) / perPx
  }

  /// 점 가운데에 맞춘 글자의 왼쪽 x. 첫·끝 칸에서 칸 반폭보다 넓으면 그림 영역 안으로 민다
  func textX(_ index: Int, width: Double) -> Double {
    min(max(x(index) - width / 2, left), right - width)
  }

  /// 손가락 x에 가장 가까운 월물
  func nearestIndex(x: Double) -> Int? {
    CurveLayout.nearestSlot(x: x, left: left, slotWidth: slot, count: points.count)
  }

  /// 십자선 가로선·가격 라벨 값. 현재가(없으면 기준일 값)를 따라간다
  func crosshairValue(_ index: Int) -> Double? {
    points.indices.contains(index) ? points[index].current ?? points[index].base : nil
  }

  /// 두 선의 선분. 값이 빠진 월물에서 끊긴다
  var segments: [CurveLayout.Segment] {
    [\Point.base, \Point.current].flatMap { key in
      zip(points.indices, points.indices.dropFirst()).compactMap { i, j in
        guard let v = points[i][keyPath: key], let next = points[j][keyPath: key] else {
          return nil
        }
        return CurveLayout.Segment(x0: x(i), y0: y(v), x1: x(j), y1: y(next))
      }
    }
  }

  /// 변화율 라벨. 모든 월물에 붙이고, 오르면 점 위·내리면 점 아래다(반올림해 0이면 위).
  /// 이웃과 겹치면 같은 쪽 바깥으로 밀어내고, 선과 겹치면 좌우로 민다
  func pctLabels(
    format: @MainActor (Double) -> String = CurveFormat.pct,
    decimals: Int = CurveFormat.pctDecimals,
    measure: @MainActor (String) -> Double = ChartText.width
  ) -> [PctLabel] {
    let items: [(index: Int, pct: Double, text: String, label: CurveLayout.PctLabel)] =
      points.indices.compactMap { i in
        let p = points[i]
        guard let pct = p.changePct else { return nil }
        let ys = [p.base, p.current].compactMap(\.self).map(y)
        let text = format(pct)
        let width = measure(text)
        return (
          i, pct, text,
          CurveLayout.PctLabel(
            x: textX(i, width: width), anchor: x(i), width: width,
            top: (ys.min() ?? 0) - Self.dot, bottom: (ys.max() ?? 0) + Self.dot,
            below: Self.roundsNegative(pct, decimals: decimals))
        )
      }
    let positions = CurveLayout.placePctLabels(
      items.map(\.label), height: Double(ChartLayout.fontSize), gap: Self.labelGap,
      minY: dataTop, maxY: plotBottom, minX: left, maxX: right, segments: segments)
    return zip(items, positions).map { item, position in
      PctLabel(
        index: item.index, pct: item.pct, text: item.text, x: position.x, y: position.y,
        width: item.label.width)
    }
  }

  /// 화면 x 구간 `[x0, x1]`에 그려진 점·선분·변화율 글자의 세로 구간. 상세 박스 귀퉁이 고르기용
  func markSpans(x0: Double, x1: Double, pctLabels: [PctLabel]) -> [ClosedRange<Double>] {
    var spans: [ClosedRange<Double>] = []
    for key in [\Point.base, \Point.current] {
      for i in points.indices {
        guard let v = points[i][keyPath: key] else { continue }
        let px = x(i)
        let py = y(v)
        if px >= x0 - Self.dot, px <= x1 + Self.dot {
          spans.append((py - Self.dot)...(py + Self.dot))
        }
        // 다음 점까지의 선분 중 [x0, x1] 안 부분의 세로 구간
        guard i + 1 < points.count, let next = points[i + 1][keyPath: key] else { continue }
        let nx = x(i + 1)
        let a = max(px, x0)
        let b = min(nx, x1)
        guard a <= b else { continue }
        let ny = y(next)
        let at = { (x: Double) in py + (ny - py) * (x - px) / (nx - px) }
        spans.append(min(at(a), at(b))...max(at(a), at(b)))
      }
    }
    for l in pctLabels where l.x + l.width >= x0 && l.x <= x1 {
      spans.append((l.y - Double(ChartLayout.fontSize))...l.y)
    }
    return spans
  }

  /// 표시 자릿수로 반올림해 음수인지(0.0%는 방향 없음이라 위)
  static func roundsNegative(_ pct: Double, decimals: Int) -> Bool {
    pct < 0 && (Double(NumberFormat.toFixed(-pct, decimals: decimals)) ?? 0) > 0
  }
}

extension CurveChartLayout.Point {
  init(_ contract: CurveContract) {
    self.init(
      label: NumberFormat.contractMonthShort(contract.contractMonth),
      contractMonth: contract.contractMonth, base: contract.basePrice,
      current: contract.currentPrice, changePct: contract.changePct)
  }
}
