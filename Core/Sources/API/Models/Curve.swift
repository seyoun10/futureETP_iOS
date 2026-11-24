/// `GET /v1/commodities/:code/curve?baseDate` 응답 `data` (계약 `schemas/curve.json`, D-090).
/// D는 `freshness.tradeDate`다
public struct Curve: Codable, Sendable, Equatable {
  public let freshness: Freshness
  /// 가격 표시 소수 자릿수(0 이상)
  public let priceDecimals: Int
  /// 실제로 쓴 기준일(거래일). 요청한 날짜가 휴장일이면 직전 거래일, 하한보다 앞이면 하한 이후 첫 거래일
  public let baseDate: LocalDate
  /// D부터 센 거래일 수(기준일이 D-1이면 1)
  public let baseOffset: Int
  /// 기준일을 1 거래일 앞·뒤로 옮긴 날짜. 범위 끝이면 nil
  public let prevBaseDate: LocalDate?
  public let nextBaseDate: LocalDate?
  /// 기준일 선택 범위: 그 원자재의 가장 이른 일봉 날짜 ~ D-1
  public let minBaseDate: LocalDate
  public let maxBaseDate: LocalDate
  /// 비교 커브 날짜 = 기준일 다음 거래일(기준일이 D-1이면 D, D-114). `current*` 값은 이 날짜 기준
  public let compareDate: LocalDate
  /// 만기순
  public let points: [CurveContract]
  /// 비교일(`compareDate`) 커브의 수치 요약. 이름과 달리 D가 아닐 수 있다
  public let current: CurveStats?
  /// 기준일(`baseDate`) 커브의 수치 요약
  public let base: CurveStats?

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    freshness = try container.decode(Freshness.self, forKey: .freshness)
    priceDecimals = try container.decode(Int.self, forKey: .priceDecimals, atLeast: 0)
    baseDate = try container.decode(LocalDate.self, forKey: .baseDate)
    baseOffset = try container.decode(Int.self, forKey: .baseOffset, atLeast: 1)
    prevBaseDate = try container.decodeIfPresent(LocalDate.self, forKey: .prevBaseDate)
    nextBaseDate = try container.decodeIfPresent(LocalDate.self, forKey: .nextBaseDate)
    minBaseDate = try container.decode(LocalDate.self, forKey: .minBaseDate)
    maxBaseDate = try container.decode(LocalDate.self, forKey: .maxBaseDate)
    compareDate = try container.decode(LocalDate.self, forKey: .compareDate)
    points = try container.decode([CurveContract].self, forKey: .points)
    current = try container.decodeIfPresent(CurveStats.self, forKey: .current)
    base = try container.decodeIfPresent(CurveStats.self, forKey: .base)
  }
}

/// C-b 월물 하나. 가격은 소수 자릿수를 맞추지 않은 값이다
public struct CurveContract: Codable, Sendable, Equatable {
  public let symbol: String
  public let contractMonth: ContractMonth
  /// 그 커브에 없으면 nil(기준일에만 있는 월물 = 그 사이 만기, D에만 있는 월물 = 신규 상장 등)
  public let basePrice: Double?
  public let currentPrice: Double?
  /// 두 커브에 모두 있고 기준일 값이 0보다 클 때만
  public let changePct: Double?
}

/// M1→M2 수치 요약. M1·M2가 없거나 가격이 0 이하면 응답에서 nil(화면은 "산출 불가")
public struct CurveStats: Codable, Sendable, Equatable {
  public let m1ContractMonth: ContractMonth
  public let m2ContractMonth: ContractMonth
  public let state: CurveState
  /// (M2 / M1 − 1) × 100
  public let spreadPct: Double
  /// 연환산 롤 수익률(%/년). 양수 = 백워데이션(롤 이익)
  public let rollYieldPct: Double
}
