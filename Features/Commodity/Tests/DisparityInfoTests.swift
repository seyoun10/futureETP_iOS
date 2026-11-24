import Core
import Foundation
import Testing

@testable import Commodity

/// 문구 대신 `key{name=value}`를 돌려준다
private let t: DisparityInfo.Translate = { key, values in
  values.isEmpty
    ? key
    : key + "{"
      + values.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
      .joined(separator: ",") + "}"
}

private func bar(
  _ date: String, open: Double = 10, high: Double = 12, low: Double = 8, close: Double = 10,
  disparity: Double? = nil, inRoll: Bool = false, holdings: [String] = []
) -> [String: Any] {
  [
    "tradeDate": date, "open": open, "high": high, "low": low, "close": close, "ma": NSNull(),
    "disparity": disparity ?? NSNull(), "inRoll": inRoll,
    "holdings": holdings.map { ["contractMonth": $0, "weight": 1 / Double(holdings.count)] },
  ]
}

private func chart(
  basis: String = "KR", fallback: Bool = false, tail: (String, Double)? = nil,
  bars: [[String: Any]]
) throws -> DisparityChart {
  let object: [String: Any] = [
    "freshness": [
      "asOf": "2026-11-24T03:46:00Z", "tradeDate": "2026-11-23", "delayed": false,
      "marketState": "OPEN", "nextUpdateAt": NSNull(),
    ],
    "priceDecimals": 3, "basis": basis, "fallback": fallback, "maPeriod": 200,
    "window": "ALL", "distribution": NSNull(), "rareLevels": [],
    "currentTail": tail.map { ["side": $0.0, "pct": $0.1] as [String: Any] } ?? NSNull(),
    "provisional": false, "bars": bars, "hasMore": false,
  ]
  return try JSONDecoder.api().decode(
    DisparityChart.self, from: JSONSerialization.data(withJSONObject: object))
}

private func model(_ data: DisparityChart) -> DisparityChartModel {
  DisparityChartModel(basis: data.basis, bars: data.bars, rareLevels: data.rareLevels)
}

struct DisparityInfoTests {
  @Test func basisLabelShowsTheFrontContract() throws {
    let data = try chart(basis: "FRONT", bars: [bar("2026-11-23", holdings: ["2026-12"])])
    let today = try #require(model(data).bars.last)
    #expect(DisparityInfo.basisLabel(data, today: today, t: t) == "settings.basisFRONT DEC26")
  }

  @Test func basisLabelMarksFallbackAndRoll() throws {
    let fallback = try chart(basis: "FRONT", fallback: true, bars: [bar("2026-11-23")])
    let today = try #require(model(fallback).bars.last)
    #expect(
      DisparityInfo.basisLabel(fallback, today: today, t: t)
        == "disparity.basisFallback{basis=settings.basisFRONT}")
    let rolling = try chart(bars: [bar("2026-11-23", inRoll: true)])
    let rollDay = try #require(model(rolling).bars.last)
    #expect(
      DisparityInfo.basisLabel(rolling, today: rollDay, t: t)
        == "disparity.basisInRoll{basis=settings.basisKR}")
  }

  @Test func ohlcUsesPriceDecimals() throws {
    let data = try chart(bars: [
      bar("2026-11-23", open: 3.151, high: 3.184, low: 3.098, close: 3.12)
    ])
    let today = try #require(model(data).bars.last)
    #expect(
      DisparityInfo.ohlc(today, decimals: 3, t: t)
        == "disparity.open3.151 disparity.high3.184 disparity.low3.098 disparity.close3.120")
  }

  @Test func hintsAddFallbackAndSameAsKR() throws {
    let fallback = try chart(basis: "FRONT", fallback: true, bars: [])
    #expect(
      DisparityInfo.hints(fallback, code: .ng, requestedBasis: .us, t: t) == [
        "disparity.hint.FRONT", "disparity.hint.fallback{basis=settings.basisUS}",
      ])
    let us = try chart(basis: "US", bars: [])
    #expect(
      DisparityInfo.hints(us, code: .gc, requestedBasis: .us, t: t) == [
        "disparity.hint.adjusted{basis=settings.basisUS}", "disparity.hint.sameAsKR",
      ])
    #expect(DisparityInfo.hints(us, code: .cl, requestedBasis: .us, t: t).count == 1)
  }

  @Test func statsUseTheTailAndVisibleBars() throws {
    let data = try chart(
      tail: ("DOWN", 9),
      bars: [
        bar("2026-11-19", high: 20, low: 5), bar("2026-11-20", high: 16, low: 8),
        bar("2026-11-23", high: 12, low: 8, close: 10, disparity: -18.71),
      ])
    #expect(
      DisparityInfo.stats(data, chart: model(data), visible: 1...2, t: t)
        == "disparity.disparity{value=-18.7%} (disparity.tailDOWN{pct=9})"
        + " · disparity.fromLow{pct=+25.00%} · disparity.fromHigh{pct=-37.50%}")
    // 봉이 줄어든 뒤의 옛 범위는 봉 안으로 자른다
    #expect(
      DisparityInfo.stats(data, chart: model(data), visible: 0...9, t: t)
        .hasSuffix("fromLow{pct=+100.00%} · disparity.fromHigh{pct=-50.00%}"))
  }
}
