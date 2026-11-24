import Core

/// C 탭 화면이 쓰는 조회. App이 `QueryCache`와 repository로 만들어 넘긴다(feature는 API client를 모른다)
public struct CommodityQueries {
  /// C-a 조회. 설정 값(`query`)마다 다른 캐시 항목이다
  public let disparity: @MainActor (CommodityCode, DisparityQuery) -> PagedQuery<DisparityChart>
  /// C-c 조회. 원자재마다 하나다
  public let contracts: @MainActor (CommodityCode) -> PagedQuery<ContractsChart>
  /// C-b 조회. 기준일마다 다른 캐시 항목이다(nil은 서버가 고른 최근 기준일)
  public let curve: @MainActor (CommodityCode, LocalDate?) -> Query<Curve>

  public init(
    disparity: @escaping @MainActor (CommodityCode, DisparityQuery) -> PagedQuery<DisparityChart>,
    contracts: @escaping @MainActor (CommodityCode) -> PagedQuery<ContractsChart>,
    curve: @escaping @MainActor (CommodityCode, LocalDate?) -> Query<Curve>
  ) {
    self.disparity = disparity
    self.contracts = contracts
    self.curve = curve
  }
}
