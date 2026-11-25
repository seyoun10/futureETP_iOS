import Core

/// C 탭 화면이 쓰는 조회. App이 `QueryCache`와 repository로 만들어 넘긴다(feature는 API client를 모른다)
public struct CommodityQueries {
  /// C-a 조회. 설정 값(`query`)마다 다른 캐시 항목이다
  public let disparity: @MainActor (CommodityCode, DisparityQuery) -> PagedQuery<DisparityChart>
  /// C-c 조회. 원자재마다 하나다
  public let contracts: @MainActor (CommodityCode) -> PagedQuery<ContractsChart>
  /// C-b 조회. 기준일마다 다른 캐시 항목이다(nil은 서버가 고른 최근 기준일)
  public let curve: @MainActor (CommodityCode, LocalDate?) -> Query<Curve>
  /// C-d 조회. 원자재마다 하나다
  public let etps: @MainActor (CommodityCode) -> Query<ETPList>

  public init(
    disparity: @escaping @MainActor (CommodityCode, DisparityQuery) -> PagedQuery<DisparityChart>,
    contracts: @escaping @MainActor (CommodityCode) -> PagedQuery<ContractsChart>,
    curve: @escaping @MainActor (CommodityCode, LocalDate?) -> Query<Curve>,
    etps: @escaping @MainActor (CommodityCode) -> Query<ETPList>
  ) {
    self.disparity = disparity
    self.contracts = contracts
    self.curve = curve
    self.etps = etps
  }

  /// A에서 원자재를 누르면 화면 전환 동안 C-a 조회를 먼저 시작한다. C-a 화면이 같은 캐시 항목의 조회를 이어받는다.
  /// 설정은 캐시에 있으면 오래됐어도 그대로 쓰고, 없을 때만 받는다. 실패는 무시한다(화면이 다시 조회하고 오류를 보여 준다)
  /// (RN `prefetchDisparityChart`)
  @MainActor
  public func prefetchDisparity(_ code: CommodityCode, settings: SettingsStore) async {
    if settings.data == nil { await settings.query.refetch() }
    guard let values = settings.data, let query = DisparityTabView.query(values) else { return }
    await disparity(code, query).query.fetchIfStale()
  }
}
