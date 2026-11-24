import Foundation
import SwiftUI

/// 캔들 차트가 그리는 봉과 선(C-a 이평선·rare-level 밴드). 봉마다 그 봉 위 선까지 포함한 위·아래 끝 가격(`envelope`)을
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

  let bars: [Bar]
  /// 뒤에 있을수록 위에 그린다
  let lines: [Line]
  let high: [Double]
  let low: [Double]

  init(bars: [Bar], lines: [Line]) {
    self.bars = bars
    self.lines = lines
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
}

/// log y축(D-056). 보이는 봉의 위·아래 끝으로 범위를 다시 정하고, 위·아래에 높이의 6%씩 여백을 둔다 (RN `fitTransform`)
struct PriceScale: Equatable, Sendable {
  static let padding = 0.06

  let logLow: Double
  let logHigh: Double

  init(logLow: Double, logHigh: Double) {
    self.logLow = logLow
    self.logHigh = logHigh
  }

  /// 보이는 봉의 끝 가격으로 맞춘다. 봉이 없거나 가격이 0 이하면 nil
  init?(series: CandleSeries, indices: ClosedRange<Int>?) {
    guard let indices else { return nil }
    var top = -Double.infinity
    var bottom = Double.infinity
    for i in indices {
      top = max(top, series.high[i])
      bottom = min(bottom, series.low[i])
    }
    guard bottom > 0, top.isFinite else { return nil }
    logLow = Foundation.log(bottom)
    logHigh = Foundation.log(top)
  }

  /// 높이 `height`에서 가격의 y(위가 0)
  func y(_ price: Double, height: Double) -> Double {
    let pad = height * Self.padding
    let span = max(logHigh - logLow, 1e-9)
    return pad + (logHigh - Foundation.log(price)) / span * (height - 2 * pad)
  }

  /// 높이 `height`에서 y(위가 0)에 있는 가격. `y(_:height:)`의 역함수
  func price(atY y: Double, height: Double) -> Double {
    let pad = height * Self.padding
    let span = max(logHigh - logLow, 1e-9)
    return Foundation.exp(logHigh - (y - pad) / max(height - 2 * pad, 1e-9) * span)
  }

  /// 여백까지 넣은 가격 범위(Swift Charts 축 도메인용)
  var paddedDomain: ClosedRange<Double> {
    let span = max(logHigh - logLow, 1e-9)
    let pad = span * Self.padding / (1 - 2 * Self.padding)
    return Foundation.exp(logLow - pad)...Foundation.exp(logHigh + pad)
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
