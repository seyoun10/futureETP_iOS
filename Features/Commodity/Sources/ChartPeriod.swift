import Foundation
import Observation

/// C-a·C-c 기간 버튼. 한 줄에 다 들어가게 6개만 둔다. 더 긴 범위는 핀치로 본다 (D-102, RN `charts/chartPeriods.ts`)
public enum ChartPeriod: String, CaseIterable, Sendable {
  case m2 = "2M"
  case m4 = "4M"
  case m6 = "6M"
  case m8 = "8M"
  case m10 = "10M"
  case m12 = "12M"

  /// 원자재에 들어올 때마다 이 기간으로 시작한다 (D-107)
  public static let initial: ChartPeriod = .m6

  /// 기간 버튼이 보여 주는 거래일 봉 수(월 21일로 어림한다)
  public var bars: Int {
    switch self {
    case .m2: 42
    case .m4: 84
    case .m6: 126
    case .m8: 168
    case .m10: 210
    case .m12: 252
    }
  }

  /// 보이는 봉 수와 가장 가까운 기간(핀치 뒤 기간 칩 테두리). 비율로 비교한다.
  /// 전체 봉 수보다 긴 기간은 전체 봉 수로 줄여 비교하고, 같으면 짧은 기간을 고른다
  public static func nearest(visibleBars: Double, totalBars: Int) -> ChartPeriod {
    var best = ChartPeriod.m2
    var bestDistance = Double.infinity
    for period in allCases {
      let bars = Double(min(period.bars, totalBars))
      let distance = abs(log(visibleBars / bars))
      if distance < bestDistance {
        best = period
        bestDistance = distance
      }
    }
    return best
  }
}

/// C-a·C-c 기간 선택 (D-107). C 화면이 스택에 있는 동안만 기억하고(탭·ETP 상세를 오가도 유지),
/// 목록으로 나가면 잊는다. C-a와 C-c는 따로 고른다 (RN `ChartPeriodProvider`)
@Observable
public final class ChartPeriods {
  public var disparity = ChartPeriod.initial
  public var contract = ChartPeriod.initial

  public init() {}
}
