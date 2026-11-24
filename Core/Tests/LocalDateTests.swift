import Testing

@testable import Core

@Suite struct LocalDateTests {
  @Test func daysCountsCalendarDaysAcrossMonthsYearsAndLeapDays() throws {
    let d = { (s: String) in LocalDate(s)! }
    #expect(d("2026-11-25").days(to: d("2027-01-27")) == 63)
    #expect(d("2027-01-27").days(to: d("2026-11-25")) == -63)
    #expect(d("2024-02-28").days(to: d("2024-03-01")) == 2)
    #expect(d("2023-02-28").days(to: d("2023-03-01")) == 1)
    #expect(d("2026-12-31").days(to: d("2026-12-31")) == 0)
  }
}
