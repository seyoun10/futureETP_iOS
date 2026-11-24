import Core
import Testing

@testable import Commodity

// RN `useOlderPages.test.tsx` 경우 (D-104, D-139)
@MainActor
struct OlderPagesTests {
  @Test func fetchesOnlyWhenTheFirstBarIsVisibleAndMoreExists() async {
    let older = OlderPages()
    var calls = 0
    let fetch: @MainActor () async -> AppError? = {
      calls += 1
      return nil
    }
    await older.rangeReported(firstVisible: 3, hasOlder: true, fetch: fetch)
    await older.rangeReported(firstVisible: 0, hasOlder: false, fetch: fetch)
    await older.rangeReported(firstVisible: nil, hasOlder: true, fetch: fetch)
    #expect(calls == 0)
    await older.rangeReported(firstVisible: 0, hasOlder: true, fetch: fetch)
    #expect(calls == 1)
    #expect(older.startCount == 1)
    #expect(!older.isLoading)
    #expect(!older.showsFailure)
  }

  @Test func loadingBlocksASecondFetch() async {
    let older = OlderPages()
    let (gate, open) = AsyncStream.makeStream(of: Void.self)
    var calls = 0
    let first = Task {
      await older.rangeReported(firstVisible: 0, hasOlder: true) {
        calls += 1
        for await _ in gate {}
        return nil
      }
    }
    while !older.isLoading { await Task.yield() }
    await older.rangeReported(firstVisible: 0, hasOlder: true) {
      calls += 1
      return nil
    }
    #expect(calls == 1)
    open.finish()
    await first.value
    #expect(!older.isLoading)
  }

  @Test func failureShowsAlert() async {
    let older = OlderPages()
    await older.rangeReported(firstVisible: 0, hasOlder: true) { AppError(.network) }
    #expect(!older.isLoading)
    #expect(older.showsFailure)
  }

  @Test func timeoutStopsLoadingAndLateResultDoesNotChangeState() async {
    let older = OlderPages(timeout: .milliseconds(20))
    let (gate, open) = AsyncStream.makeStream(of: Void.self)
    let fetching = Task {
      await older.rangeReported(firstVisible: 0, hasOlder: true) {
        for await _ in gate {}
        return AppError(.network)
      }
    }
    while !older.showsFailure { await Task.yield() }
    #expect(!older.isLoading)
    // 늦게 끝난 회차는 Alert를 다시 띄우지 않는다
    older.showsFailure = false
    open.finish()
    await fetching.value
    #expect(!older.showsFailure)
    #expect(!older.isLoading)
  }

  @Test func cancelDropsTheRunningFetch() async {
    let older = OlderPages()
    let (gate, open) = AsyncStream.makeStream(of: Void.self)
    let fetching = Task {
      await older.rangeReported(firstVisible: 0, hasOlder: true) {
        for await _ in gate {}
        return AppError(.network)
      }
    }
    while !older.isLoading { await Task.yield() }
    older.cancel()
    #expect(!older.isLoading)
    open.finish()
    await fetching.value
    #expect(!older.showsFailure)
  }
}
