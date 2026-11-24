import Core
import Foundation
import Testing

@MainActor
struct CommoditiesRepositoryTests {
  private func repository() throws -> LiveCommoditiesRepository {
    let url = try #require(Bundle.module.url(forResource: "commodities", withExtension: "json"))
    let body = try Data(contentsOf: url)
    let client = APIClient(
      baseURL: URL(string: "http://localhost:3000")!,
      accessToken: { "token" },
      deviceID: { "device" },
      transport: { request in
        #expect(request.url?.absoluteString == "http://localhost:3000/v1/commodities")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        let response = HTTPURLResponse(
          url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, response)
      },
      retryDelay: { _ in .zero }
    )
    return LiveCommoditiesRepository(client: client)
  }

  @Test func fetchesListWithAuth() async throws {
    let data = try await repository().fetchList()
    #expect(data.commodities.map(\.code).contains(.gc))
  }

  @Test func listQueryRefreshesAfterNextUpdate() async throws {
    let cache = QueryCache()
    let query = cache.commodityList(try repository())
    #expect(query === cache.commodityList(try repository()))
    await query.refetch()
    let nextUpdateAt = try #require(query.state.data?.freshness.nextUpdateAt)
    // 마지막 조회 1분 뒤보다 늦으면 nextUpdateAt + 1분이다
    let expected = AutoRefresh.date(nextUpdateAt: nextUpdateAt, lastFetchedAt: query.dataUpdatedAt)
    #expect(query.nextAutoRefreshAt == expected)
    // 진입할 때마다 다시 조회한다
    #expect(query.isStale)
  }
}
