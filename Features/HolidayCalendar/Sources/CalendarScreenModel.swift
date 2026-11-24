import Core
import Foundation
import Observation

/// A-a 휴장 달력 화면 상태 (screens.md A-a, RN `CalendarScreen`). 이번 달~다다음 달을 보여 준다.
/// 오늘·일정 모두 기기 로컬 날짜·시각이다(D-144). 화면을 여는 동안 날짜가 바뀌어도 다시 열 때까지 그대로 둔다
@MainActor @Observable
public final class CalendarScreenModel {
  static let monthCount = 3

  let today: LocalDate
  let months: [CalendarMonth]
  let query: Query<MarketCalendar>
  @ObservationIgnored private let timeZone: TimeZone
  /// 화면 3개월이 걸친 연도. 넓혀 받은 하루 때문에 생긴 그 밖 연도의 미입력은 안내하지 않는다
  @ObservationIgnored private let years: ClosedRange<Int>

  /// - Parameter makeQuery: 조회 범위의 캐시 조회
  public init(
    now: Date = Date(), timeZone: TimeZone = .current,
    query makeQuery: (CalendarQuery) -> Query<MarketCalendar>
  ) {
    let today = MonthGrid.localDate(now, timeZone: timeZone)
    let months = MonthGrid.months(from: today, count: Self.monthCount)
    let range = MonthGrid.range(months)!
    // 로컬로 옮기면 시장 날짜가 하루 앞뒤로 움직이므로 하루씩 넓혀 받는다
    let wide = LocalSchedule.widen(range)
    self.today = today
    self.months = months
    self.timeZone = timeZone
    years = range.from.year...range.to.year
    query = makeQuery(CalendarQuery(from: wide.from, to: wide.to)!)
  }

  func schedule(_ data: MarketCalendar) -> CalendarSchedule {
    CalendarSchedule(data: data, years: years, timeZone: timeZone)
  }
}

/// 받은 일정을 기기 로컬 날짜 칸으로 나눈 것
struct CalendarSchedule {
  /// 로컬 시각순
  let exceptions: [LocalCalendarException]
  let byDate: [LocalDate: [LocalCalendarException]]
  let missing: [CalendarMissingYear]

  init(data: MarketCalendar, years: ClosedRange<Int>, timeZone: TimeZone) {
    exceptions = LocalSchedule.local(data.exceptions, timeZone: timeZone)
    byDate = Dictionary(grouping: exceptions, by: \.localDate)
    missing = data.missing.filter { years.contains($0.year) }
  }

  /// 그 달 목록. 로컬 시각순
  func items(in month: CalendarMonth) -> [LocalCalendarException] {
    exceptions.filter { $0.localDate.year == month.year && $0.localDate.month == month.month }
  }
}
