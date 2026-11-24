import Core
import Foundation
import Testing

@testable import HolidayCalendar

// RN `monthGrid.test.ts`와 같은 경우
struct MonthGridTests {
  private func date(_ string: String) -> LocalDate { LocalDate(string)! }

  @Test func threeMonthsFromTodayAcrossYears() throws {
    let months = MonthGrid.months(from: date("2026-11-21"), count: 3)
    #expect(
      months == [
        CalendarMonth(year: 2026, month: 11), CalendarMonth(year: 2026, month: 12),
        CalendarMonth(year: 2027, month: 1),
      ])
    let range = try #require(MonthGrid.range(months))
    #expect(range.from == date("2026-11-01"))
    #expect(range.to == date("2027-01-31"))
  }

  @Test func lastDayOfMonthDoesNotSkipNextMonth() {
    #expect(
      MonthGrid.months(from: date("2027-01-31"), count: 2) == [
        CalendarMonth(year: 2027, month: 1), CalendarMonth(year: 2027, month: 2),
      ])
    #expect(MonthGrid.range([CalendarMonth(year: 2028, month: 2)])?.to == date("2028-02-29"))
    #expect(MonthGrid.range([]) == nil)
  }

  @Test func cellsStartOnSundayAndPadBothEnds() {
    // 2026-11-01은 일요일, 30일은 월요일
    let nov = MonthGrid.cells(CalendarMonth(year: 2026, month: 11))
    #expect(nov.first == date("2026-11-01"))
    #expect(nov.count == 35)
    #expect(nov[29] == date("2026-11-30"))
    #expect(nov[30...].allSatisfy { $0 == nil })
    // 2027-01-01은 금요일
    let jan = MonthGrid.cells(CalendarMonth(year: 2027, month: 1))
    #expect(Array(jan[0..<6]) == [nil, nil, nil, nil, nil, date("2027-01-01")])
    #expect(jan.count.isMultiple(of: 7))
  }

  @Test func weekdayAndLocalDate() {
    #expect(MonthGrid.weekday(date("2026-11-26")) == 4)
    #expect(MonthGrid.weekday(date("1969-12-28")) == 0)
    // 2026-11-21T14:59Z = 서울 23:59
    let instant = Date(timeIntervalSince1970: 1_795_273_140)
    #expect(
      MonthGrid.localDate(instant, timeZone: TimeZone(identifier: "Asia/Seoul")!)
        == date("2026-11-21"))
    #expect(date("2026-12-31").adding(days: 1) == date("2027-01-01"))
    #expect(date("2028-03-01").adding(days: -1) == date("2028-02-29"))
  }
}
