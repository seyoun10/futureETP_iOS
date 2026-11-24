import Core
import Foundation
import Testing

@testable import Commodity

private func decodeCurve(_ object: [String: Any]) throws -> Curve {
  try JSONDecoder.api().decode(Curve.self, from: JSONSerialization.data(withJSONObject: object))
}

private func point(
  _ month: String, base: Double?, current: Double?, pct: Double? = nil
) -> [String: Any] {
  [
    "symbol": "CL", "contractMonth": month, "basePrice": base ?? NSNull(),
    "currentPrice": current ?? NSNull(), "changePct": pct ?? NSNull(),
  ]
}

/// 커브 응답. 기준일이 `maxBaseDate`(D-1)면 다음 날짜가 없다
private func curve(
  baseDate: String = "2026-11-20", prev: String? = "2026-11-19", next: String? = nil,
  points: [[String: Any]] = [point("2026-12", base: 60, current: 61, pct: 1.6667)]
) throws -> Curve {
  try decodeCurve([
    "freshness": [
      "asOf": "2026-11-24T04:05:36.946Z", "tradeDate": "2026-11-23", "delayed": false,
      "marketState": "CLOSED", "nextUpdateAt": "2099-01-01T00:00:00.000Z",
    ],
    "priceDecimals": 2, "baseDate": baseDate, "baseOffset": 1, "prevBaseDate": prev ?? NSNull(),
    "nextBaseDate": next ?? NSNull(), "minBaseDate": "2010-06-07",
    "maxBaseDate": "2026-11-20", "compareDate": "2026-11-23", "points": points,
    "current": NSNull(), "base": NSNull(),
  ])
}

private func date(_ string: String) -> LocalDate { LocalDate(string)! }

/// 글자 폭은 한 글자 6pt로 센다
private func measure(_ text: String) -> Double { Double(text.count) * 6 }

@Suite struct CurveChartLayoutTests {
  private func points(_ values: [(Double?, Double?, Double?)]) -> [CurveChartLayout.Point] {
    values.enumerated().map { i, v in
      CurveChartLayout.Point(
        label: "27\(i)", contractMonth: ContractMonth(year: 2027, month: i + 1)!, base: v.0,
        current: v.1, changePct: v.2)
    }
  }

