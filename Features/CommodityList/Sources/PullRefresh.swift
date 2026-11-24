import Observation

/// A 당겨서 새로고침 상태 (screens.md A, D-138, RN `usePullRefresh`).
/// 조회가 끝날 때까지 인디케이터를 유지하고, `timeout` 안에 끝나지 않거나 실패하면 인디케이터를 거두고 실패 Alert를 띄운다.
/// 시간 초과로 거둔 조회는 끊지 않아 늦게 끝나면 그대로 목록을 바꾼다. 자동 새로고침·복귀 재조회는 이 상태를 쓰지 않는다
@MainActor
@Observable
final class PullRefresh {
  /// 인디케이터를 보이는 동안. 화면 터치를 막는다
  private(set) var isRefreshing = false
  /// 공통 실패 Alert. [확인]은 닫기만 하고 다시 조회하지 않는다
  var showsFailure = false
  /// 당길 때마다 바뀐다. 걸리는 순간 햅틱 트리거
  private(set) var pullCount = 0

  @ObservationIgnored private let timeout: Duration
  /// 시간 초과로 거둔 회차의 늦은 결과가 상태를 다시 바꾸지 않게 회차를 센다
  @ObservationIgnored private var run = 0

  init(timeout: Duration = .seconds(5)) {
    self.timeout = timeout
  }

  /// `.refreshable`에서 부른다. 조회가 끝나거나 시간이 지나면 돌아와 시스템 인디케이터를 거둔다.
  /// - Parameter fetch: 조회하고 성공 여부를 돌려준다
  func refresh(_ fetch: @escaping @MainActor () async -> Bool) async {
    run += 1
    let current = run
    pullCount += 1
    isRefreshing = true
    // 화면을 떠나 `.refreshable` 작업이 취소돼도 조회는 끝까지 한다
    let fetching = Task { await fetch() }
    let succeeded = await FirstResult().wait(for: fetching, timeout: timeout)
    guard run == current else { return }
    isRefreshing = false
    if succeeded != true { showsFailure = true }
  }
}

/// 조회와 시간 초과 중 먼저 끝난 쪽. 시간 초과면 nil이고 조회는 끊지 않는다
/// (task group은 남은 자식을 기다려 늦은 조회가 끝날 때까지 돌아오지 않는다)
@MainActor
private final class FirstResult {
  private var continuation: CheckedContinuation<Bool?, Never>?

  func wait(for fetching: Task<Bool, Never>, timeout: Duration) async -> Bool? {
    let timer = Task {
      try? await Task.sleep(for: timeout)
      resume(nil)
    }
    defer { timer.cancel() }
    return await withCheckedContinuation { continuation in
      self.continuation = continuation
      Task { resume(await fetching.value) }
    }
  }

  private func resume(_ value: Bool?) {
    continuation?.resume(returning: value)
    continuation = nil
  }
}
