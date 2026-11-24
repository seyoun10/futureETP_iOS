import Foundation

/// 보이는 봉 중 최고가·최저가 봉의 꼬리표 배치(screens.md C-a). 고가는 봉 위, 저가는 봉 아래에 두고
/// 화살표 글자가 봉을 가리킨다 (RN `charts/extremeTagLayout.ts`)
enum ExtremeTagLayout {
  enum Kind {
    case high
    case low

    var arrow: String { self == .high ? "↓" : "↑" }
  }

  /// 꼬리표와 봉·점선 사이 간격
  static let gap: Double = 3

  /// 꼬리표 위 끝 y. 차트 위·아래 끝 안으로 민다. 현재가 점선(`lineY`)이 글자를 지나가면 점선 바깥(봉 반대쪽)으로
  /// 옮기고, 그쪽이 차트를 넘으면 봉 쪽으로 옮긴다
  static func top(
    _ kind: Kind, y: Double, height: Double, gap: Double = gap, lineY: Double?, top: Double,
    bottom: Double
  ) -> Double {
    let clamp = { (v: Double) in min(max(v, top), bottom - height) }
    let placed = clamp(kind == .high ? y - height - gap : y + gap)
    guard let lineY, lineY >= placed - gap, lineY <= placed + height + gap else { return placed }
    let above = lineY - height - gap
    let below = lineY + gap
    let (first, second) = kind == .high ? (above, below) : (below, above)
    if first >= top, first <= bottom - height { return first }
    return clamp(second)
  }

  /// 꼬리표 왼쪽 끝 x와 화살표 위치. 화살표 글자 가운데가 봉 x에 온다. 화살표는 고가면 글자 뒤, 저가면 앞이 기본이고,
  /// 그쪽이 차트 끝을 넘으면 반대쪽에 붙인다. 양쪽 다 넘으면 덜 넘치는 쪽으로 두고 차트 안으로 민다
  static func left(
    _ kind: Kind, x: Double, width: Double, arrowWidth: Double, left: Double, right: Double
  ) -> (left: Double, arrowFirst: Bool) {
    let overflow = { (v: Double) in max(0, left - v) + max(0, v + width - right) }
    let at = { (first: Bool) in first ? x - arrowWidth / 2 : x + arrowWidth / 2 - width }
    let preferred = kind == .low
    let arrowFirst =
      overflow(at(!preferred)) < overflow(at(preferred)) ? !preferred : preferred
    return (min(max(at(arrowFirst), left), right - width), arrowFirst)
  }
}
