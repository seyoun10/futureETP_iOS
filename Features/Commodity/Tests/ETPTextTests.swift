import Core
import Foundation
import Testing

@testable import Commodity

struct ETPTextTests {
  /// 키와 값을 그대로 보이는 가짜 번역(`etp.krwScheme`만 언어별 값)
  private static func t(scheme: String) -> ETPText.Translate {
    { key, values in
      switch key {
      case "etp.krwScheme": scheme
      case "etp.leverageValue": "\(values["n"]!)x"
      case "etp.amount.KRX": "\(values["n"]!) 원"
      case "etp.amount.US": "$\(values["n"]!)"
      case "etp.sortValue": "\(values["label"]!) \(values["amount"]!)"
      case "etp.noValue": "—"
      case "etp.seriesCode": "\(values["code"]!) 시리즈"
      case "etp.maturity": "만기 \(values["date"]!)"
      case "etp.expenseRatioValue": "\(values["n"]!)%"
      default: key
      }
    }
  }

  private static func etp(
    market: ETPMarket, leverage: Double = 1, aum: Double? = nil, tickers: [String] = []
  ) -> ETPSummary {
    ETPSummary(
      id: UUID(), market: market, type: .etf, leverage: leverage,
      fxHedge: market == .us ? .na : .hedged, name: "Gold", tickers: tickers, aum: aum,
      avgTradingValue: nil)
  }

  @Test func usTitleHasTickerFirst() {
    #expect(ETPText.title(Self.etp(market: .us, tickers: ["UGL"])) == "UGL  Gold")
    #expect(ETPText.title(Self.etp(market: .krx, tickers: ["123456"])) == "Gold")
  }

  @Test func leverageIsJSNumberText() {
    let t = Self.t(scheme: "eok")
    #expect(ETPText.leverage(1, t: t) == "1x")
    #expect(ETPText.leverage(-2, t: t) == "-2x")
    #expect(ETPText.leverage(1.5, t: t) == "1.5x")
  }

  @Test func attributesAppendSortValueInMarketCurrency() {
    let ko = Self.t(scheme: "eok")
    let krx = Self.etp(market: .krx, aum: 123_456_000_000)
    #expect(
      ETPText.attributes(krx, sort: .default, t: ko) == "KRX · ETF · 1x · etp.fxHedges.HEDGED")
    #expect(
      ETPText.attributes(krx, sort: .aum, t: ko)
        == "KRX · ETF · 1x · etp.fxHedges.HEDGED · etp.sorts.AUM 1,235억 원")
    #expect(
      ETPText.attributes(krx, sort: .tradingValue, t: ko).hasSuffix("etp.sorts.TRADING_VALUE —"))
    // 원은 en에서 si, 달러는 언어와 상관없이 si
    #expect(ETPText.amount(123_456_000_000, market: .krx, t: Self.t(scheme: "si")) == "123.5B 원")
    #expect(ETPText.amount(12_340_000, market: .us, t: ko) == "$12.3M")
  }

  @Test func seriesLinesAndIssuerURL() throws {
    let t = Self.t(scheme: "eok")
    let data = try JSONSerialization.data(withJSONObject: [
      "ticker": "530031", "seriesCode": "B", "maturityDate": "2031-03-15",
    ])
    let series = try JSONDecoder().decode(ETPSeries.self, from: data)
    #expect(ETPDetailRows.seriesLine(series, t: t) == "B 시리즈 · 530031 · 만기 2031-03-15")
    let etf = try JSONDecoder().decode(
      ETPSeries.self,
      from: JSONSerialization.data(withJSONObject: [
        "ticker": "UGL", "seriesCode": NSNull(), "maturityDate": NSNull(),
      ]))
    #expect(ETPDetailRows.seriesLine(etf, t: t) == "UGL")
  }
}
