import SwiftUI
import UIKit

extension View {
  /// 화면이 보이는 동안 `query`를 관찰한다 (RN `useQuery` 마운트·focusManager·`useAutoRefresh`, D-030, D-075).
  /// - 진입할 때와 앱에 돌아올 때 오래된 값이면 다시 조회한다
  /// - `nextUpdateAt` + 1분(마지막 조회 1분 뒤 이후)에 다시 조회한다. 백그라운드면 건너뛰고 복귀 재조회에 맡긴다
  public func queryLifecycle<Value: Sendable>(_ query: Query<Value>) -> some View {
    modifier(QueryLifecycle(query: query))
  }
}

private struct QueryLifecycle<Value: Sendable>: ViewModifier {
  let query: Query<Value>
  @Environment(\.scenePhase) private var scenePhase

  func body(content: Content) -> some View {
    content
      .onAppear {
        query.attach()
        Task { await query.fetchIfStale() }
      }
      .onDisappear { query.detach() }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active { Task { await query.fetchIfStale() } }
      }
      // 조회가 끝날 때마다(성공·실패) 시각이 바뀌어 다시 예약된다. 화면을 떠나면 취소된다
      .task(id: query.nextAutoRefreshAt) {
        guard let runAt = query.nextAutoRefreshAt else { return }
        try? await Task.sleep(for: .seconds(max(0, runAt.timeIntervalSinceNow)))
        guard !Task.isCancelled, UIApplication.shared.applicationState == .active else { return }
        await query.refetch()
      }
  }
}
