import Foundation
import Testing

@testable import Core

private let base = Date(timeIntervalSince1970: 1_792_677_600)  // 2026-10-22T14:00:00Z
private let minute: TimeInterval = 60

/// 테스트가 움직이는 시계와 조회 횟수
private final class Fixture: @unchecked Sendable {
  private let lock = NSLock()
  private var _now = base
  private var _calls = 0

  var now: Date {
    get { lock.withLock { _now } }
    set { lock.withLock { _now = newValue } }
  }
  var calls: Int { lock.withLock { _calls } }
  func countCall() { lock.withLock { _calls += 1 } }
}

private struct Payload: Sendable, Equatable {
  let value: Int
  var nextUpdateAt: Date? = nil

  var freshness: Freshness {
    Freshness(
      asOf: base, tradeDate: LocalDate(year: 2026, month: 10, day: 22)!, delayed: true,
      marketState: .open, nextUpdateAt: nextUpdateAt)
  }
}

@MainActor
private func makeQuery(
  _ fixture: Fixture, cache: QueryCache? = nil, key: [String] = ["a"],
  stalePolicy: StalePolicy = .immediately, delay: Duration = .zero,
  result: @escaping @Sendable (Int) throws -> Payload = { Payload(value: $0) }
) -> Query<Payload> {
  let cache = cache ?? QueryCache(now: { fixture.now })
  return cache.query(
    key, stalePolicy: stalePolicy, freshness: { $0.freshness },
    fetch: {
      fixture.countCall()
      if delay > .zero { try await Task.sleep(for: delay) }
      return try result(fixture.calls)
    })
}

/// 기다리지 않고 시작한 조회가 끝날 때까지 양보한다
@MainActor
private func waitUntil(_ condition: () -> Bool) async {
  for _ in 0..<1000 where !condition() { await Task.yield() }
}

// RN `useAutoRefresh.test.tsx`와 같은 경우
@Suite struct AutoRefreshTests {
  @Test func runsOneMinuteAfterNextUpdate() {
    let date = AutoRefresh.date(nextUpdateAt: base + 5 * minute, lastFetchedAt: base)
    #expect(date == base + 6 * minute)
  }

  @Test func runsOneMinuteAfterLastFetchWhenNextUpdatePassed() {
    let date = AutoRefresh.date(nextUpdateAt: base - 60 * minute, lastFetchedAt: base)
    #expect(date == base + minute)
  }

  @Test func runsNowWhenLastFetchIsOld() {
    let date = AutoRefresh.date(nextUpdateAt: base - 60 * minute, lastFetchedAt: base - 30 * minute)
    #expect(date! <= base)
  }

  @Test func doesNotRunWithoutNextUpdate() {
    #expect(AutoRefresh.date(nextUpdateAt: nil, lastFetchedAt: base) == nil)
  }
}

@MainActor @Suite struct QueryTests {
  @Test func refetchStoresDataAndTime() async {
    let fixture = Fixture()
    let query = makeQuery(fixture)
    await query.refetch()
    #expect(query.state.data == Payload(value: 1))
    #expect(query.state.isFetching == false)
    #expect(query.dataUpdatedAt == base)
  }

  @Test func failedRefreshKeepsData() async {
    let fixture = Fixture()
    let query = makeQuery(fixture) { call in
      if call > 1 { throw AppError(.timeout) }
      return Payload(value: call)
    }
    await query.refetch()
    fixture.now = base + minute
    await query.refetch()
    #expect(query.state.data == Payload(value: 1))
    #expect(query.state.error == AppError(.timeout))
    #expect(query.errorUpdatedAt == base + minute)
    guard case .content = query.state.phase else {
      Issue.record("데이터가 있으면 내용을 보인다")
      return
    }
  }

  @Test func nonAppErrorBecomesInternal() async {
    struct Other: Error {}
    let query = makeQuery(Fixture()) { _ in throw Other() }
    await query.refetch()
    #expect(query.state.error?.code == .internal)
  }

  @Test func concurrentRefetchJoinsTheRunningFetch() async {
    let fixture = Fixture()
    let query = makeQuery(fixture, delay: .milliseconds(50))
    async let first: Void = query.refetch()
    async let second: Void = query.refetch()
    _ = await (first, second)
    #expect(fixture.calls == 1)
  }

