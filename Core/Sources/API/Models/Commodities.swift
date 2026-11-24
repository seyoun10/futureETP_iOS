/// `GET /v1/commodities` 응답 `data` (계약 `schemas/commodities.json`). 원자재는 표시 순서대로다
public struct Commodities: Codable, Sendable, Equatable {
  public let freshness: Freshness
  public let commodities: [CommoditySummary]
}

/// A 원자재 목록의 원자재 하나 (D-085)
public struct CommoditySummary: Codable, Sendable, Equatable {
  public let code: CommodityCode
  /// 가격 표시 소수 자릿수(0 이상)
  public let priceDecimals: Int
  /// 알림 대상(B-a) 원자재
  public let alert: Bool
  /// 만기순 5개, 대표월물이 그 안에 없으면 6번째
  public let contracts: [ContractQuote]

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    code = try container.decode(CommodityCode.self, forKey: .code)
    priceDecimals = try container.decode(Int.self, forKey: .priceDecimals)
    guard priceDecimals >= 0 else {
      throw DecodingError.dataCorruptedError(
        forKey: .priceDecimals, in: container, debugDescription: "negative priceDecimals")
    }
    alert = try container.decode(Bool.self, forKey: .alert)
    contracts = try container.decode([ContractQuote].self, forKey: .contracts)
  }
}

/// A 원자재 목록 한 줄(월물 하나). 가격은 소수 자릿수를 맞추지 않은 값이다
public struct ContractQuote: Codable, Sendable, Equatable {
  /// 서버 표준형 심볼(`CLZ26`)
  public let symbol: String
  public let contractMonth: ContractMonth
  /// 정산가 → 장중 스냅숏 → 마지막 정산가 순. 일봉이 하나도 없으면 nil
  public let price: Double?
  /// 직전 거래일 정산가 대비. 거래 없음이거나 직전 정산가가 없으면 nil
  public let change: Double?
  public let changePct: Double?
  /// "거래 없음"
  public let noTrade: Bool
  /// 대표월물
  public let isFront: Bool
}
