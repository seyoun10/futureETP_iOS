import Core

/// C 탭 화면이 쓰는 조회. App이 `QueryCache`와 repository로 만들어 넘긴다(feature는 API client를 모른다)
public struct CommodityQueries {
  /// C-a 조회. 설정 값(`query`)마다 다른 캐시 항목이다
  public let disparity: @MainActor (CommodityCode, DisparityQuery) -> PagedQuery<DisparityChart>

  public init(
    disparity: @escaping @MainActor (CommodityCode, DisparityQuery) -> PagedQuery<DisparityChart>
  ) {
    self.disparity = disparity
  }
}
