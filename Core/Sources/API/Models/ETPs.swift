import Foundation

/// `GET /v1/commodities/:code/etps` 응답 `data` (계약 `schemas/etpList.json`, D-017).
/// 필터·정렬은 앱에서 한다
public struct ETPList: Codable, Sendable, Equatable {
  /// 상품 정보를 마지막으로 받은 시각. 상품이 없으면 nil
  public let asOf: Date?
  /// 매핑 전 후보·상장폐지 상품은 빠진다
  public let etps: [ETPSummary]
}

/// C-d 목록 한 줄
public struct ETPSummary: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let market: ETPMarket
  public let type: ETPType
  /// 예: 1, 2, -1, -2
  public let leverage: Double
  public let fxHedge: FXHedge
  /// 원문
  public let name: String
  /// 상장 중 시리즈 종목코드(ETN 후속 시리즈가 겹치면 여럿)
  public let tickers: [String]
  /// 통화는 `market`으로 정해진다(KRX 원, US 달러). 아직 못 받았으면 nil
  public let aum: Double?
  public let avgTradingValue: Double?

  public init(
    id: UUID, market: ETPMarket, type: ETPType, leverage: Double, fxHedge: FXHedge, name: String,
    tickers: [String], aum: Double?, avgTradingValue: Double?
  ) {
    self.id = id
    self.market = market
    self.type = type
    self.leverage = leverage
    self.fxHedge = fxHedge
    self.name = name
    self.tickers = tickers
    self.aum = aum
    self.avgTradingValue = avgTradingValue
  }
}

/// `GET /v1/etps/:id` 응답 `data` (계약 `schemas/etpDetail.json`, C-d-a).
/// 자동 수집 정보라 원문 언어 그대로다
public struct ETPDetail: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let market: ETPMarket
  public let type: ETPType
  public let leverage: Double
  public let fxHedge: FXHedge
  public let name: String
  public let tickers: [String]
  public let aum: Double?
  public let avgTradingValue: Double?
  public let commodityCode: CommodityCode
  /// `name`의 언어
  public let nameLang: AppLanguage
  public let issuer: String?
  public let underlyingIndex: String?
  /// 총보수 %
  public let expenseRatio: Double?
  public let issuerUrl: String?
  /// 첫 시리즈 상장일. 모르면 nil
  public let listedDate: LocalDate?
  /// 상장 중 시리즈만
  public let series: [ETPSeries]
  public let collectedAt: Date
}

/// C-d-a 시리즈 한 줄
public struct ETPSeries: Codable, Sendable, Equatable {
  public let ticker: String
  /// ETN A/B…, ETF는 nil
  public let seriesCode: String?
  public let maturityDate: LocalDate?
}
