import Core
import Foundation
import Synchronization
import Testing

@MainActor
struct CalendarRepositoryTests {
  private static let base = Date(timeIntervalSince1970: 1_795_000_000)
  private static let range = CalendarQuery(
    from: LocalDate("2026-10-31")!, to: LocalDate("2027-02-01")!)!

  private static func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
  }

  /// 요청 URL 기록
  private final class URLLog: Sendable {
    let urls = Mutex<[URL]>([])
  }

  /// `name` 예시를 돌려주는 저장소와 요청 URL 기록
  private static func repository(_ name: String) throws -> (LiveCalendarRepository, URLLog) {
    let body = try fixture(name)
    let log = URLLog()
    let client = APIClient(
      baseURL: URL(string: "http://localhost:3000")!,
      accessToken: { "token" },
      deviceID: { "device" },
      transport: { request in
        log.urls.withLock { $0.append(request.url!) }
        let response = HTTPURLResponse(
          url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, response)
      },
      retryDelay: { _ in .zero }
    )
    return (LiveCalendarRepository(client: client), log)
  }

  @Test func fetchesRange() async throws {
    let (repository, log) = try Self.repository("calendar")
    let cache = QueryCache()
    let query = cache.marketCalendar(repository, query: Self.range)
    #expect(query === cache.marketCalendar(repository, query: Self.range))
    await query.refetch()
    #expect(query.state.data?.exceptions.isEmpty == false)
    let url = try #require(log.urls.withLock { $0.first })
    #expect(url.path == "/v1/calendar")
    #expect(url.query == "from=2026-10-31&to=2027-02-01")
    #expect(QueryKeys.calendar(Self.range) == ["calendar", "2026-10-31", "2027-02-01"])
  }

  @Test(arguments: [
    ("calendar", QueryCache.calendarStaleTime),
    ("calendar.missing", QueryCache.calendarMissingStaleTime),
  ])
  func staleTimeDependsOnMissing(_ name: String, _ staleTime: TimeInterval) async throws {
    let (repository, log) = try Self.repository(name)
    let now = Mutex(Self.base)
    let cache = QueryCache(now: { now.withLock { $0 } })
    let query = cache.marketCalendar(repository, query: Self.range)
    await query.refetch()

    now.withLock { $0 = Self.base.addingTimeInterval(staleTime - 1) }
    await query.fetchIfStale()
    #expect(log.urls.withLock { $0.count } == 1)
    now.withLock { $0 = Self.base.addingTimeInterval(staleTime) }
    await query.fetchIfStale()
    #expect(log.urls.withLock { $0.count } == 2)
  }
}
