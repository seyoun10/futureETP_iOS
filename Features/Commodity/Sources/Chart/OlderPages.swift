import Core
import Observation

/// 가장 과거 봉이 보이면 이전 3년을 더 받는 상태(C-a·C-c 공용, D-104, D-139, RN `charts/useOlderPages.ts`).
/// 보이는 범위를 알릴 때만 확인해, 받기가 실패해도 같은 자리에서 반복 요청하지 않는다. 차트는 드래그·핀치가 끝날 때
/// 범위가 그대로여도 다시 알리므로(`ChartViewState.rangeReports`) 가장 과거 끝에서 다시 끌거나 축소하면 다시 시도한다.
/// 받기 시작에 햅틱을 주고, 이번 회차가 끝나거나 `timeout`이 지날 때까지 `isLoading`이다(그동안 화면 터치를 막는다, D-108).
/// 실패·시간 초과면 공통 실패 Alert. 시간 초과로 거둔 회차의 늦은 응답은 데이터만 붙이고 상태는 바꾸지 않는다
@MainActor
@Observable
final class OlderPages {
  /// 받는 중(로딩 표시·터치 차단)
  private(set) var isLoading = false
  /// 공통 실패 Alert. [확인]은 닫기만 한다
  var showsFailure = false
  /// 받기를 시작할 때마다 바뀐다. 햅틱 트리거
  private(set) var startCount = 0

  @ObservationIgnored private let timeout: Duration
  /// 지금 회차 번호. 시간 초과·화면을 떠나 거둔 회차를 무효화한다
  @ObservationIgnored private var run = 0

  init(timeout: Duration = .seconds(5)) {
    self.timeout = timeout
  }

  /// 보이는 범위를 알렸다. 첫 봉(`firstVisible` 0)이 보이고 더 받을 것이 있으면 받는다. 받는 중이면 하지 않는다
  /// - Parameter fetch: 이전 3년을 받아 붙이고 실패면 오류를 돌려준다(`PagedQuery.fetchOlder`)
  func rangeReported(
    firstVisible: Int?, hasOlder: Bool, fetch: @escaping @MainActor () async -> AppError?
  ) async {
    guard firstVisible == 0, hasOlder, !isLoading else { return }
    run += 1
    let current = run
    isLoading = true
    startCount += 1
    let timer = Task { [weak self, timeout] in
      try? await Task.sleep(for: timeout)
      guard !Task.isCancelled else { return }
      self?.finish(current, failed: true)
    }
    let error = await fetch()
    timer.cancel()
    finish(current, failed: error != nil)
  }

  /// 화면을 떠났다. 진행 중인 회차를 거둔다(받기는 끊지 않는다)
  func cancel() {
    run += 1
    isLoading = false
  }

  private func finish(_ id: Int, failed: Bool) {
    guard run == id else { return }
    run += 1
    isLoading = false
    if failed { showsFailure = true }
  }
}
