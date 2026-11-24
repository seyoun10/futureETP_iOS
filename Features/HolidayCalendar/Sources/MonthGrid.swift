import Core
import Foundation

/// 휴장 달력의 한 달
struct CalendarMonth: Hashable, Sendable {
  let year: Int
  let month: Int
}

/// 휴장 달력 화면의 달·칸 계산 (RN `features/calendar/monthGrid.ts`). 날짜는 모두 기기 로컬 날짜다
enum MonthGrid {
  /// `today`가 속한 달부터 `count`개월
  static func months(from today: LocalDate, count: Int) -> [CalendarMonth] {
    (0..<count).map { offset in
      let index = today.year * 12 + (today.month - 1) + offset
      return CalendarMonth(year: index / 12, month: index % 12 + 1)
    }
  }

  /// 첫 달 1일 ~ 마지막 달 말일. 빈 목록이면 nil
  static func range(_ months: [CalendarMonth]) -> (from: LocalDate, to: LocalDate)? {
    guard let first = months.first, let last = months.last,
      let from = LocalDate(year: first.year, month: first.month, day: 1),
      let to = LocalDate(year: last.year, month: last.month, day: daysInMonth(last))
    else { return nil }
    return (from, to)
  }

  /// 일요일 시작 주 단위 칸. 그 달이 아닌 칸은 nil이고, 길이는 7의 배수다
  static func cells(_ month: CalendarMonth) -> [LocalDate?] {
    guard let first = LocalDate(year: month.year, month: month.month, day: 1) else { return [] }
    var cells: [LocalDate?] = Array(repeating: nil, count: weekday(first))
    cells += (1...daysInMonth(month)).map {
      LocalDate(year: month.year, month: month.month, day: $0)
    }
    while !cells.count.isMultiple(of: 7) { cells.append(nil) }
    return cells
  }

  /// 요일(0 = 일요일). 1970-01-01은 목요일이다
  static func weekday(_ date: LocalDate) -> Int {
    let days = epoch.days(to: date)
    return ((days + 4) % 7 + 7) % 7
  }

  static func isWeekend(_ weekday: Int) -> Bool { weekday == 0 || weekday == 6 }

  /// `date`의 `timeZone` 날짜
  static func localDate(_ date: Date, timeZone: TimeZone) -> LocalDate {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return LocalDate(year: parts.year!, month: parts.month!, day: parts.day!)!
  }

  private static let epoch = LocalDate(year: 1970, month: 1, day: 1)!

  private static func daysInMonth(_ month: CalendarMonth) -> Int {
    (28...31).last { LocalDate(year: month.year, month: month.month, day: $0) != nil } ?? 28
  }
}

extension LocalDate {
  /// 달력 날짜로 `days`일 뒤(음수면 앞)
  func adding(days: Int) -> LocalDate {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    let start = calendar.date(from: DateComponents(year: year, month: month, day: day))!
    let moved = calendar.date(byAdding: .day, value: days, to: start)!
    return MonthGrid.localDate(moved, timeZone: .gmt)
  }
}