  @Test func noPricesOrWidthMeansNoLayout() {
    let empty = points([(nil, nil, nil)])
    #expect(
      CurveChartLayout(
        points: empty, priceDecimals: 2, size: CGSize(width: 300, height: 200), insetTop: 0)
        == nil)
    #expect(
      CurveChartLayout(
        points: points([(1, 2, 3)]), priceDecimals: 2, size: .zero, insetTop: 0) == nil)
  }

  @Test func slotsSpanThePlotLeftOfTheAxis() throws {
    let layout = try #require(
      CurveChartLayout(
        points: points([(60, 61, 1), (62, 63, 1), (64, 65, 1)]), priceDecimals: 2,
        size: CGSize(width: 300, height: 200), insetTop: 20, measure: measure))
    // 눈금 글자 `66`(2자)+여백 10과 십자선 `65.00`(5자)+상자 여백 7 중 넓은 쪽
    #expect(layout.right == 300 - 37)
    #expect(layout.slot == layout.right / 3)
    #expect(layout.x(0) == layout.slot / 2)
    #expect(layout.nearestIndex(x: -10) == 0)
    #expect(layout.nearestIndex(x: 1000) == 2)
    #expect(layout.isLog)
    // 선·점은 정보 줄 아래에서 시작하고 위아래 8% 여백을 둔다
    #expect(layout.y(65) > layout.dataTop)
    #expect(layout.y(60) < layout.plotBottom)
    #expect(layout.dataTop == CurveChartLayout.top + 20)
    #expect(layout.plotBottom == 200 - CurveChartLayout.bottom)
  }

  @Test func linearAxisWhenAValueIsNotPositive() throws {
    let layout = try #require(
      CurveChartLayout(
        points: points([(-37.63, 10, nil), (20, 21, 5)]), priceDecimals: 2,
        size: CGSize(width: 300, height: 200), insetTop: 0, measure: measure))
    #expect(!layout.isLog)
    #expect(layout.y(-37.63) > layout.y(21))
  }

  @Test func pctLabelsSitAboveRisesAndBelowFalls() throws {
    let layout = try #require(
      CurveChartLayout(
        points: points([(60, 62, 3.3), (64, 62, -3.1), (70, 70, -0.04)]), priceDecimals: 2,
        size: CGSize(width: 300, height: 300), insetTop: 0, measure: measure))
    let labels = layout.pctLabels(measure: measure)
    #expect(labels.map(\.text) == ["+3.3%", "-3.1%", "0.0%"])
    // 오르면 점(위쪽 점) 위, 내리면 점(아래쪽 점) 아래, 0.0%는 위
    #expect(labels[0].y <= layout.y(62) - CurveChartLayout.dot)
    #expect(labels[1].y - Double(ChartLayout.fontSize) >= layout.y(62) + CurveChartLayout.dot)
    #expect(labels[2].y <= layout.y(70) - CurveChartLayout.dot)
  }

  @Test func roundsNegativeUsesShownDigits() {
    #expect(CurveChartLayout.roundsNegative(-0.06, decimals: 1))
    #expect(!CurveChartLayout.roundsNegative(-0.04, decimals: 1))
    #expect(!CurveChartLayout.roundsNegative(0.5, decimals: 1))
  }

  @Test func segmentsBreakAtMissingValues() throws {
    let layout = try #require(
      CurveChartLayout(
        points: points([(60, 61, nil), (nil, 62, nil), (64, 63, nil)]), priceDecimals: 2,
        size: CGSize(width: 300, height: 200), insetTop: 0, measure: measure))
    // 기준일 선은 가운데가 빠져 끊기고, 비교일 선은 두 선분이다
    #expect(layout.segments.count == 2)
    #expect(layout.crosshairValue(1) == 62)
    #expect(layout.crosshairValue(5) == nil)
  }

  @Test func markSpansCoverDotsAndLinesInRange() throws {
    let layout = try #require(
      CurveChartLayout(
        points: points([(60, nil, nil), (70, nil, nil)]), priceDecimals: 2,
        size: CGSize(width: 300, height: 200), insetTop: 0, measure: measure))
    let mid = (layout.x(0) + layout.x(1)) / 2
    // 점 사이 가운데 1pt 구간은 선분만 지난다
    let spans = layout.markSpans(x0: mid, x1: mid + 1, pctLabels: [])
    #expect(spans.count == 1)
    #expect(spans[0].contains((layout.y(60) + layout.y(70)) / 2 - 0.5))
    #expect(layout.markSpans(x0: -100, x1: -50, pctLabels: []).isEmpty)
  }
}

@Suite struct CurveDetailTests {
  private let t: DisparityInfo.Translate = { key, values in
    values.isEmpty ? key : "\(key)\(values)"
  }

  @Test func rowsSkipValuesMissingFromACurve() throws {
    let data = try curve(points: [
      point("2026-12", base: 60, current: 61.5, pct: 2.5),
      point("2027-01", base: nil, current: 62, pct: nil),
    ])
    #expect(
      CurveDetail.rows(data, index: 0, t: t) == [
        .single(.init(label: "DEC26", value: nil)),
        .single(.init(label: "11/20", value: "60.00")),
        .single(.init(label: "11/23", value: "61.50")),
        .single(.init(label: "curve.tooltipChange", value: "+2.5%")),
      ])
    #expect(
      CurveDetail.rows(data, index: 1, t: t) == [
        .single(.init(label: "JAN27", value: nil)),
        .single(.init(label: "11/23", value: "62.00")),
      ])
    #expect(CurveDetail.rows(data, index: 2, t: t).isEmpty)
  }
}

