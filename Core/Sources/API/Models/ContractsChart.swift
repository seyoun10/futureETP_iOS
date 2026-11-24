/// `GET /v1/commodities/:code/contracts` 응답 `data` (계약 `schemas/contractsChart.json`).
/// 선 여러 개가 날짜를 공유하므로 열 배열이다 (D-092)
public struct ContractsChart: Codable, Sendable, Equatable {
  public let freshness: Freshness
  /// 가격 표시 소수 자릿수(0 이상)
  public let priceDecimals: Int
  /// 거래일 오름차순. 최근 3년씩, `before`를 주면 그 날짜보다 이른 3년 (D-104)
  public let dates: [LocalDate]
  /// `dates`보다 이른 날이 더 있는지
  public let hasMore: Bool
  /// 마지막 날짜에 장중 스냅숏 값(오늘 잠정 값)이 하나라도 있는지
  public let provisional: Bool
  /// A와 같은 월물 목록(만기순 5개, 대표월물 안전장치 6번째)
  public let contracts: [ContractLine]

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    freshness = try container.decode(Freshness.self, forKey: .freshness)
    priceDecimals = try container.decode(Int.self, forKey: .priceDecimals, atLeast: 0)
    dates = try container.decode([LocalDate].self, forKey: .dates)
    hasMore = try container.decode(Bool.self, forKey: .hasMore)
    provisional = try container.decode(Bool.self, forKey: .provisional)
    contracts = try container.decode([ContractLine].self, forKey: .contracts)
    // 원본 refine: 모든 선의 prices 길이는 dates와 같다
    guard contracts.allSatisfy({ $0.prices.count == dates.count }) else {
      throw DecodingError.dataCorruptedError(
        forKey: .contracts, in: container, debugDescription: "prices length must match dates")
    }
  }
}

/// C-c 월물 하나의 원가격 선. 가격은 소수 자릿수를 맞추지 않은 값이다
public struct ContractLine: Codable, Sendable, Equatable {
  public let symbol: String
  public let contractMonth: ContractMonth
  /// 롤 수익률 연환산(만기 간격)에 쓴다
  public let lastTradeDate: LocalDate
  /// 대표월물(A의 ● 표식)
  public let isFront: Bool
  /// `ContractsChart.dates`와 같은 길이·순서. 그날 값이 없으면(상장 전 등) nil
  public let prices: [Double?]
}
