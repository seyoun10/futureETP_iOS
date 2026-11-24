import Foundation
import SwiftUI

/// 차트가 그리는 봉과 선(C-a 봉·이평선·rare-level 밴드, C-c 월물 선). 봉마다 그 봉 위 선까지 포함한 위·아래 끝 가격(`envelope`)을
/// 미리 계산해 y 자동 맞춤이 봉과 선을 모두 넣게 한다 (RN `disparitySeries.ts` `chartEnvelope`)
struct CandleSeries: Sendable {
  struct Bar: Equatable, Sendable {
    let open: Double
    let high: Double
    let low: Double
    let close: Double

    var isUp: Bool { close >= open }
  }

  struct Line: Identifiable, Sendable {
    let id: String
    /// 봉 순번별 값. 값이 없는 봉은 nil
    let values: [Double?]
    let color: Color
    let width: Double
  }

  /// 선만 그리는 차트(C-c)는 비어 있다
  let bars: [Bar]
  /// 뒤에 있을수록 위에 그린다
  let lines: [Line]
  /// 순번(봉·날짜)마다 위·아래 끝. 선만 있는 차트에서 값이 없는 날은 −∞·+∞
  let high: [Double]
  let low: [Double]
  /// 십자선 가로선·가격 라벨 가격. 봉은 종가, 선만 있으면 그날 값이 있는 첫 선(RN `LinesChart` `close`)
  let crosshairPrices: [Double]
  /// log y축이면 true(D-056). 선만 있는 차트에서 0 이하 값이 있으면 선형이다(D-113)
  let isLog: Bool

  /// 순번 수(봉 수·날짜 수)
  var count: Int { high.count }

  init(bars: [Bar], lines: [Line]) {
    self.bars = bars
    self.lines = lines
    crosshairPrices = bars.map(\.close)
    isLog = true
    var high = bars.map(\.high)
    var low = bars.map(\.low)
    for line in lines {
      for (i, value) in line.values.enumerated() where i < bars.count {
        guard let value else { continue }
        if value > high[i] { high[i] = value }
        if value < low[i] { low[i] = value }
      }
    }
    self.high = high
    self.low = low
  }

  /// 선만 그리는 차트(C-c). `high`·`low`는 날짜마다 그날 선들의 위·아래 끝이다
  init(lines: [Line], high: [Double], low: [Double]) {
    bars = []
    self.lines = lines
    self.high = high
    self.low = low
    crosshairPrices = high.indices.map { i in
      lines.lazy.compactMap { $0.values.indices.contains(i) ? $0.values[i] : nil }.first ?? low[i]
    }
    isLog = low.allSatisfy { $0 > 0 }
  }
}

/// y축 변환. log(D-056) 또는 선형(0 이하 값이 있는 C-c, D-113). 보이는 봉의 위·아래 끝으로 범위를 다시 정하고,
/// 위·아래에 높이의 6%씩 여백을 둔다 (RN `fitTransform`)
struct PriceScale: Equatable, Sendable {
  static let padding = 0.06

  /// 변환한(log면 log 값) 범위 끝
  let lower: Double
  let upper: Double
  let isLog: Bool

  init(logLow: Double, logHigh: Double) {
    lower = logLow
    upper = logHigh
    isLog = true
  }

  init(linearLow: Double, linearHigh: Double) {
    lower = linearLow
    upper = linearHigh
    isLog = false
  }

  /// 보이는 순번의 끝 가격으로 맞춘다. 값이 없거나 log 축에서 가격이 0 이하면 nil
  init?(series: CandleSeries, indices: ClosedRange<Int>?) {
    guard let indices else { return nil }
    var top = -Double.infinity
    var bottom = Double.infinity
    for i in indices {
      top = max(top, series.high[i])
      bottom = min(bottom, series.low[i])
    }
    guard top.isFinite, bottom.isFinite else { return nil }
    if series.isLog {
      guard bottom > 0 else { return nil }
      self.init(logLow: Foundation.log(bottom), logHigh: Foundation.log(top))
    } else {
      self.init(linearLow: bottom, linearHigh: top)
    }
  }

  private func forward(_ price: Double) -> Double { isLog ? Foundation.log(price) : price }
  private func inverse(_ value: Double) -> Double { isLog ? Foundation.exp(value) : value }
  private var span: Double { max(upper - lower, 1e-9) }

  /// 높이 `height`에서 가격의 y(위가 0)
  func y(_ price: Double, height: Double) -> Double {
    let pad = height * Self.padding
    return pad + (upper - forward(price)) / span * (height - 2 * pad)
  }

  /// 높이 `height`에서 y(위가 0)에 있는 가격. `y(_:height:)`의 역함수
  func price(atY y: Double, height: Double) -> Double {
    let pad = height * Self.padding
    return inverse(upper - (y - pad) / max(height - 2 * pad, 1e-9) * span)
  }

  /// 여백까지 넣은 가격 범위(Swift Charts 축 도메인용)
  var paddedDomain: ClosedRange<Double> {
    let pad = span * Self.padding / (1 - 2 * Self.padding)
    return inverse(lower - pad)...inverse(upper + pad)
  }

  /// 그림 영역 위~아래 가격 범위의 눈금(log는 d3 `scaleLog().ticks(6)`, 선형은 `ticks(6)`)
  func ticks(from start: Double, to stop: Double) -> [Double] {
    isLog
      ? AxisTicks.log(from: start, to: stop)
      : AxisTicks.linear(from: min(start, stop), to: max(start, stop), count: AxisTicks.count)
  }
}

/// 선 레이어가 그릴 봉 순번(D-106). 화면 밖은 앞뒤 1봉만 남기고, 봉 간격이 1pt보다 좁으면 2의 거듭제곱 간격으로 건너뛰어
/// 1pt에 점이 하나 이하가 되게 한다. 간격의 배수를 고르므로 드래그 중에 선 모양이 흔들리지 않는다 (RN `lineSampling.ts`)
enum LineSample {
  static func indices(viewport: CandleViewport, width: Double) -> StrideThrough<Int>? {
    guard viewport.barCount > 0, width > 0 else { return nil }
    let perBar = width / viewport.span
    let low = max(0, Int(viewport.lower.rounded(.down)) - 1)
    let high = min(viewport.barCount - 1, Int(viewport.upper.rounded(.up)) + 1)
    guard low <= high else { return nil }
    let step = perBar >= 1 ? 1 : 1 << Int(Foundation.log2(1 / perBar).rounded(.down))
    return stride(from: low / step * step, through: high, by: step)
  }
}
