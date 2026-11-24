import Foundation

/// A-a 휴장 달력 `GET /v1/calendar?from&to` (D-143)
public protocol CalendarRepository: Sendable {
  func fetchCalendar(_ query: CalendarQuery) async throws -> MarketCalendar
}

public struct LiveCalendarRepository: CalendarRepository {
  private let client: APIClient

  public init(client: APIClient) {
    self.client = client
  }

  public func fetchCalendar(_ query: CalendarQuery) async throws -> MarketCalendar {
    try await client.send(
      APIRequest("/calendar", query: query.queryItems, as: MarketCalendar.self))
  }
}

extension QueryCache {
  /// 휴장 일정은 연 몇 번만 바뀌므로 12시간 동안 다시 받지 않는다 (RN `useMarketCalendar`)
  nonisolated public static let calendarStaleTime: TimeInterval = 12 * 60 * 60
  /// 입력되지 않은 (시장, 연도)가 있으면 곧 import될 수 있어 5분만 새것으로 본다.
  /// 빈 달력을 12시간 붙잡으면 서버에 import한 뒤에도 앱을 다시 켜야 보인다
  nonisolated public static let calendarMissingStaleTime: TimeInterval = 5 * 60

  /// A-a 조회 (RN `useMarketCalendar`). 범위(`from`·`to`)가 키다
  public func marketCalendar(_ repository: any CalendarRepository, query: CalendarQuery)
    -> Query<MarketCalendar>
  {
    self.query(
      QueryKeys.calendar(query),
      stalePolicy: .after {
        $0.missing.isEmpty ? Self.calendarStaleTime : Self.calendarMissingStaleTime
      },
      fetch: { try await repository.fetchCalendar(query) })
  }
}
