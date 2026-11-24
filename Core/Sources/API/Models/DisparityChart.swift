/// `GET /v1/commodities/:code/disparity` 응답 `data` (계약 `schemas/disparityChart.json`, D-086)
public struct DisparityChart: Codable, Sendable, Equatable {
  public let freshness: Freshness
  /// 가격 표시 소수 자릿수(0 이상)
  public let priceDecimals: Int
  /// 실제로 그린 기준값. 요청한 한국형·미국형 규칙이 없는 원자재는 `front`이고 `fallback`이 true다
  public let basis: Basis
  public let fallback: Bool
  public let maPeriod: MAPeriod
  public let window: DistributionWindow
  /// 분포가 없으면(데이터 부족) nil
  public let distribution: Distribution?
  /// 위 방향 레벨 오름차순, 그다음 아래 방향 레벨 오름차순. 분포가 없으면 빈 배열
  public let rareLevels: [RareLevelLine]
  /// 마지막 봉 이격도의 가까운 꼬리 백분위
  public let currentTail: Tail?
  /// 마지막 봉이 장중 스냅숏으로 만든 오늘 잠정 봉인지
  public let provisional: Bool
  /// 거래일 오름차순. 최근 3년씩, `before`를 주면 그 날짜보다 이른 3년 (D-104)
  public let bars: [DisparityBar]
  /// `bars`보다 이른 봉이 더 있는지
  public let hasMore: Bool

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    freshness = try container.decode(Freshness.self, forKey: .freshness)
    priceDecimals = try container.decode(Int.self, forKey: .priceDecimals, atLeast: 0)
    basis = try container.decode(Basis.self, forKey: .basis)
    fallback = try container.decode(Bool.self, forKey: .fallback)
    maPeriod = try container.decode(MAPeriod.self, forKey: .maPeriod)
    window = try container.decode(DistributionWindow.self, forKey: .window)
    distribution = try container.decodeIfPresent(Distribution.self, forKey: .distribution)
    rareLevels = try container.decode([RareLevelLine].self, forKey: .rareLevels)
    currentTail = try container.decodeIfPresent(Tail.self, forKey: .currentTail)
    provisional = try container.decode(Bool.self, forKey: .provisional)
    bars = try container.decode([DisparityBar].self, forKey: .bars)
    hasMore = try container.decode(Bool.self, forKey: .hasMore)
  }

  public struct Distribution: Codable, Sendable, Equatable {
    public let actualStartDate: LocalDate
    public let sampleCount: Int
  }

  public struct Tail: Codable, Sendable, Equatable {
    public let side: Direction
    public let pct: Double
  }
}

/// C-a 지수 일봉 하나. 가격은 표시 자릿수+2, 이격도(%)는 3자리로 반올림한 값이다 (D-046)
public struct DisparityBar: Codable, Sendable, Equatable {
  public let tradeDate: LocalDate
  /// 산출 불가일은 모두 nil
  public let open: Double?
  public let high: Double?
  public let low: Double?
  public let close: Double?
  /// 초기 (이평선 기간−1)일과 산출 불가일은 nil
  public let ma: Double?
  public let disparity: Double?
  /// 한국형·미국형 롤 음영, 대표월물은 전환일
  public let inRoll: Bool
  /// 그날 보유 월물(전 거래일 종가 뒤 비중, 합 1). 만기순. 첫날은 빈 배열
  public let holdings: [Holding]

  public struct Holding: Codable, Sendable, Equatable {
    public let contractMonth: ContractMonth
    public let weight: Double
  }
}

/// rare 레벨 하나의 이격도와 오늘 rare-level 선 가격. 이평선이 없으면 `price`는 nil
public struct RareLevelLine: Codable, Sendable, Equatable {
  public let direction: Direction
  public let level: Double
  public let disparity: Double
  public let price: Double?
}
