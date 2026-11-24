import Foundation

/// A 원자재 목록 `GET /v1/commodities` (D-085)
public protocol CommoditiesRepository: Sendable {
  func fetchList() async throws -> Commodities
}

public struct LiveCommoditiesRepository: CommoditiesRepository {
  private let client: APIClient

  public init(client: APIClient) {
    self.client = client
  }

  public func fetchList() async throws -> Commodities {
    try await client.send(APIRequest("/commodities", as: Commodities.self))
  }
}

extension QueryCache {
  /// A 원자재 목록 조회 (RN `useCommodities`). 화면 진입·앱 복귀마다 다시 조회하고,
  /// `freshness.nextUpdateAt` 뒤에 자동 새로고침한다 (D-075)
  public func commodityList(_ repository: any CommoditiesRepository) -> Query<Commodities> {
    query(
      QueryKeys.commodityList, freshness: { $0.freshness },
      fetch: { try await repository.fetchList() })
  }
}

/// C-a 이격도차트 `GET /v1/commodities/:code/disparity` (D-086, D-104)
public protocol DisparityRepository: Sendable {
  func fetchDisparity(_ code: CommodityCode, query: DisparityQuery) async throws -> DisparityChart
}

extension LiveCommoditiesRepository: DisparityRepository {
  public func fetchDisparity(_ code: CommodityCode, query: DisparityQuery) async throws
    -> DisparityChart
  {
    try await client.send(
      APIRequest(
        "/commodities/\(code.rawValue)/disparity", query: query.queryItems, as: DisparityChart.self)
    )
  }
}

extension QueryCache {
  /// C-a 조회 (RN `useDisparityChart`). 설정 값(`query`, `before` 제외)이 키라 설정이 바뀌면 다시 조회한다 (D-086)
  public func disparityChart(
    _ repository: any DisparityRepository, code: CommodityCode, query: DisparityQuery
  ) -> PagedQuery<DisparityChart> {
    var params = query
    params.before = nil
    let latest = params
    return pagedQuery(QueryKeys.disparity(code, query: latest)) { before in
      var query = latest
      query.before = before
      return try await repository.fetchDisparity(code, query: query)
    }
  }
}

/// C-c 월물차트 `GET /v1/commodities/:code/contracts` (D-092, D-104)
public protocol ContractsRepository: Sendable {
  func fetchContracts(_ code: CommodityCode, query: ContractsQuery) async throws -> ContractsChart
}

extension LiveCommoditiesRepository: ContractsRepository {
  public func fetchContracts(_ code: CommodityCode, query: ContractsQuery) async throws
    -> ContractsChart
  {
    try await client.send(
      APIRequest(
        "/commodities/\(code.rawValue)/contracts", query: query.queryItems,
        as: ContractsChart.self))
  }
}

extension QueryCache {
  /// C-c 조회 (RN `useContracts`). 전역 설정을 쓰지 않아 원자재마다 하나다
  public func contractsChart(_ repository: any ContractsRepository, code: CommodityCode)
    -> PagedQuery<ContractsChart>
  {
    pagedQuery(QueryKeys.contracts(code)) { before in
      try await repository.fetchContracts(code, query: ContractsQuery(before: before))
    }
  }
}

/// C-b 월물커브 `GET /v1/commodities/:code/curve?baseDate` (D-090)
public protocol CurveRepository: Sendable {
  func fetchCurve(_ code: CommodityCode, query: CurveQuery) async throws -> Curve
}

extension LiveCommoditiesRepository: CurveRepository {
  public func fetchCurve(_ code: CommodityCode, query: CurveQuery) async throws -> Curve {
    try await client.send(
      APIRequest("/commodities/\(code.rawValue)/curve", query: query.queryItems, as: Curve.self))
  }
}

extension QueryCache {
  /// C-b 조회 (RN `useCurve` + `chartCacheOptions`). 기준일마다 다른 캐시 항목이고, nil은 서버가 고른 최근 기준일이다.
  /// 화면을 떠나도 1시간 두고 `nextUpdateAt`까지 새것으로 본다
  public func curve(_ repository: any CurveRepository, code: CommodityCode, baseDate: LocalDate?)
    -> Query<Curve>
  {
    query(
      QueryKeys.curve(code, baseDate: baseDate), keepFor: Self.chartKeepFor,
      stalePolicy: .untilNextUpdate, freshness: { $0.freshness },
      fetch: { try await repository.fetchCurve(code, query: CurveQuery(baseDate: baseDate)) })
  }
}

/// C-d ETP 목록 `GET /v1/commodities/:code/etps`와 C-d-a 상세 `GET /v1/etps/:id` (D-017)
public protocol ETPRepository: Sendable {
  func fetchETPs(_ code: CommodityCode) async throws -> ETPList
  func fetchETP(_ id: UUID) async throws -> ETPDetail
}

extension LiveCommoditiesRepository: ETPRepository {
  public func fetchETPs(_ code: CommodityCode) async throws -> ETPList {
    try await client.send(APIRequest("/commodities/\(code.rawValue)/etps", as: ETPList.self))
  }

  public func fetchETP(_ id: UUID) async throws -> ETPDetail {
    try await client.send(APIRequest("/etps/\(id.uuidString.lowercased())", as: ETPDetail.self))
  }
}

extension QueryCache {
  /// C-d 조회 (RN `useEtps`). 필터·정렬은 화면에서 한다. 화면 진입·앱 복귀마다 다시 조회한다
  public func etpList(_ repository: any ETPRepository, code: CommodityCode) -> Query<ETPList> {
    query(QueryKeys.etps(code), fetch: { try await repository.fetchETPs(code) })
  }

  /// C-d-a 조회 (RN `useEtp`)
  public func etpDetail(_ repository: any ETPRepository, id: UUID) -> Query<ETPDetail> {
    query(QueryKeys.etp(id), fetch: { try await repository.fetchETP(id) })
  }
}
