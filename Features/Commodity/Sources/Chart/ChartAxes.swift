import Core
import Foundation
import SwiftUI
import UIKit

/// 우측 y축 눈금(D-056). d3 `scaleLog().ticks(6)`과 같은 값을 고른다: 범위 안 `k·10^n`(k = 1…9)이 3개 이상이면 그것을,
/// 아니면 선형 눈금을 쓴다 (RN `YAxisLayer` `TICK_COUNT`)
enum AxisTicks {
  static let count = 6

  /// log 축 눈금. 범위가 비었거나 0 이하면 빈 배열
  static func log(from start: Double, to stop: Double, count: Int = count) -> [Double] {
    let (u, v) = start <= stop ? (start, stop) : (stop, start)
    guard u > 0, v.isFinite else { return [] }
    let i = log10(u)
    let j = log10(v)
    guard j - i < Double(count) else {
      // 10의 거듭제곱 눈금(차트 가격 범위에서는 생기지 않는다)
      return linear(from: i, to: j, count: min(Int(j - i), count)).map { pow(10, $0) }
    }
    var ticks: [Double] = []
    var power = Int(i.rounded(.down))
    outer: while Double(power) <= j.rounded(.up) {
      for k in 1..<10 {
        let t = power < 0 ? Double(k) / pow(10, Double(-power)) : Double(k) * pow(10, Double(power))
        if t < u { continue }
        if t > v { break outer }
        ticks.append(t)
      }
      power += 1
    }
    return ticks.count * 2 < count ? linear(from: u, to: v, count: count) : ticks
  }

  /// d3 `ticks(start, stop, count)`: 1·2·5 × 10^n 간격의 보기 좋은 눈금
  static func linear(from start: Double, to stop: Double, count: Int) -> [Double] {
    guard count > 0 else { return [] }
    if start == stop { return [start] }
    let (u, v) = start <= stop ? (start, stop) : (stop, start)
    guard let (i1, i2, inc) = spec(u, v, Double(count)), i2 >= i1 else { return [] }
    let ticks = (i1...i2).map { inc < 0 ? Double($0) / -inc : Double($0) * inc }
    return start <= stop ? ticks : ticks.reversed()
  }

  private static func spec(_ start: Double, _ stop: Double, _ count: Double) -> (Int, Int, Double)?
  {
    let step = (stop - start) / max(0, count)
    guard step.isFinite, step > 0 else { return nil }
    let power = Int(log10(step).rounded(.down))
    let error = step / pow(10, Double(power))
    let factor: Double =
      error >= 50.squareRoot() ? 10 : error >= 10.squareRoot() ? 5 : error >= 2.squareRoot() ? 2 : 1
    var i1: Int
    var i2: Int
    var inc: Double
    if power < 0 {
      inc = pow(10, Double(-power)) / factor
      i1 = Int((start * inc).rounded())
      i2 = Int((stop * inc).rounded())
      if Double(i1) / inc < start { i1 += 1 }
      if Double(i2) / inc > stop { i2 -= 1 }
      inc = -inc
    } else {
      inc = pow(10, Double(power)) * factor
      i1 = Int((start / inc).rounded())
      i2 = Int((stop / inc).rounded())
      if Double(i1) * inc < start { i1 += 1 }
      if Double(i2) * inc > stop { i2 -= 1 }
    }
    if i2 < i1, 0.5 <= count, count < 2 { return spec(start, stop, count * 2) }
    return (i1, i2, inc)
  }

  /// 눈금 간격을 구분할 만큼의 소수 자릿수, 최대 `max`(가격 소수 자릿수) (RN `curveLayout.ts` `tickDecimals`)
  static func decimals(_ ticks: [Double], max maxDecimals: Int) -> Int {
    var step = Double.infinity
    for i in ticks.indices.dropFirst() { step = min(step, ticks[i] - ticks[i - 1]) }
    guard step.isFinite, step > 0 else { return maxDecimals }
    return min(maxDecimals, max(0, -Int((log10(step) + 1e-9).rounded(.down))))
  }
}

/// y축 특수 라벨(현재가·이평선·rare-level) 배치(screens.md C-a y축 라벨, D-056). 선은 모두 그리고,
/// 라벨도 모두 남긴 채 겹치지 않게 위·아래로 민다 (RN `charts/priceLabels.ts`)
enum PriceLabelLayout {
  /// 라벨은 가운데 y에 그려 위·아래 끝에 붙으면 반이 잘린다. 반 높이만큼 안쪽으로 민다
  static func clampY(_ y: Double, height: Double, top: Double, bottom: Double) -> Double {
    min(max(y, top + height / 2), bottom - height / 2)
  }

  static func overlapsAny(_ y: Double, _ ys: [Double], height: Double) -> Bool {
    ys.contains { abs($0 - y) < height }
  }

