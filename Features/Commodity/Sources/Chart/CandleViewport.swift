import Foundation

/// C-a·C-c 차트의 보이는 봉 범위(D-056, D-087). 봉 i는 x 칸 `[i, i+1)`을 차지하고, 범위는 소수 봉 순번이다.
/// 축소는 전체 봉까지, 확대는 `minVisibleBars`개까지, 이동은 데이터 시작부터 끝까지로 제한한다 (RN `charts/fitTransform.ts`)
struct CandleViewport: Equatable, Sendable {
  /// 최대 확대에서도 보이는 최소 봉 수
  static let minVisibleBars: Double = 20

  let barCount: Int
  private(set) var lower: Double
  private(set) var upper: Double

  init(barCount: Int, lower: Double, upper: Double) {
    self.barCount = barCount
    self.lower = 0
    self.upper = Double(barCount)
    clamp(lower: lower, upper: upper)
  }

  /// 마지막 `bars`개 봉이 보이는 범위(기간 버튼 동작)
  static func lastBars(_ bars: Int, of barCount: Int) -> Self {
    Self(barCount: barCount, lower: Double(barCount - bars), upper: Double(barCount))
  }

  /// 보이는 봉 수(소수)
  var span: Double { upper - lower }

  /// 범위에 조금이라도 걸친 봉 순번. 봉이 없으면 nil
  var visibleIndices: ClosedRange<Int>? {
    guard barCount > 0 else { return nil }
    let first = min(max(Int(lower.rounded(.down)), 0), barCount - 1)
    let last = min(max(Int(upper.rounded(.up)) - 1, first), barCount - 1)
    return first...last
  }

  /// 봉 수만큼 옮긴다. 음수면 과거 쪽
  func panned(byBars delta: Double) -> Self {
    Self(barCount: barCount, lower: lower + delta, upper: upper + delta)
  }

  /// 핀치: 시작 범위의 `startAnchor`(폭 대비 0…1) 지점이 지금 손가락 가운데 `anchor`에 오도록 `scale`배 확대한다.
  /// 배율을 먼저 제한해야 최대·최소 배율에서 더 벌리거나 오므려도 화면이 밀리지 않는다
  func zoomed(scale: Double, startAnchor: Double, anchor: Double) -> Self {
    let newSpan = Self.clampedSpan(span / max(scale, .leastNonzeroMagnitude), barCount: barCount)
    let anchorBar = lower + startAnchor * span
    let newLower = anchorBar - anchor * newSpan
    return Self(barCount: barCount, lower: newLower, upper: newLower + newSpan)
  }

  /// 화면 폭 `width`에서 봉 i 가운데의 x
  func centerX(ofBar index: Int, width: Double) -> Double {
    (Double(index) + 0.5 - lower) * width / span
  }

  /// 화면 x에 있는 봉 순번(범위 밖이면 가장 가까운 봉). 봉이 없으면 nil
  func barIndex(atX x: Double, width: Double) -> Int? {
    guard barCount > 0, width > 0 else { return nil }
    let index = Int((lower + x / width * span).rounded(.down))
    return min(max(index, 0), barCount - 1)
  }

  private static func clampedSpan(_ span: Double, barCount: Int) -> Double {
    let total = Double(barCount)
    return min(max(span, min(minVisibleBars, total)), total)
  }

  private mutating func clamp(lower: Double, upper: Double) {
    let total = Double(barCount)
    let span = Self.clampedSpan(upper - lower, barCount: barCount)
    let start = min(max(lower, 0), total - span)
    self.lower = start
    self.upper = start + span
  }
}
