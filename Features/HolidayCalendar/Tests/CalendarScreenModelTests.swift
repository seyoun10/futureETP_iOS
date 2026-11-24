import Core
import Foundation
import Synchronization
import Testing

@testable import HolidayCalendar

/// 받은 범위를 기록하고 정한 응답을 돌려준다
private final class FakeCalendarRepository: CalendarRepository {
  let response: MarketCalendar
  let queries = Mutex<[CalendarQuery]>([])

  init(_ response: MarketCalendar) { self.response = response }

  func fetchCalendar(_ query: CalendarQuery) async throws -> MarketCalendar {
    queries.withLock { $0.append(query) }
    return response
  }
}

/// 한국어 문구(RN `ko.ts` 중 이 화면이 쓰는 것)
private func t(_ key: String, _ values: [String: String]) -> String {
  let ko: [String: String] = [
    "calendar.monthTitle": "{{year}}년 {{month}}",
    "calendar.months.nov": "11월", "calendar.months.dec": "12월", "calendar.months.jan": "1월",
    "calendar.weekdays.thu": "목", "calendar.weekdays.fri": "금", "calendar.weekdays.sat": "토",
    "calendar.markets.CME": "CME", "calendar.markets.KRX": "KRX", "calendar.markets.NYSE": "NYSE",
    "calendar.kinds.CLOSED": "휴장", "calendar.kinds.HALT": "휴장 ({{time}} 거래 중단)",
    "calendar.kinds.EARLY_CLOSE": "조기 마감 {{time}}", "calendar.kinds.LATE_OPEN": "개장 지연 {{time}}",
    "calendar.legendToday": "오늘", "calendar.listDate": "{{date}} ({{weekday}})",
    "calendar.missing": "{{market}} {{year}}년 휴장 정보가 아직 없습니다",
    "calendar.cellDate": "{{month}} {{day}}일",
  ]
  return L10n.fill(ko[key] ?? key, values)
}

private func calendar(missing: [(CalendarMarket, Int)] = []) -> MarketCalendar {
  let exceptions: [[String: Any]] = [
    [
      "market": "CME", "date": "2026-11-26", "kind": "HALT", "at": "13:30",
      "note": "Thanksgiving Day",
    ],
    [
      "market": "NYSE", "date": "2026-11-26", "kind": "CLOSED", "at": NSNull(),
      "note": "Thanksgiving Day",
    ],
    [
      "market": "NYSE", "date": "2026-11-27", "kind": "EARLY_CLOSE", "at": "13:00",
      "note": "Day after Thanksgiving",
    ],
    [
      "market": "CME", "date": "2026-11-27", "kind": "EARLY_CLOSE", "at": "13:45",
      "note": "Day after Thanksgiving",
    ],
    ["market": "KRX", "date": "2026-12-31", "kind": "CLOSED", "at": NSNull(), "note": "연말 휴장"],
    ["market": "KRX", "date": "2027-01-04", "kind": "LATE_OPEN", "at": "10:00", "note": "연초 개장식"],
  ]
  let json: [String: Any] = [
    "from": "2026-10-31", "to": "2027-02-01", "exceptions": exceptions,
    "missing": missing.map { ["market": $0.0.rawValue, "year": $0.1] },
  ]
  let data = try! JSONSerialization.data(withJSONObject: json)
  return try! JSONDecoder().decode(MarketCalendar.self, from: data)
}

// RN `CalendarScreen.test.tsx`와 같은 경우. 기기 시간대는 서울로 고정한다
@MainActor
struct CalendarScreenModelTests {
  /// 2026-11-21 09:00 KST
  private static let now = Date(timeIntervalSince1970: 1_795_219_200)
  private static let seoul = TimeZone(identifier: "Asia/Seoul")!

  private func loaded(_ response: MarketCalendar) async -> (
    CalendarScreenModel, CalendarSchedule, FakeCalendarRepository
  ) {
    let repository = FakeCalendarRepository(response)
    let cache = QueryCache()
    let model = CalendarScreenModel(now: Self.now, timeZone: Self.seoul) {
      cache.marketCalendar(repository, query: $0)
    }
    await model.query.refetch()
    return (model, model.schedule(model.query.state.data!), repository)
  }

  @Test func fetchesThreeMonthsWidenedByOneDay() async {
    let (model, _, repository) = await loaded(calendar())
    #expect(model.today == LocalDate("2026-11-21"))
    #expect(
      model.months.map { CalendarText.monthTitle($0, t: t) } == [
        "2026년 11월", "2026년 12월", "2027년 1월",
      ])
    let query = repository.queries.withLock { $0.first }
    #expect(query?.from == LocalDate("2026-10-31"))
    #expect(query?.to == LocalDate("2027-02-01"))
  }

  @Test func cellsShowLocalDatesAndTimes() async {
    let (model, schedule, _) = await loaded(calendar())
    let label = { (date: String) in
      let day = LocalDate(date)!
      return CalendarText.cellLabel(
        day, isToday: day == model.today, exceptions: schedule.byDate[day] ?? [], t: t)
    }
    #expect(label("2026-11-21") == "11월 21일, 오늘")
    #expect(label("2026-11-26") == "11월 26일, NYSE 휴장")
    #expect(label("2026-11-27") == "11월 27일, CME 휴장 (04:30 거래 중단)")
    #expect(label("2026-11-28") == "11월 28일, NYSE 조기 마감 03:00, CME 조기 마감 04:45")
    #expect(label("2026-11-20") == "11월 20일")
    #expect(schedule.byDate[LocalDate("2026-11-26")!]?.map(\.isClosed) == [true])
    #expect(schedule.byDate[LocalDate("2026-11-28")!]?.map(\.isClosed) == [false, false])
  }

  @Test func monthListsInLocalTimeOrder() async {
    let (model, schedule, _) = await loaded(calendar())
    let nov = schedule.items(in: model.months[0])
    #expect(
      nov.map { CalendarText.listDate($0.localDate, t: t) }
        == ["11/26 (목)", "11/27 (금)", "11/28 (토)", "11/28 (토)"])
    #expect(nov.suffix(2).map { CalendarText.kind($0, t: t) } == ["조기 마감 03:00", "조기 마감 04:45"])
    let jan = schedule.items(in: model.months[2])
    #expect(jan.map { CalendarText.kind($0, t: t) } == ["개장 지연 10:00"])
  }

  @Test func hidesMissingYearsOutsideThreeMonths() async {
    let (_, schedule, _) = await loaded(
      calendar(missing: [(.nyse, 2026), (.krx, 2025), (.krx, 2027)]))
    #expect(
      schedule.missing.map { CalendarText.missing($0, t: t) } == [
        "NYSE 2026년 휴장 정보가 아직 없습니다", "KRX 2027년 휴장 정보가 아직 없습니다",
      ])
  }
}
