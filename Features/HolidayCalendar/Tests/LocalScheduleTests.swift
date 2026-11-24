import Core
import Foundation
import Testing

@testable import HolidayCalendar

/// 계약 형태 JSON으로 예외 일정을 만든다(디코딩 검사도 함께 탄다)
func exception(
  _ market: CalendarMarket, _ date: String, _ kind: CalendarExceptionKind = .closed,
  at: String? = nil, note: String = ""
) -> CalendarException {
  let json: [String: Any] = [
    "market": market.rawValue, "date": date, "kind": kind.rawValue, "at": at ?? NSNull(),
    "note": note,
  ]
  let data = try! JSONSerialization.data(withJSONObject: json)
  return try! JSONDecoder().decode(CalendarException.self, from: data)
}

func zone(_ identifier: String) -> TimeZone { TimeZone(identifier: identifier)! }

// RN `localSchedule.test.ts`와 같은 경우
struct LocalScheduleTests {
  private func iso(_ date: Date) -> String { date.formatted(.iso8601) }

  @Test func marketWallClockFollowsDaylightSaving() {
    let d = { LocalDate($0)! }
    #expect(
      iso(
        LocalSchedule.instant(
          d("2026-11-27"), hour: 13, minute: 0, timeZone: zone("America/New_York")))
        == "2026-11-27T18:00:00Z")
    #expect(
      iso(
        LocalSchedule.instant(
          d("2026-07-03"), hour: 13, minute: 30, timeZone: zone("America/Chicago")))
        == "2026-07-03T18:30:00Z")
    // 서머타임 시작일(3/8 02:00 CST → 03:00 CDT) 당일 오후
    #expect(
      iso(
        LocalSchedule.instant(
          d("2026-03-08"), hour: 17, minute: 0, timeZone: zone("America/Chicago")))
        == "2026-03-08T22:00:00Z")
  }

  @Test func timedExceptionMovesToLocalDateAndTime() {
    let halt = exception(.cme, "2026-11-26", .halt, at: "13:30")
    let seoul = LocalSchedule.local(halt, timeZone: zone("Asia/Seoul"))
    #expect(seoul.localDate == LocalDate("2026-11-27"))
    #expect(seoul.localTime == "04:30")
    let la = LocalSchedule.local(halt, timeZone: zone("America/Los_Angeles"))
    #expect(la.localDate == LocalDate("2026-11-26"))
    #expect(la.localTime == "11:30")
    let lateOpen = exception(.krx, "2027-01-04", .lateOpen, at: "10:00")
    let ny = LocalSchedule.local(lateOpen, timeZone: zone("America/New_York"))
    #expect(ny.localDate == LocalDate("2027-01-03"))
    #expect(ny.localTime == "20:00")
  }

  @Test func closedUsesRegularOpenLocalDate() {
    let nyse = LocalSchedule.local(exception(.nyse, "2026-11-26"), timeZone: zone("Asia/Seoul"))
    #expect(nyse.localDate == LocalDate("2026-11-26"))
    #expect(nyse.localTime == nil)
    // CME 거래일 세션은 전날 17:00 CT에 열린다
    let cme = exception(.cme, "2026-12-25")
    #expect(
      LocalSchedule.local(cme, timeZone: zone("Asia/Seoul")).localDate == LocalDate("2026-12-25"))
    #expect(
      LocalSchedule.local(cme, timeZone: zone("America/Chicago")).localDate
        == LocalDate("2026-12-24"))
    let krx = exception(.krx, "2026-12-31")
    #expect(
      LocalSchedule.local(krx, timeZone: zone("America/New_York")).localDate
        == LocalDate("2026-12-30"))
  }

  @Test func sortsByLocalTimeWithClosedAtRegularOpen() {
    let list = LocalSchedule.local(
      [
        exception(.krx, "2026-12-25"),
        exception(.cme, "2026-12-24", .earlyClose, at: "12:45"),
        exception(.nyse, "2026-12-25"),
        exception(.cme, "2026-12-25"),
        exception(.nyse, "2026-12-24", .earlyClose, at: "13:00"),
      ], timeZone: zone("Asia/Seoul"))
    // 03:00 NYSE 조기 마감, 03:45 CME 조기 마감, 08:00 CME 개장, 09:00 KRX 개장, 23:30 NYSE 개장
    #expect(list.allSatisfy { $0.localDate == LocalDate("2026-12-25") })
    #expect(list.map(\.market) == [.nyse, .cme, .cme, .krx, .nyse])
    #expect(list.map(\.kind) == [.earlyClose, .earlyClose, .closed, .closed, .closed])
  }

  @Test func sameInstantFollowsMarketOrder() {
    // 13:30 CT = 14:30 ET
    let list = LocalSchedule.local(
      [
        exception(.nyse, "2026-11-26", .earlyClose, at: "14:30"),
        exception(.cme, "2026-11-26", .halt, at: "13:30"),
      ], timeZone: zone("Asia/Seoul"))
    #expect(list.map(\.market) == [.cme, .nyse])
  }

  @Test func widensRangeByOneDay() {
    let wide = LocalSchedule.widen((LocalDate("2027-01-01")!, LocalDate("2027-02-28")!))
    #expect(wide.from == LocalDate("2026-12-31"))
    #expect(wide.to == LocalDate("2027-03-01"))
  }
}
