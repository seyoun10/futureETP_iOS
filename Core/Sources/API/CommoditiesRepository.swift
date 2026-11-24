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
