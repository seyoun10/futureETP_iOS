import SwiftUI

/// 등락 색 스타일(D-031): 한국식 상승 빨강·하락 파랑, 미국식 상승 초록·하락 빨강
public enum UpDownStyle: String, Codable, Sendable, CaseIterable {
  case kr = "KR"
  case us = "US"
}

/// 등락 색은 토큰이 아니라 표시 설정에서 고른다(D-031). 차트·목록이 같은 함수로 읽는다 (RN `theme/upDownColor.ts`)
public struct UpDownPalette: Equatable, Sendable {
  public let up: Color
  public let down: Color
  public let flat: Color

  public init(_ style: UpDownStyle) {
    switch style {
    case .kr:
      up = Color(hex: 0xef5350)
      down = Color(hex: 0x42a5f5)
    case .us:
      up = Color(hex: 0x26a69a)
      down = Color(hex: 0xef5350)
    }
    flat = Theme.Colors.neutral
  }

  /// 변화량 부호로 색을 고른다. 0·NaN은 방향 없는 색이다.
  /// `decimals`를 주면 그 자릿수로 반올림한 값(화면에 쓴 값)으로 고른다: `0.0%`로 보이는 -0.04는 방향 없는 색
  public func color(for change: Double, decimals: Int? = nil) -> Color {
    let shown = decimals.map { Self.rounded(change, decimals: $0) } ?? change
    if shown > 0 { return up }
    if shown < 0 { return down }
    return flat
  }

  /// 변화량과 등락률(소수 둘째 자리)을 함께 보이는 줄의 색. 둘 다 반올림해 0이면 방향 없는 색이다
  /// (NG처럼 변화량은 `0.000`인데 등락률은 `+0.01%`일 수 있어 둘 중 0이 아닌 쪽을 따른다)
  public func color(change: Double, changePct: Double, decimals: Int) -> Color {
    let shownChange = Self.rounded(change, decimals: decimals)
    let shown =
      shownChange != 0
      ? shownChange : Self.rounded(changePct, decimals: NumberFormat.changePctDecimals)
    return color(for: shown)
  }

  /// JS `Number(value.toFixed(decimals))`와 같은 값. NaN은 그대로
  static func rounded(_ value: Double, decimals: Int) -> Double {
    guard value.isFinite else { return value }
    let magnitude = Double(NumberFormat.toFixed(abs(value), decimals: decimals)) ?? 0
    return value < 0 ? -magnitude : magnitude
  }
}
