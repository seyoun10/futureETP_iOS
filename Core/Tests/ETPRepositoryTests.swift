import Core
import Foundation
import Synchronization
import Testing

@MainActor
struct ETPRepositoryTests {
  private static func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
  }

  @Test func fetchesListAndDetail() async throws {
    let list = try Self.fixture("etpList")
    let detail = try Self.fixture("etpDetail")
    let paths = Mutex<[String]>([])
    let client = APIClient(
      baseURL: URL(string: "http://localhost:3000")!,
      accessToken: { "token" },
      deviceID: { "device" },
      transport: { request in
        let path = request.url!.path
        paths.withLock { $0.append(path) }
        let response = HTTPURLResponse(
          url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (path.hasPrefix("/v1/etps/") ? detail : list, response)
      },
      retryDelay: { _ in .zero }
    )
    let repository = LiveCommoditiesRepository(client: client)
    let cache = QueryCache()

    let etps = cache.etpList(repository, code: .gc)
    #expect(etps === cache.etpList(repository, code: .gc))
    await etps.refetch()
    let first = try #require(etps.state.data?.etps.first)

    let etp = cache.etpDetail(repository, id: first.id)
    await etp.refetch()
    #expect(etp.state.data != nil)
    #expect(
      paths.withLock { $0 }
        == ["/v1/commodities/GC/etps", "/v1/etps/\(first.id.uuidString.lowercased())"])
  }

  @Test func keys() {
    let id = UUID(uuidString: "9D468AF9-3A01-4B91-9C08-63A5EE7A511A")!
    #expect(QueryKeys.etps(.gc) == ["commodities", "GC", "etps"])
    #expect(QueryKeys.etp(id) == ["etps", "9d468af9-3a01-4b91-9c08-63a5ee7a511a"])
  }
}
