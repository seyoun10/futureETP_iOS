import Core
import Foundation
import SwiftUI
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

private let palette = UpDownPalette(.kr)

private func bar(
  _ date: String, close: Double = 10, ma: Double? = nil, disparity: Double? = nil,
  holdings: [(String, Double)] = []
) -> [String: Any] {
  [
    "tradeDate": date, "open": 10, "high": 12, "low": 8, "close": close, "ma": ma ?? NSNull(),
    "disparity": disparity ?? NSNull(), "inRoll": false,
    "holdings": holdings.map { ["contractMonth": $0.0, "weight": $0.1] },
  ]
}

private func chart(
  basis: String = "KR", rareLevels: [(String, Double, Double)] = [], bars: [[String: Any]]
) throws -> DisparityChart {
  let object: [String: Any] = [
    "freshness": [
      "asOf": "2026-11-24T03:46:00Z", "tradeDate": "2026-11-23", "delayed": false,
      "marketState": "OPEN", "nextUpdateAt": NSNull(),
    ],
    "priceDecimals": 3, "basis": basis, "fallback": false, "maPeriod": 200,
    "window": "ALL", "distribution": NSNull(),
    "rareLevels": rareLevels.map {
      ["direction": $0.0, "level": $0.1, "disparity": $0.2, "price": NSNull()] as [String: Any]
    },
    "currentTail": NSNull(), "provisional": false, "bars": bars, "hasMore": false,
  ]
  return try JSONDecoder.api().decode(
    DisparityChart.self, from: JSONSerialization.data(withJSONObject: object))
}

private func rows(_ data: DisparityChart, at index: Int) -> [DetailRow] {
  let model = DisparityChartModel(basis: data.basis, bars: data.bars, rareLevels: data.rareLevels)
  return DisparityDetail.rows(model, index: index, data: data, palette: palette, t: t)
}

private func cells(_ rows: [DetailRow]) -> [DetailRow.Cell] {
  rows.flatMap { row -> [DetailRow.Cell] in
    switch row {
    case .single(let cell): [cell]
    case .pair(let left, let right): [left, right]
    }
  }
}

struct DisparityDetailTests {
  @Test func firstBarShowsDateHoldingsAndOhlcWithoutPreviousChange() throws {
    let data = try chart(bars: [bar("2026-11-23", holdings: [("2026-12", 0.6), ("2027-01", 0.4)])])
    let result = rows(data, at: 0)
    #expect(
      result == [
        .single(.init(label: "2026-11-23", value: "DEC26 60% · JAN27 40%")),
        .pair(
          .init(label: "disparity.open", value: "10.000"),
          .init(label: "disparity.high", value: "12.000")),
        .pair(
          .init(label: "disparity.close", value: "10.000"),
          .init(label: "disparity.low", value: "8.000")),
      ])
  }

  @Test func previousChangeAndDisparityUseUpDownColors() throws {
    let data = try chart(bars: [
      bar("2026-11-20", close: 10), bar("2026-11-23", close: 10.5, disparity: -3.2),
    ])
    let result = cells(rows(data, at: 1))
    let change = try #require(result.first { $0.label == "disparity.prevChange" })
    #expect(change.value == "+0.500 (+5.00%)")
    #expect(change.color == palette.up)
    let disparity = try #require(result.first { $0.label == "disparity.disparityLabel" })
    #expect(disparity.value == "-3.2%")
    #expect(disparity.color == palette.down)
  }

  @Test func frontSwitchDayAppendsTheNewContract() throws {
    let data = try chart(
      basis: "FRONT",
      bars: [
        bar("2026-11-20", holdings: [("2026-12", 1)]),
        bar("2026-11-23", holdings: [("2027-02", 1)]),
      ])
    #expect(cells(rows(data, at: 0)).first?.value == "DEC26 → FEB27")
    #expect(cells(rows(data, at: 1)).first?.value == "FEB27")
  }

  @Test func lineValuesAreSortedByPriceWithLineNames() throws {
    let data = try chart(
      rareLevels: [("UP", 5, 20), ("DOWN", 2.5, -10)],
      bars: [bar("2026-11-23", ma: 10)])
    let lines = cells(rows(data, at: 0)).suffix(3)
    #expect(
      lines.map(\.label) == [
        "disparity.tailUP{pct=5}", "disparity.ma{n=200}", "disparity.tailDOWN{pct=2.5}",
      ])
    #expect(lines.map(\.value) == ["12.000", "10.000", "9.000"])
    #expect(lines.dropFirst().first?.color == Theme.ChartColors.movingAverage)
  }

  @Test func outOfRangeIndexHasNoRows() throws {
    #expect(rows(try chart(bars: [bar("2026-11-23")]), at: 3).isEmpty)
  }
}
