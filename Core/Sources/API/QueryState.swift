import Foundation

/// 화면 하나의 조회 상태. repository가 만들고 `QueryStateView`가 그린다 (architecture.md 화면 표시)
public struct QueryState<Value: Sendable>: Sendable {
  /// 마지막으로 받은 데이터. 새로고침이 실패해도 지우지 않는다
  public var data: Value?
  /// 마지막 조회 실패. 성공하면 지운다
  public var error: AppError?
  public var isFetching: Bool

  public init(data: Value? = nil, error: AppError? = nil, isFetching: Bool = false) {
    self.data = data
    self.error = error
    self.isFetching = isFetching
  }

  public enum Phase {
    case content(Value)
    case failed(AppError)
    case loading
  }

  /// 데이터가 한 번이라도 있으면 그 데이터를 계속 보이고(기준 시각 줄로 오래됨을 알림),
  /// 데이터 없이 실패하고 다시 조회 중이 아닐 때만 오류다 (RN `QueryStateView`)
  public var phase: Phase {
    if let data { return .content(data) }
    if let error, !isFetching { return .failed(error) }
    return .loading
  }
}
