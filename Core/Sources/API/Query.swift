import Foundation
import Observation

/// 캐시한 값을 언제까지 새것으로 볼지 (RN `staleTime`)
public enum StalePolicy: Sendable {
  /// 바로 오래된 값. 화면에 들어오거나 앱에 돌아올 때마다 다시 조회한다 (TanStack Query 기본값 0)
  case immediately
  /// `freshness.nextUpdateAt`까지 새것. 값이 배치 때만 바뀌는 C 차트용. nil이거나 지났으면 바로 오래된 값 (RN `chartCache`)
  case untilNextUpdate
}

/// `nextUpdateAt` 뒤 자동 새로고침 시각 (D-042, D-048, D-075, RN `useAutoRefresh`)
public enum AutoRefresh {
  /// 배치 완료 예상 시각 뒤 여유
  public static let margin: TimeInterval = 60
  /// 마지막 조회(성공·실패)부터 다음 자동 조회까지 최소 간격. 예상 시각이 지났거나 조회가 계속 실패할 때 반복을 막는다
  public static let minInterval: TimeInterval = 60

  /// `nextUpdateAt`이 nil이면 자동 새로고침하지 않는다
  public static func date(nextUpdateAt: Date?, lastFetchedAt: Date?) -> Date? {
    guard let nextUpdateAt else { return nil }
    return max(
      nextUpdateAt.addingTimeInterval(margin),
      (lastFetchedAt ?? .distantPast).addingTimeInterval(minInterval))
  }
}

/// 조회 하나의 캐시 항목 (RN TanStack Query `useQuery`, D-030). `QueryCache`가 키마다 하나 만든다.
/// 화면 Model이 `state`를 읽고, 화면은 `.queryLifecycle(_:)`으로 보이는 동안 관찰·재조회·자동 새로고침을 건다.
/// 재시도·`UNAUTHORIZED` 알림은 `APIClient`가 맡는다
@MainActor @Observable
public final class Query<Value: Sendable> {
  public private(set) var state = QueryState<Value>()
  public private(set) var dataUpdatedAt: Date?
  public private(set) var errorUpdatedAt: Date?

  @ObservationIgnored let key: [String]
  @ObservationIgnored let keepFor: TimeInterval
  @ObservationIgnored private let fetcher: @Sendable () async throws -> Value
  @ObservationIgnored private let stalePolicy: StalePolicy
  @ObservationIgnored private let freshness: @Sendable (Value) -> Freshness?
  @ObservationIgnored private let now: @Sendable () -> Date
  @ObservationIgnored private var isInvalidated = false
  @ObservationIgnored private var inFlight: Task<Void, Never>?
  /// 조회를 시작하거나 끊을 때마다 바뀐다. 끝난 조회가 끊긴 조회면 결과를 버린다
  @ObservationIgnored private var generation = 0
  @ObservationIgnored private(set) var observerCount = 0
  @ObservationIgnored private(set) var unobservedSince: Date

  init(
    key: [String], keepFor: TimeInterval, stalePolicy: StalePolicy,
    freshness: @escaping @Sendable (Value) -> Freshness?,
    now: @escaping @Sendable () -> Date,
    fetch: @escaping @Sendable () async throws -> Value
  ) {
    self.key = key
    self.keepFor = keepFor
    self.stalePolicy = stalePolicy
    self.freshness = freshness
    self.now = now
    self.fetcher = fetch
    unobservedSince = now()
  }

  /// 데이터가 없거나, 무효화됐거나, 새것으로 볼 시각이 지났다
  public var isStale: Bool {
    guard let data = state.data, !isInvalidated else { return true }
    switch stalePolicy {
    case .immediately: return true
    case .untilNextUpdate:
      guard let nextUpdateAt = freshness(data)?.nextUpdateAt else { return true }
      return nextUpdateAt <= now()
    }
  }

  /// 다음 자동 새로고침 시각. 데이터에 `freshness`가 없거나 `nextUpdateAt`이 nil이면 nil
  public var nextAutoRefreshAt: Date? {
    let lastFetchedAt = [dataUpdatedAt, errorUpdatedAt].compactMap(\.self).max()
    return AutoRefresh.date(
      nextUpdateAt: state.data.flatMap(freshness)?.nextUpdateAt, lastFetchedAt: lastFetchedAt)
  }

  /// 새로 조회한다. 진행 중인 조회가 있으면 취소하지 않고 그 조회를 기다린다 (RN `cancelRefetch: false`)
  public func refetch() async {
    if let inFlight { return await inFlight.value }
    generation += 1
    let current = generation
    let task = Task { await run(current) }
    inFlight = task
    await task.value
  }

  /// 진행 중인 조회를 끊고 결과를 버린다(RN `cancelQueries`). 변경 요청이 옛 조회 결과에 덮이지 않게 한다
  public func cancel() {
    generation += 1
    inFlight?.cancel()
    inFlight = nil
    state.isFetching = false
  }

  /// 서버가 돌려준 값을 넣는다(RN `setQueryData`). 진행 중인 조회는 끊는다
  public func setData(_ value: Value) {
    cancel()
    state.data = value
    state.error = nil
    dataUpdatedAt = now()
    isInvalidated = false
  }

  /// 오래된 값일 때만 조회한다 (화면 진입·앱 복귀)
  public func fetchIfStale() async {
    if isStale { await refetch() }
  }

  /// 오래된 값으로 표시하고, 보이는 화면이 있으면 바로 다시 조회한다(기다리지 않음). 없으면 다음 진입 때 조회한다
  public func invalidate() {
    isInvalidated = true
    if observerCount > 0 { Task { await refetch() } }
  }

  /// 화면이 보이기 시작함. 보이는 동안은 캐시에서 지우지 않는다
  public func attach() {
    observerCount += 1
  }

  public func detach() {
    observerCount = max(0, observerCount - 1)
    if observerCount == 0 { unobservedSince = now() }
  }

  /// 보는 화면 없이 `keepFor`가 지났다 (RN `gcTime`)
  func isExpired(at date: Date) -> Bool {
    observerCount == 0 && inFlight == nil && date >= unobservedSince.addingTimeInterval(keepFor)
  }

  private func run(_ current: Int) async {
    state.isFetching = true
    defer {
      if generation == current {
        state.isFetching = false
        inFlight = nil
      }
    }
    do {
      let value = try await fetcher()
      guard generation == current else { return }
      state.data = value
      state.error = nil
      dataUpdatedAt = now()
      isInvalidated = false
    } catch is CancellationError {
      // 호출자 취소는 실패로 보이지 않는다
    } catch {
      guard generation == current else { return }
      state.error = (error as? AppError) ?? AppError(.internal, message: "\(error)")
      errorUpdatedAt = now()
    }
  }
}
