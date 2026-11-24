import Foundation

/// A·C 조회 응답 `data`의 기준 정보 (계약 `freshness`, D-042, D-048)
public struct Freshness: Codable, Sendable, Equatable {
  /// 데이터 기준 시각
  public let asOf: Date
  /// CME 거래일
  public let tradeDate: LocalDate
  public let delayed: Bool
  public let marketState: MarketState
  /// 다음 갱신 예정 시각. 정해지지 않았으면 nil
  public let nextUpdateAt: Date?

  public init(
    asOf: Date, tradeDate: LocalDate, delayed: Bool, marketState: MarketState,
    nextUpdateAt: Date?
  ) {
    self.asOf = asOf
    self.tradeDate = tradeDate
    self.delayed = delayed
    self.marketState = marketState
    self.nextUpdateAt = nextUpdateAt
  }
}
