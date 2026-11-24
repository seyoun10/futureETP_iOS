import Core
import Foundation
import Synchronization
import Testing

@MainActor
struct ContractsChartPagesTests {
  private static func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
  }

  private func page(_ dates: [LocalDate], _ contracts: [ContractLine], hasMore: Bool)
    -> ContractsChart
  {
    ContractsChart(
      freshness: Freshness(
        asOf: Date(timeIntervalSince1970: 0),
        tradeDate: dates.last
          ?? LocalDate(year: 2026, month: 10, day: 22)!, delayed: true, marketState: .open,
        nextUpdateAt: nil),
      priceDecimals: 3, dates: dates, hasMore: hasMore, provisional: false, contracts: contracts)
  }

  private func line(_ symbol: String, month: Int, front: Bool = false, _ prices: [Double?])
    -> ContractLine
  {
    ContractLine(
      symbol: symbol, contractMonth: ContractMonth(year: 2026, month: month)!,
      lastTradeDate: LocalDate(year: 2026, month: month - 1, day: 25)!, isFront: front,
      prices: prices)
  }

  @Test func mergePrependsOlderPagesAndFillsMissingContracts() {
    let d = (1...4).map { LocalDate(year: 2026, month: 1, day: $0)! }
    let latest = page(
      [d[2], d[3]],
      [line("NGZ26", month: 12, front: true, [3, 4]), line("NGF27", month: 11, [nil, 5])],
      hasMore: true)
    let older = page(
      [d[0], d[1]], [line("NGZ26", month: 12, front: true, [1, 2])], hasMore: false)
    let merged = ChartPages([latest, older]).merged
    #expect(merged.dates == d)
    #expect(merged.contracts.map(\.prices) == [[1, 2, 3, 4], [nil, nil, nil, 5]])
    #expect(merged.hasMore == false)
  }

  @Test func mergeOfSinglePageIsThePage() {
    let only = page([LocalDate(year: 2026, month: 1, day: 1)!], [], hasMore: false)
    #expect(ChartPages([only]).merged == only)
  }

  @Test func fetchesContractsAndOlderPage() async throws {
    let latest = try Self.fixture("contractsChart")
    let older = try Self.fixture("contractsChart.before")
    let requests = Mutex<[String?]>([])
    let client = APIClient(
      baseURL: URL(string: "http://localhost:3000")!,
      accessToken: { "token" },
      deviceID: { "device" },
      transport: { request in
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        #expect(components.path == "/v1/commodities/GC/contracts")
        let before = components.queryItems?.first { $0.name == "before" }?.value
        requests.withLock { $0.append(before) }
        let response = HTTPURLResponse(
          url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (before == nil ? latest : older, response)
      },
      retryDelay: { _ in .zero }
    )
    let cache = QueryCache()
    let repository = LiveCommoditiesRepository(client: client)
    let paged = cache.contractsChart(repository, code: .gc)
    #expect(paged.query === cache.contractsChart(repository, code: .gc).query)
    await paged.query.refetch()
    #expect(paged.hasOlder)
    #expect(await paged.fetchOlder() == nil)
    #expect(requests.withLock { $0 } == [nil, "2023-10-27"])
    let merged = try #require(paged.query.state.data).merged
    #expect(merged.dates.count == 756 + 640)
    #expect(merged.contracts.allSatisfy { $0.prices.count == merged.dates.count })
    #expect(!paged.hasOlder)
  }
}
