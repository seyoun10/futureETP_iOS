import Core
import Foundation
import Synchronization
import Testing

@MainActor
struct CurveRepositoryTests {
  private static func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
  }

  @Test func fetchesCurveByBaseDateIntoSeparateEntries() async throws {
    let latest = try Self.fixture("curve")
    let older = try Self.fixture("curve.baseDate")
    let requested = Mutex<[String?]>([])
    let client = APIClient(
      baseURL: URL(string: "http://localhost:3000")!,
      accessToken: { "token" },
      deviceID: { "device" },
      transport: { request in
        let components = try #require(
          URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        #expect(components.path == "/v1/commodities/CL/curve")
        let baseDate = components.queryItems?.first { $0.name == "baseDate" }?.value
        requested.withLock { $0.append(baseDate) }
        let response = HTTPURLResponse(
          url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (baseDate == nil ? latest : older, response)
      },
      retryDelay: { _ in .zero }
    )
    let repository = LiveCommoditiesRepository(client: client)
    let cache = QueryCache()
    let date = LocalDate(year: 2020, month: 4, day: 20)!

    let current = cache.curve(repository, code: .cl, baseDate: nil)
    #expect(current === cache.curve(repository, code: .cl, baseDate: nil))
    let past = cache.curve(repository, code: .cl, baseDate: date)
    #expect(current !== past)

    await current.refetch()
    await past.refetch()
    #expect(requested.withLock { $0 } == [nil, "2020-04-20"])
    #expect(past.state.data?.baseDate == date)
    #expect(past.state.data?.prevBaseDate == LocalDate(year: 2020, month: 4, day: 17))
    #expect(current.state.data != nil)
  }

  @Test func curveKeyStartsWithCommodity() {
    #expect(QueryKeys.curve(.cl, baseDate: nil) == ["commodities", "CL", "curve", "latest"])
    #expect(
      QueryKeys.curve(.cl, baseDate: LocalDate(year: 2020, month: 4, day: 20))
        == ["commodities", "CL", "curve", "2020-04-20"])
  }
}
