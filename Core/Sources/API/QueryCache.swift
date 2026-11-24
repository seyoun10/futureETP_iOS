import Foundation

/// 키를 넣어 조회를 찾는 앱 하나의 메모리 캐시 (RN `QueryClient`, D-030). 기기에 저장하지 않는다.
/// 키는 경로처럼 앞에서부터 묶는다(`["commodities", "GC", "disparity", …]`). 앞부분으로 한꺼번에 무효화한다
@MainActor
public final class QueryCache {
  /// 보는 화면이 없어진 뒤 캐시에 두는 시간. TanStack Query 기본 `gcTime` 5분
  nonisolated public static let defaultKeepFor: TimeInterval = 5 * 60
  /// C 차트는 응답이 크고 첫 조회·그리기가 느려 1시간 둔다 (RN `CHART_GC_TIME_MS`)
  nonisolated public static let chartKeepFor: TimeInterval = 60 * 60

  private var entries: [[String]: any CachedQuery] = [:]
  private let now: @Sendable () -> Date

  public init(now: @escaping @Sendable () -> Date = { Date() }) {
    self.now = now
  }

  /// `key`의 조회. 없거나 만료됐으면 새로 만든다(조회는 아직 하지 않는다)
  public func query<Value: Sendable>(
    _ key: [String],
    keepFor: TimeInterval = defaultKeepFor,
    stalePolicy: StalePolicy = .immediately,
    freshness: @escaping @Sendable (Value) -> Freshness? = { _ in nil },
    fetch: @escaping @Sendable () async throws -> Value
  ) -> Query<Value> {
    removeExpired()
    if let query = entries[key] as? Query<Value> { return query }
    let query = Query(
      key: key, keepFor: keepFor, stalePolicy: stalePolicy, freshness: freshness, now: now,
      fetch: fetch)
    entries[key] = query
    return query
  }

  /// `prefix`로 시작하는 조회를 무효화한다. 비우면 전부(접근 키 저장 뒤, D-044)
  public func invalidate(prefix: [String] = []) {
    for (key, query) in entries where key.starts(with: prefix) {
      query.invalidate()
    }
  }

  var count: Int { entries.count }

  private func removeExpired() {
    let date = now()
    entries = entries.filter { !$0.value.isExpired(at: date) }
  }
}

/// 값 타입이 다른 조회를 한 사전에 담는다
@MainActor
protocol CachedQuery: AnyObject {
  func invalidate()
  func isExpired(at date: Date) -> Bool
}

extension Query: CachedQuery {}