/// 기준일별 응답을 돌려주는 가짜 repository. 응답이 없는 기준일은 끝나지 않는다(받는 중)
private final class FakeCurves: CurveRepository, @unchecked Sendable {
  var responses: [LocalDate?: Curve] = [:]

  func fetchCurve(_ code: CommodityCode, query: CurveQuery) async throws -> Curve {
    if let curve = responses[query.baseDate] { return curve }
    try await Task.sleep(for: .seconds(60))
    throw CancellationError()
  }
}

@MainActor
@Suite struct CurveScreenModelTests {
  private func make(_ fake: FakeCurves) -> CurveScreenModel {
    let cache = QueryCache()
    let queries = CommodityQueries(
      disparity: { _, _ in fatalError() }, contracts: { _ in fatalError() },
      curve: { cache.curve(fake, code: $0, baseDate: $1) }, etps: { _ in fatalError() })
    return CurveScreenModel(code: .cl, queries: queries)
  }

  @Test func keepsThePreviousCurveWhileTheNewBaseDateLoads() async throws {
    let fake = FakeCurves()
    let latest = try curve()
    fake.responses[nil] = latest
    let model = make(fake)
    await model.query.refetch()
    #expect(model.state.data == latest)

    model.changeBaseDate(date("2026-11-19"))
    #expect(model.baseDate == date("2026-11-19"))
    #expect(model.state.data == latest)
    #expect(model.isPlaceholder)

    let older = try curve(baseDate: "2026-11-19", prev: "2026-11-18", next: "2026-11-20")
    fake.responses[date("2026-11-19")] = older
    await model.query.refetch()
    #expect(model.state.data == older)
    #expect(!model.isPlaceholder)
  }

  @Test func pickingTheLatestBaseDateUsesTheDefaultKey() async throws {
    let fake = FakeCurves()
    fake.responses[nil] = try curve()
    let model = make(fake)
    model.changeBaseDate(date("2026-11-19"))
    model.pickBaseDate(date("2026-11-20"), maxBaseDate: date("2026-11-20"))
    #expect(model.baseDate == nil)
    await model.query.refetch()
    // 고른 날짜 그대로 왔으면 안내하지 않는다
    #expect(model.movedTo == nil)
  }

  @Test func announcesAMovedBaseDateAfterItArrives() async throws {
    let fake = FakeCurves()
    // 휴장일 11/21(토)을 고르면 서버가 11/20으로 옮긴다
    fake.responses[date("2026-11-21")] = try curve(baseDate: "2026-11-20")
    let model = make(fake)
    model.pickBaseDate(date("2026-11-21"), maxBaseDate: date("2026-11-22"))
    #expect(model.movedTo == nil)
    await model.query.refetch()
    #expect(model.movedTo == date("2026-11-20"))
    model.clearMoved()
    #expect(model.movedTo == nil)
    // 버튼으로 옮기면 안내를 지운다
    model.pickBaseDate(date("2026-11-21"), maxBaseDate: date("2026-11-22"))
    model.changeBaseDate(nil)
    #expect(model.picked == nil)
  }

  @Test func nextBaseDateOfDMinusOneIsTheDefaultKey() throws {
    #expect(CurveScreenModel.next(of: try curve(next: "2026-11-20")) == .some(nil))
    #expect(
      CurveScreenModel.next(of: try curve(baseDate: "2026-11-18", next: "2026-11-19"))
        == .some(date("2026-11-19")))
    #expect(CurveScreenModel.next(of: try curve()) == nil)
  }
}

@Suite struct BaseDateSheetTests {
  @Test func pickerDateRoundTripsInAnyTimeZone() {
    for zone in ["Asia/Seoul", "America/Chicago", "Pacific/Kiritimati"] {
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = TimeZone(identifier: zone)!
      let day = date("2026-11-20")
      let picked = BaseDateSheet.pickerDate(day, calendar: calendar)
      #expect(BaseDateSheet.localDate(picked, calendar: calendar) == day)
    }
  }
}
