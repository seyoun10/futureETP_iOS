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

  /// 가운데가 범위 안인 봉 순번. 꼬리표는 꼬리가 화면 밖인 봉을 뺀다(RN `centerIndexRange`). 없으면 nil
  var centerIndices: ClosedRange<Int>? {
    guard barCount > 0 else { return nil }
    let first = max(Int((lower - 0.5).rounded(.up)), 0)
    let last = min(Int((upper - 0.5).rounded(.down)), barCount - 1)
    return first <= last ? first...last : nil
  }

  /// 가장 과거 봉이 보인다(이전 3년을 이어 받을 때, D-104)
  var showsFirstBar: Bool { barCount > 0 && lower < 1 }

  /// 봉 배열이 `barCount`개로 바뀌었다. 앞에 붙은 봉 `prepended`개만큼 옮겨 보던 봉(날짜) 범위를 그대로 둔다.
  /// 뒤에 붙은 봉(새로고침으로 오늘 봉)은 순번을 바꾸지 않으니 `prepended`는 0이다 (RN `fitTransform.ts` `shiftedView`)
  func rebased(barCount newCount: Int, prepended: Int) -> Self {
    let shift = Double(prepended)
    return Self(barCount: newCount, lower: lower + shift, upper: upper + shift)
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
