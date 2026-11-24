import Testing

@testable import CommodityList

// RN `CommodityListScreen.test.tsx` 당겨서 새로고침 경우 (D-138)
@MainActor
struct PullRefreshTests {
  @Test func successHidesIndicatorWithoutAlert() async {
    let refresh = PullRefresh()
    await refresh.refresh { true }
    #expect(!refresh.isRefreshing)
    #expect(!refresh.showsFailure)
    #expect(refresh.pullCount == 1)
  }

  @Test func failureShowsAlert() async {
    let refresh = PullRefresh()
    await refresh.refresh { false }
    #expect(!refresh.isRefreshing)
    #expect(refresh.showsFailure)
  }

  @Test func keepsIndicatorWhileFetching() async {
    let refresh = PullRefresh()
    let (gate, open) = AsyncStream.makeStream(of: Void.self)
    let pulling = Task {
      await refresh.refresh {
        for await _ in gate {}
        return true
      }
    }
    await Task.yield()
    #expect(refresh.isRefreshing)
    open.finish()
    await pulling.value
    #expect(!refresh.isRefreshing)
    #expect(!refresh.showsFailure)
  }

  @Test func timeoutHidesIndicatorAndLetsFetchFinish() async {
    let refresh = PullRefresh(timeout: .milliseconds(20))
    let (gate, open) = AsyncStream.makeStream(of: Void.self)
    var finished = false
    // 조회가 끝나지 않아도 시간 초과면 돌아온다
    await refresh.refresh {
      for await _ in gate {}
      finished = true
      return true
    }
    #expect(!refresh.isRefreshing)
    #expect(refresh.showsFailure)
    // 늦게 끝난 조회는 끊지 않고, Alert를 다시 바꾸지 않는다
    refresh.showsFailure = false
    open.finish()
    while !finished { await Task.yield() }
    #expect(!refresh.showsFailure)
  }
}
