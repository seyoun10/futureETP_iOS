import Core
import Foundation
import Testing

/// `before` 쿼리마다 응답을 고르는 C-a 서버 흉내
private final class DisparityServer: @unchecked Sendable {
  private let lock = NSLock()
  private var _requests: [String?] = []
  /// 이전 3년 요청을 실패시킨다
  var failsOlder = false
  /// 이전 3년 응답 지연
  var olderDelay: Duration = .zero

  var requests: [String?] { lock.withLock { _requests } }

  func client() throws -> APIClient {
    let latest = try Self.fixture("disparityChart")
    let older = try Self.fixture("disparityChart.before")
    return APIClient(
      baseURL: URL(string: "http://localhost:3000")!,
      accessToken: { "token" },
      deviceID: { "device" },
      transport: { [self] request in
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        #expect(components.path == "/v1/commodities/GC/disparity")
        let before = components.queryItems?.first { $0.name == "before" }?.value
        lock.withLock { _requests.append(before) }
        if before != nil {
          if olderDelay > .zero { try await Task.sleep(for: olderDelay) }
          if failsOlder { throw URLError(.notConnectedToInternet) }
        }
        let response = HTTPURLResponse(
          url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (before == nil ? latest : older, response)
      },
      retryDelay: { _ in .zero }
    )
  }

  private static func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
  }
}

private let params = DisparityQuery(
  basis: .kr, maPeriod: .days200, window: .years10, levels: RareLevels([1, 2.5, 5, 10, 20])!)

@MainActor
struct ChartPagesTests {
  private func paged(_ server: DisparityServer, cache: QueryCache = QueryCache()) throws
    -> PagedQuery<DisparityChart>
  {
    cache.disparityChart(
      LiveCommoditiesRepository(client: try server.client()), code: .gc, query: params)
  }

  @Test func keyFollowsSettingsAndIgnoresBefore() throws {
    let cache = QueryCache()
    let server = DisparityServer()
    let a = try paged(server, cache: cache)
    var older = params
    older.before = LocalDate(year: 2020, month: 1, day: 2)
    let b = cache.disparityChart(
      LiveCommoditiesRepository(client: try server.client()), code: .gc, query: older)
    #expect(a.query === b.query)
    var other = params
    other.maPeriod = .days50
    let c = cache.disparityChart(
      LiveCommoditiesRepository(client: try server.client()), code: .gc, query: other)
    #expect(a.query !== c.query)
    #expect(QueryKeys.disparity(.gc, query: params).starts(with: QueryKeys.commodity(.gc)))
  }

  @Test func fetchOlderPrependsEarlierBars() async throws {
    let server = DisparityServer()
    let paged = try paged(server)
    await paged.query.refetch()
    #expect(paged.hasOlder)
    let error = await paged.fetchOlder()
    #expect(error == nil)
    let pages = try #require(paged.query.state.data)
    #expect(pages.pages.count == 2)
    #expect(server.requests == [nil, "2023-10-27"])
    let bars = pages.joined(\.bars)
    #expect(bars.count == 1512)
    #expect(bars.first?.tradeDate == pages.pages[1].bars.first?.tradeDate)
    #expect(bars.last?.tradeDate == pages.latest.bars.last?.tradeDate)
    // 봉 밖 값은 최근 페이지, hasMore는 가장 이른 페이지
    #expect(pages.latest.basis == .front)
    #expect(pages.nextBefore == LocalDate(year: 2014, month: 12, day: 31))
  }

  @Test func refetchReloadsAsManyPagesAsLoaded() async throws {
    let server = DisparityServer()
    let paged = try paged(server)
    await paged.query.refetch()
    await paged.fetchOlder()
    await paged.query.refetch()
    #expect(server.requests == [nil, "2023-10-27", nil, "2023-10-27"])
    #expect(paged.query.state.data?.pages.count == 2)
  }

  @Test func olderFailureKeepsDataWithoutQueryError() async throws {
    let server = DisparityServer()
    server.failsOlder = true
    let paged = try paged(server)
    await paged.query.refetch()
    let error = await paged.fetchOlder()
    #expect(error?.code == .network)
    #expect(paged.query.state.error == nil)
    #expect(paged.query.state.data?.pages.count == 1)
  }

  @Test func lateOlderResponseStillAppends() async throws {
    let server = DisparityServer()
    server.olderDelay = .milliseconds(50)
    let paged = try paged(server)
    await paged.query.refetch()
    // 화면이 기다리기를 그만둬도(시간 초과) 받은 값은 붙는다 (D-139)
    let task = Task { await paged.fetchOlder() }
    _ = task
    #expect(paged.query.state.data?.pages.count == 1)
    for _ in 0..<200 where paged.query.state.data?.pages.count == 1 {
      try await Task.sleep(for: .milliseconds(5))
    }
    #expect(paged.query.state.data?.pages.count == 2)
  }

  @Test func staleUntilNextUpdate() async throws {
    let paged = try paged(DisparityServer())
    #expect(paged.query.isStale)
    await paged.query.refetch()
    // 픽스처 nextUpdateAt은 지난 시각이라 바로 오래된 값이다
    let nextUpdateAt = paged.query.state.data?.latest.freshness.nextUpdateAt
    #expect(paged.query.isStale == (nextUpdateAt.map { $0 <= Date() } ?? true))
  }
}