  /// 위에서부터 겹치지 않게 아래로 밀고, 아래 끝을 넘으면 위로 되민다. 위·아래 밖 라벨은 뺀다.
  /// 입력 `y`는 선 위치, 돌려주는 `y`는 라벨 가운데 위치이고 위에서 아래 순서다
  static func stack<Label>(
    _ labels: [(label: Label, y: Double)], height: Double, top: Double, bottom: Double
  ) -> [(label: Label, y: Double)] {
    var sorted =
      labels
      .filter { $0.y >= top && $0.y <= bottom }
      .map { ($0.label, clampY($0.y, height: height, top: top, bottom: bottom)) }
      .enumerated().sorted { ($0.element.1, $0.offset) < ($1.element.1, $1.offset) }
      .map { (label: $0.element.0, y: $0.element.1) }
    for i in sorted.indices.dropFirst() {
      sorted[i].y = max(sorted[i].y, sorted[i - 1].y + height)
    }
    for i in sorted.indices.reversed() {
      let limit = i == sorted.count - 1 ? bottom - height / 2 : sorted[i + 1].y - height
      sorted[i].y = min(sorted[i].y, limit)
    }
    return sorted
  }
}

/// 보이는 봉 구간의 월 경계 x축 눈금(D-056). 1월은 연도, 나머지는 월 이름(screens.md C-a의 "11월 2026 3월")
/// (RN `charts/monthTicks.ts`)
enum MonthTicks {
  struct Tick: Equatable {
    let index: Int
    let year: Int
    let month: Int
  }

  static let steps = [1, 2, 3, 6, 12, 24, 48]
  /// 이웃 라벨 사이 최소 여백
  static let gap: Double = 8

  /// 라벨이 겹치지 않는 가장 촘촘한 월 간격의 눈금. `minGap`은 이웃 눈금 사이 최소 봉 수(라벨 너비 + 여백 / 봉 간격)
  static func ticks(dates: [LocalDate], range: ClosedRange<Int>, minGap: Double) -> [Tick] {
    var boundaries: [Tick] = []
    let upper = min(range.upperBound, dates.count - 1)
    var i = max(range.lowerBound, 1)
    while i <= upper {
      let previous = dates[i - 1]
      let current = dates[i]
      if previous.year != current.year || previous.month != current.month {
        boundaries.append(Tick(index: i, year: current.year, month: current.month))
      }
      i += 1
    }
    var ticks: [Tick] = []
    for step in steps {
      ticks = boundaries.filter { ($0.year * 12 + $0.month - 1) % step == 0 }
      if zip(ticks, ticks.dropFirst()).allSatisfy({ Double($1.index - $0.index) >= minGap }) {
        break
      }
    }
    return ticks
  }

  static func label(year: Int, month: Int, locale: Locale) -> String {
    month == 1 ? String(year) : L10n.string("chart.months.\(month)", locale: locale)
  }
}

/// y축 특수 라벨(현재가·이평선·rare-level 값, C-c 월물 끝값). 선 색으로 쓴다
struct ChartPriceLabel: Equatable, Sendable {
  let id: String
  let price: Double
  let color: Color
}

/// 롤 표시: 한국형·미국형은 롤 기간 음영 구간, 대표월물은 전환일 봉 순번(세로 점선) (D-103, RN `RollLayer`)
struct ChartRollMarks: Equatable, Sendable {
  var shading: [ClosedRange<Int>] = []
  var switches: [Int] = []
}

/// 차트 축·십자선 글자. Canvas 밖에서 자리(y축 폭·월 라벨 폭)를 잴 때도 같은 글꼴을 쓴다
enum ChartText {
  static let font = Font.system(size: ChartLayout.fontSize).monospacedDigit()
  private static let uiFont = UIFont.monospacedDigitSystemFont(
    ofSize: ChartLayout.fontSize, weight: .regular)

  static func width(_ text: String) -> Double {
    (text as NSString).size(withAttributes: [.font: uiFont]).width.rounded(.up)
  }

  /// 글자 한 줄 높이(꼬리표)
  static let lineHeight = Double(uiFont.lineHeight.rounded(.up))
  /// 라벨 상자 높이(겹침 판정에도 쓴다)
  static let labelHeight = Double(ChartLayout.fontSize + 2 * ChartLayout.labelPad)
  /// 십자선 날짜 상자 너비
  static let dateBoxWidth = width("0000-00-00") + 2 * Double(ChartLayout.labelPad)

  /// 1월(연도)을 포함한 모든 월 라벨 중 가장 넓은 너비. 월 눈금 겹침 판정은 이 너비로 한다
  static func widestMonthLabel(locale: Locale) -> Double {
    (1...12).map { width(MonthTicks.label(year: 2000, month: $0, locale: locale)) }.max() ?? 0
  }
}
