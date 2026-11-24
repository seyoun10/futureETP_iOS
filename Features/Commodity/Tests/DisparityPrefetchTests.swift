import Core
import Synchronization
import Testing

@testable import Commodity

private let settings = AppSettings(
  locale: .ko, timezone: "Asia/Seoul", basis: .front, maPeriod: .days50, window: .years5,
  rareLevels: [1, 2.5, 5, 10, 20], alertCommodity: .gc, quietTime: nil)

struct TestError: Error {}

/// 설정 조회 횟수를 세고, `fails`면 실패한다
final class SettingsStub: SettingsRepository {
  let fetches = Mutex(0)
  let fails: Bool
  let value: AppSettings

  @MainActor init(fails: Bool = false) {
    self.fails = fails
    value = settings
  }

  func fetch() async throws -> AppSettings {
    fetches.withLock { $0 += 1 }
    if fails { throw TestError() }
    return value
  }

  func update(_ patch: SettingsPatch) async throws -> AppSettings { value }
}

/// C-a 요청을 기록하고 실패한다(미리 조회는 실패를 무시한다)
final class DisparityStub: DisparityRepository {
  let requests = Mutex<[DisparityQuery]>([])

  func fetchDisparity(_ code: CommodityCode, query: DisparityQuery) async throws -> DisparityChart {
    requests.withLock { $0.append(query) }
    throw TestError()
  }
}

// RN `prefetchDisparityChart` 경우
@MainActor
struct DisparityPrefetchTests {
  let cache = QueryCache()
  let disparity = DisparityStub()

  private var queries: CommodityQueries {
    let cache = cache
    let disparity = disparity
    return CommodityQueries(
      disparity: { cache.disparityChart(disparity, code: $0, query: $1) },
      contracts: { _ in fatalError() }, curve: { _, _ in fatalError() },
      etps: { _ in fatalError() })
  }

  private var expected: DisparityQuery {
    DisparityQuery(
      basis: .front, maPeriod: .days50, window: .years5, levels: RareLevels([1, 2.5, 5, 10, 20])!)
  }

  @Test func fetchesTheSettingsFirstThenTheChartWithTheirValues() async {
    let repository = SettingsStub()
    let store = SettingsStore(repository: repository, cache: cache)
    await queries.prefetchDisparity(.gc, settings: store)
    #expect(repository.fetches.withLock { $0 } == 1)
    #expect(disparity.requests.withLock { $0 } == [expected])
  }

  @Test func usesCachedSettingsWithoutFetchingThemAgain() async {
    let repository = SettingsStub()
    let store = SettingsStore(repository: repository, cache: cache)
    await store.query.refetch()
    store.query.invalidate()
    await queries.prefetchDisparity(.gc, settings: store)
    #expect(repository.fetches.withLock { $0 } == 1)
    #expect(disparity.requests.withLock { $0 }.count == 1)
  }

  @Test func skipsTheChartWhenTheSettingsFail() async {
    let store = SettingsStore(repository: SettingsStub(fails: true), cache: cache)
    await queries.prefetchDisparity(.gc, settings: store)
    #expect(disparity.requests.withLock { $0 }.isEmpty)
  }

  @Test func theTabJoinsThePrefetchedQuery() async {
    let store = SettingsStore(repository: SettingsStub(), cache: cache)
    await queries.prefetchDisparity(.gc, settings: store)
    // C-a 화면이 같은 키로 만든 조회는 미리 조회한 캐시 항목이다
    let prefetched = queries.disparity(.gc, expected).query
    #expect(prefetched.state.error != nil)
    #expect(prefetched === cache.disparityChart(disparity, code: .gc, query: expected).query)
  }
}
