import Core

/// A-a 문구 (RN `CalendarScreen`의 `kindText`·`cellDate`·`listDate`)
enum CalendarText {
  typealias Translate = (_ key: String, _ values: [String: String]) -> String

  /// i18n 키. 요일은 0 = 일요일 순, 달은 1월부터
  static let weekdayKeys = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
  static let monthKeys = [
    "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec",
  ]

  static func monthName(_ month: Int, t: Translate) -> String {
    t("calendar.months.\(monthKeys[month - 1])", [:])
  }

  static func monthTitle(_ month: CalendarMonth, t: Translate) -> String {
    t("calendar.monthTitle", ["year": String(month.year), "month": monthName(month.month, t: t)])
  }

  static func weekday(_ weekday: Int, t: Translate) -> String {
    t("calendar.weekdays.\(weekdayKeys[weekday])", [:])
  }

  static func market(_ market: CalendarMarket, t: Translate) -> String {
    t("calendar.markets.\(market.rawValue)", [:])
  }

  /// `휴장`, `조기 마감 03:00`. 시각은 기기 로컬이고 시간대 표기는 붙이지 않는다 (D-144)
  static func kind(_ exception: LocalCalendarException, t: Translate) -> String {
    t("calendar.kinds.\(exception.kind.rawValue)", ["time": exception.localTime ?? ""])
  }

  /// 목록 날짜 `11/28 (토)`
  static func listDate(_ date: LocalDate, t: Translate) -> String {
    t(
      "calendar.listDate",
      [
        "date": DateTimeFormat.tradeDate(date),
        "weekday": weekday(MonthGrid.weekday(date), t: t),
      ])
  }

  /// 날짜 칸 스크린 리더 문구 `11월 27일, 오늘, CME 휴장 (04:30 거래 중단)`
  static func cellLabel(
    _ date: LocalDate, isToday: Bool, exceptions: [LocalCalendarException], t: Translate
  ) -> String {
    let cellDate = t(
      "calendar.cellDate", ["month": monthName(date.month, t: t), "day": String(date.day)])
    let today = isToday ? [t("calendar.legendToday", [:])] : []
    let items = exceptions.map { "\(market($0.market, t: t)) \(kind($0, t: t))" }
    return ([cellDate] + today + items).joined(separator: ", ")
  }

  static func missing(_ missing: CalendarMissingYear, t: Translate) -> String {
    t("calendar.missing", ["market": market(missing.market, t: t), "year": String(missing.year)])
  }
}
