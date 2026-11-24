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
