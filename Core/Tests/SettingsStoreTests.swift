import Foundation
import Testing

@testable import Core

private func settings(
  locale: AppLanguage = .ko, timezone: String = "Asia/Seoul", basis: Basis = .front
) -> AppSettings {
  AppSettings(
    locale: locale, timezone: timezone, basis: basis, maPeriod: .days50, window: .years5,
    rareLevels: [1, 2.5, 5, 10, 20], alertCommodity: .gc, quietTime: nil)
}

/// 조회·변경을 손으로 끝내는 repository. 호출 순서를 기록한다
actor StubRepository: SettingsRepository {
  private(set) var calls: [String] = []
  private var fetches: [CheckedContinuation<AppSettings, any Error>] = []
  private var updates: [CheckedContinuation<AppSettings, any Error>] = []

  func fetch() async throws -> AppSettings {
    calls.append("fetch")
    return try await withCheckedThrowingContinuation { fetches.append($0) }
  }

  func update(_ patch: SettingsPatch) async throws -> AppSettings {
    calls.append("update \(patch.basis?.rawValue ?? patch.locale?.rawValue ?? "-")")
    return try await withCheckedThrowingContinuation { updates.append($0) }
  }

  var waiting: (fetches: Int, updates: Int) { (fetches.count, updates.count) }

  func finishFetch(_ result: Result<AppSettings, any Error>) {
    fetches.removeFirst().resume(with: result)
  }

  func finishUpdate(_ result: Result<AppSettings, any Error>) {
    updates.removeFirst().resume(with: result)
  }
}

@MainActor
private func waitUntil(_ condition: () async -> Bool) async {
  for _ in 0..<1000 {
    if await condition() { return }
    await Task.yield()
  }
}

// RN `useSettings.test.tsx`와 같은 경우
@MainActor
@Suite struct SettingsStoreTests {
  let repository = StubRepository()
  let cache = QueryCache()

  private func loadedStore() async -> SettingsStore {
    let store = SettingsStore(repository: repository, cache: cache)
    let fetch = Task { await store.query.refetch() }
    await waitUntil { await repository.waiting.fetches == 1 }
    await repository.finishFetch(.success(settings()))
    await fetch.value
    return store
  }

  @Test func showsPendingPatchesOverServerValueInOrder() async {
    let store = await loadedStore()
    store.update(SettingsPatch(basis: .kr))
    store.update(SettingsPatch(locale: .en, basis: .us))
    #expect(store.data?.basis == .us)
    #expect(store.data?.locale == .en)
    // 캐시에는 서버가 확인한 값만
    #expect(store.query.state.data?.basis == .front)
  }

  @Test func sendsPatchesOneAtATime() async {
    let store = await loadedStore()
    let first = store.update(SettingsPatch(basis: .kr))
    let second = store.update(SettingsPatch(basis: .us))
    await waitUntil { await repository.waiting.updates == 1 }
    #expect(await repository.calls == ["fetch", "update KR"])

    await repository.finishUpdate(.success(settings(basis: .kr)))
    await first.value
    #expect(store.data?.basis == .us)
    await waitUntil { await repository.waiting.updates == 1 }
    await repository.finishUpdate(.success(settings(basis: .us)))
    await second.value
    #expect(await repository.calls == ["fetch", "update KR", "update US"])
    #expect(store.query.state.data?.basis == .us)
  }

  @Test func failedPatchDropsOnlyThatChange() async {
    let store = await loadedStore()
    let first = store.update(SettingsPatch(basis: .kr))
    let second = store.update(SettingsPatch(locale: .en))
    await waitUntil { await repository.waiting.updates == 1 }
    await repository.finishUpdate(.failure(AppError(.network)))
    await first.value
    #expect(store.data?.basis == .front)
    #expect(store.data?.locale == .en)
    await waitUntil { await repository.waiting.updates == 1 }
    await repository.finishUpdate(.success(settings(locale: .en)))
    await second.value
    #expect(store.data?.locale == .en)
  }

  @Test func fetchStartedBeforePatchDoesNotOverwriteResponse() async {
    let store = await loadedStore()
    store.query.attach()
    let refetch = Task { await store.query.refetch() }
    await waitUntil { await repository.waiting.fetches == 1 }
    let update = store.update(SettingsPatch(basis: .kr))
    await waitUntil { await repository.waiting.updates == 1 }
    await repository.finishUpdate(.success(settings(basis: .kr)))
    await update.value
    // 끊긴 조회가 늦게 옛 값으로 끝나도 버린다
    await repository.finishFetch(.success(settings()))
    await refetch.value
    #expect(store.query.state.data?.basis == .kr)
    #expect(store.query.state.isFetching == false)
  }

  @Test func failureRefetchesWhileVisible() async {
    let store = await loadedStore()
    store.query.attach()
    let update = store.update(SettingsPatch(basis: .kr))
    await waitUntil { await repository.waiting.updates == 1 }
    await repository.finishUpdate(.failure(AppError(.timeout)))
    await update.value
    await waitUntil { await repository.waiting.fetches == 1 }
    #expect(await repository.calls == ["fetch", "update KR", "fetch"])
    await repository.finishFetch(.success(settings(basis: .kr)))
    await waitUntil { store.query.state.data?.basis == .kr }
    #expect(store.query.state.data?.basis == .kr)
  }

  @Test func alertChangeInvalidatesCommodityList() async {
    let store = await loadedStore()
    let counter = CallCounter()
    let list = cache.query(QueryKeys.commodityList) { await counter.next() }
    list.attach()
    await list.refetch()

    let other = store.update(SettingsPatch(basis: .kr))
    await waitUntil { await repository.waiting.updates == 1 }
    await repository.finishUpdate(.success(settings(basis: .kr)))
    await other.value
    #expect(await counter.value == 1)

    let alert = store.update(SettingsPatch(alertCommodity: .some(nil)))
    await waitUntil { await repository.waiting.updates == 1 }
    await repository.finishUpdate(.success(settings()))
    await alert.value
    await waitUntil { await counter.value == 2 }
    #expect(await counter.value == 2)
  }
}

@MainActor
@Suite struct QueryCancelTests {
  @Test func setDataReplacesValueAndEndsFetching() async {
    let query = QueryCache().query(["a"]) { () async throws -> Int in
      try await Task.sleep(for: .seconds(60))
      return 1
    }
    let refetch = Task { await query.refetch() }
    await waitUntil { query.state.isFetching }
    query.setData(2)
    await refetch.value
    #expect(query.state.data == 2)
    #expect(query.state.isFetching == false)
    #expect(query.isStale == true)  // .immediately
  }

  @Test func refetchAfterCancelStartsNewFetch() async {
    let counter = CallCounter()
    let query = QueryCache().query(["a"]) { () async throws -> Int in
      let call = await counter.next()
      if call == 1 { try await Task.sleep(for: .seconds(60)) }
      return call
    }
    let first = Task { await query.refetch() }
    await waitUntil { await counter.value == 1 }
    query.cancel()
    await query.refetch()
    await first.value
    #expect(query.state.data == 2)
  }
}

actor CallCounter {
  private(set) var value = 0
  func next() -> Int {
    value += 1
    return value
  }
}
