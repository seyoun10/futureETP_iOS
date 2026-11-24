import Foundation

/// 시각·거래일 표시. 언어와 상관없이 숫자 형식(`MM/DD HH:mm`)을 쓴다
/// (screens.md 기준 시각 줄, RN `lib/formatDateTime.ts`)
public enum DateTimeFormat {
  /// 시각 → 기기 현지(테스트는 시간대 지정) `MM/DD HH:mm`, 24시간제
  public static func localDateTime(_ date: Date, timeZone: TimeZone = .current) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let parts = calendar.dateComponents([.month, .day, .hour, .minute], from: date)
    return
      "\(twoDigits(parts.month!))/\(twoDigits(parts.day!)) \(twoDigits(parts.hour!)):\(twoDigits(parts.minute!))"
  }

  /// CME 거래일 → `MM/DD`. 달력 날짜라 시간대 변환을 하지 않는다
  public static func tradeDate(_ date: LocalDate) -> String {
    "\(twoDigits(date.month))/\(twoDigits(date.day))"
  }

  private static func twoDigits(_ value: Int) -> String {
    value < 10 ? "0\(value)" : "\(value)"
  }
}
