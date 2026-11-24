import SwiftUI

/// 기준 시각 줄에 보일 시각. ETP 목록처럼 거래일·장 상태가 없는 화면은 기준 시각만 보낸다 (RN `FooterTime`)
public enum FooterTime: Sendable, Equatable {
  case market(Freshness)
  case asOf(Date)
}

/// A·C 화면 최하단 기준 시각 줄: `10/22 09:00 기준 · 거래일 10/22 · 지연 · 장중` (screens.md 공통 규칙).
/// 새로고침이 실패해도 마지막 데이터의 기준 시각을 그대로 보여 오래됨을 알린다. nil이면 빈 줄로 자리를 지킨다
public struct FreshnessLine: View {
  private let time: FooterTime?
  @Environment(\.locale) private var locale

  public init(_ time: FooterTime?) {
    self.time = time
  }

  public var body: some View {
    FooterLine(time.map { Self.text($0, locale: locale) })
  }

  /// 줄 문구. 시각은 기기 현지 시간대다
  nonisolated public static func text(
    _ time: FooterTime, locale: Locale, bundle: Bundle = .main, timeZone: TimeZone = .current
  ) -> String {
    let string = { (key: String, values: [String: String]) in
      L10n.string(key, values, locale: locale, bundle: bundle)
    }
    switch time {
    case .asOf(let asOf):
      return string(
        "freshness.asOf", ["time": DateTimeFormat.localDateTime(asOf, timeZone: timeZone)])
    case .market(let freshness):
      var items = [
        string(
          "freshness.asOf",
          ["time": DateTimeFormat.localDateTime(freshness.asOf, timeZone: timeZone)]),
        string("freshness.tradeDate", ["date": DateTimeFormat.tradeDate(freshness.tradeDate)]),
      ]
      if freshness.delayed { items.append(string("freshness.delayed", [:])) }
      items.append(string("freshness.marketState.\(freshness.marketState.rawValue)", [:]))
      return items.joined(separator: " · ")
    }
  }
}
