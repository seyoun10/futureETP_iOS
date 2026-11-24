import Core
import Foundation

/// 기기 로컬 날짜·시각으로 옮긴 예외 일정 (D-144)
struct LocalCalendarException: Equatable, Identifiable {
  let exception: CalendarException
  /// 기기 로컬 날짜
  let localDate: LocalDate
  /// 기기 로컬 `HH:mm`. 시각이 없는 휴장은 nil
  let localTime: String?
  /// 정렬 기준 시각. `at`, 휴장은 정규 개장 시각
  let instant: Date

  var market: CalendarMarket { exception.market }
  var kind: CalendarExceptionKind { exception.kind }
  var id: String { "\(exception.market.rawValue)-\(exception.date)" }
  /// 채운 점: 휴장과 CME 공휴일 중간 정지(정산 없음). 빈 점: 조기 마감·개장 지연
  var isClosed: Bool { kind == .closed || kind == .halt }
}

/// 휴장 달력의 예외 일정(시장 현지 날짜·시각)을 기기 로컬 날짜·시각으로 옮긴다 (D-144, RN `localSchedule.ts`).
/// 시각이 있는 일정은 그 시각을, 휴장(CLOSED)은 그 시장 정규 개장 시각을 로컬로 바꾼 날짜에 둔다
enum LocalSchedule {
  static func timeZone(_ market: CalendarMarket) -> TimeZone {
    switch market {
    case .cme: TimeZone(identifier: "America/Chicago")!
    case .krx: TimeZone(identifier: "Asia/Seoul")!
    case .nyse: TimeZone(identifier: "America/New_York")!
    }
  }

  /// 정규 개장 시각. CME 거래일 세션은 전날 17:00 CT에 열린다 (D-061)
  static func regularOpen(_ market: CalendarMarket) -> (dayOffset: Int, hour: Int, minute: Int) {
    switch market {
    case .cme: (-1, 17, 0)
    case .krx: (0, 9, 0)
    case .nyse: (0, 9, 30)
    }
  }

  /// `timeZone`의 벽시계 날짜·시각 → 시각. 서머타임 경계도 Foundation이 맞춘다
  static func instant(_ date: LocalDate, hour: Int, minute: Int, timeZone: TimeZone) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.date(
      from: DateComponents(
        year: date.year, month: date.month, day: date.day, hour: hour, minute: minute))!
  }

  static func local(_ exception: CalendarException, timeZone: TimeZone)
    -> LocalCalendarException
  {
    let marketZone = Self.timeZone(exception.market)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let instant: Date
    let hasTime: Bool
    if let at = exception.at, let (hour, minute) = parse(at) {
      instant = Self.instant(exception.date, hour: hour, minute: minute, timeZone: marketZone)
      hasTime = true
    } else {
      let open = regularOpen(exception.market)
      instant = Self.instant(
        exception.date.adding(days: open.dayOffset), hour: open.hour, minute: open.minute,
        timeZone: marketZone)
      hasTime = false
    }
    let parts = calendar.dateComponents([.hour, .minute], from: instant)
    return LocalCalendarException(
      exception: exception,
      localDate: MonthGrid.localDate(instant, timeZone: timeZone),
      localTime: hasTime ? String(format: "%02d:%02d", parts.hour!, parts.minute!) : nil,
      instant: instant)
  }

  /// 로컬 시각순(휴장은 정규 개장 시각), 같은 시각은 시장 순
  static func local(_ exceptions: [CalendarException], timeZone: TimeZone)
    -> [LocalCalendarException]
  {
    exceptions.map { local($0, timeZone: timeZone) }.sorted {
      ($0.instant, marketOrder($0.market)) < ($1.instant, marketOrder($1.market))
    }
  }

  /// 로컬 날짜로 옮기면 시장 날짜가 하루 앞뒤로 움직이므로 조회 범위를 하루씩 넓힌다
  static func widen(_ range: (from: LocalDate, to: LocalDate)) -> (from: LocalDate, to: LocalDate) {
    (range.from.adding(days: -1), range.to.adding(days: 1))
  }

  private static func marketOrder(_ market: CalendarMarket) -> Int {
    CalendarMarket.allCases.firstIndex(of: market)!
  }

  private static func parse(_ at: String) -> (Int, Int)? {
    let parts = at.split(separator: ":")
    guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
    return (hour, minute)
  }
}
