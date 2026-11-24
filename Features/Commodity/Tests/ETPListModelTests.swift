import Core
import Foundation
import Testing

@testable import Commodity

struct ETPListModelTests {
  private static func etp(
    _ name: String, market: ETPMarket = .krx, type: ETPType = .etf, leverage: Double = 1,
    fxHedge: FXHedge = .hedged, aum: Double? = nil, avgTradingValue: Double? = nil
  ) -> ETPSummary {
    ETPSummary(
      id: UUID(), market: market, type: type, leverage: leverage, fxHedge: fxHedge, name: name,
      tickers: [], aum: aum, avgTradingValue: avgTradingValue)
  }

  private static let etps = [
    etp("UNG", market: .us, fxHedge: .na, aum: 900, avgTradingValue: 50),
    etp("KODEX 인버스", leverage: -1, aum: 10, avgTradingValue: 10),
    etp("레버리지 ETN", type: .etn, leverage: 2, fxHedge: .unhedged, aum: 300),
    etp("KODEX", aum: 200, avgTradingValue: 30),
    etp("BOIL", market: .us, leverage: 2, fxHedge: .na, aum: 100, avgTradingValue: 70),
    etp("KOSEF", leverage: -2, avgTradingValue: 20),
  ]

  private static func names(_ etps: [ETPSummary]) -> [String] { etps.map(\.name) }

  @Test func defaultSortIsMarketLeverageName() {
    #expect(
      Self.names(ETPListModel.sort(Self.etps, by: .default))
        == ["KODEX", "레버리지 ETN", "KODEX 인버스", "KOSEF", "UNG", "BOIL"])
  }

  @Test func valueSortsAreDescendingWithinMarketWithMissingLast() {
    #expect(
      Self.names(ETPListModel.sort(Self.etps, by: .aum))
        == ["레버리지 ETN", "KODEX", "KODEX 인버스", "KOSEF", "UNG", "BOIL"])
    #expect(
      Self.names(ETPListModel.sort(Self.etps, by: .tradingValue))
        == ["KODEX", "KOSEF", "KODEX 인버스", "레버리지 ETN", "BOIL", "UNG"])
  }

  @Test func filtersAllFourAndNilKeepsAll() {
    #expect(ETPListModel.filter(Self.etps, by: ETPFilters()).count == 6)
    #expect(
      Self.names(ETPListModel.filter(Self.etps, by: ETPFilters(market: .us))) == ["UNG", "BOIL"])
    #expect(Self.names(ETPListModel.filter(Self.etps, by: ETPFilters(type: .etn))) == ["레버리지 ETN"])
    #expect(
      Self.names(ETPListModel.filter(Self.etps, by: ETPFilters(leverage: 2)))
        == ["레버리지 ETN", "BOIL"])
    #expect(
      Self.names(
        ETPListModel.filter(
          Self.etps, by: ETPFilters(market: .krx, leverage: -1, fxHedge: .hedged)))
        == ["KODEX 인버스"])
  }

  @Test func leverageOptionsAreThoseReceivedInDefaultOrder() {
    #expect(ETPListModel.leverageOptions(Self.etps) == [1, 2, -1, -2])
  }

  @Test func sortValueIsNotAttachedForDefault() {
    #expect(ETPListModel.sortValue(Self.etps[0], .default) == .none)
    #expect(ETPListModel.sortValue(Self.etps[0], .aum) == .some(900))
    #expect(ETPListModel.sortValue(Self.etps[2], .tradingValue) == .some(nil))
  }
}