  @Test func immediatelyStaleAfterFetch() async {
    let query = makeQuery(Fixture())
    #expect(query.isStale)
    await query.refetch()
    #expect(query.isStale)
  }

  @Test func chartStaysFreshUntilNextUpdate() async {
    let fixture = Fixture()
    let query = makeQuery(fixture, stalePolicy: .untilNextUpdate) {
      Payload(value: $0, nextUpdateAt: base + 15 * minute)
    }
    await query.refetch()
    await query.fetchIfStale()
    #expect(fixture.calls == 1)

    fixture.now = base + 15 * minute
    await query.fetchIfStale()
    #expect(fixture.calls == 2)
  }

  @Test func chartWithoutNextUpdateIsStale() async {
    let query = makeQuery(Fixture(), stalePolicy: .untilNextUpdate)
    await query.refetch()
    #expect(query.isStale)
  }

  @Test func invalidateRefetchesWhenObserved() async {
    let fixture = Fixture()
    let query = makeQuery(fixture, stalePolicy: .untilNextUpdate) {
      Payload(value: $0, nextUpdateAt: base + 15 * minute)
    }
    query.attach()
    await query.refetch()
    query.invalidate()
    await waitUntil { fixture.calls == 2 && !query.state.isFetching }
    #expect(fixture.calls == 2)
    #expect(query.isStale == false)
  }

  @Test func invalidateWaitsForNextAppearWhenUnobserved() async {
    let fixture = Fixture()
    let query = makeQuery(fixture, stalePolicy: .untilNextUpdate) {
      Payload(value: $0, nextUpdateAt: base + 15 * minute)
    }
    await query.refetch()
    query.invalidate()
    await waitUntil { false }
    #expect(fixture.calls == 1)
    #expect(query.isStale)
  }

  @Test func autoRefreshUsesLatestFetchOrFailure() async {
    let fixture = Fixture()
    let query = makeQuery(fixture) { call in
      if call > 1 { throw AppError(.network) }
      return Payload(value: call, nextUpdateAt: base - 60 * minute)
    }
    await query.refetch()
    #expect(query.nextAutoRefreshAt == base + minute)
    fixture.now = base + 10 * minute
    await query.refetch()
    #expect(query.nextAutoRefreshAt == base + 11 * minute)
  }

  @Test func noAutoRefreshWithoutData() {
    #expect(makeQuery(Fixture()).nextAutoRefreshAt == nil)
  }
}

@MainActor @Suite struct QueryCacheTests {
  @Test func sameKeyReturnsSameQuery() {
    let fixture = Fixture()
    let cache = QueryCache(now: { fixture.now })
    #expect(makeQuery(fixture, cache: cache) === makeQuery(fixture, cache: cache))
  }

  @Test func unobservedQueryExpiresAfterKeepFor() {
    let fixture = Fixture()
    let cache = QueryCache(now: { fixture.now })
    let query = makeQuery(fixture, cache: cache)
    query.attach()
    fixture.now = base + 10 * minute
    #expect(makeQuery(fixture, cache: cache) === query)

    query.detach()
    fixture.now = base + 15 * minute - 1
    #expect(makeQuery(fixture, cache: cache) === query)
    fixture.now = base + 15 * minute
    #expect(makeQuery(fixture, cache: cache) !== query)
  }

  @Test func invalidateMatchesKeyPrefix() async {
    let fixture = Fixture()
    let cache = QueryCache(now: { fixture.now })
    let fresh: @Sendable (Int) -> Payload = { Payload(value: $0, nextUpdateAt: base + 15 * minute) }
    let gold = makeQuery(
      fixture, cache: cache, key: ["commodities", "GC", "contracts"],
      stalePolicy: .untilNextUpdate, result: fresh)
    let list = makeQuery(
      fixture, cache: cache, key: ["commodities", "list"], stalePolicy: .untilNextUpdate,
      result: fresh)
    let settings = makeQuery(
      fixture, cache: cache, key: ["settings"], stalePolicy: .untilNextUpdate, result: fresh)
    for query in [gold, list, settings] { await query.refetch() }

    cache.invalidate(prefix: ["commodities", "GC"])
    #expect(gold.isStale)
    #expect(!list.isStale)
    #expect(!settings.isStale)

    // 접근 키 저장 뒤: 전부 (D-044)
    cache.invalidate()
    #expect(list.isStale && settings.isStale)
  }
}
