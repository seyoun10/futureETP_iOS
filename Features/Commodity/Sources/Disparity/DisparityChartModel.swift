import Core
import SwiftUI

/// C-a 응답 → 캔들 차트 입력(봉·이평선·rare-level 밴드·롤 표시)과 화면 값 계산. 순수 값이다
/// (RN `disparitySeries.ts`·`disparityChartModel.ts`, screens.md C-a, D-086)
struct DisparityChartModel {
  /// OHLC가 모두 있는 봉. 산출 불가일은 차트에서 뺀다(x는 봉 순번이라 빈칸 없이 이어진다)
  struct Bar: Equatable, Sendable {
    let tradeDate: LocalDate
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let ma: Double?
    let disparity: Double?
    let inRoll: Bool
    let holdings: [DisparityBar.Holding]

    init?(_ bar: DisparityBar) {
      guard let open = bar.open, let high = bar.high, let low = bar.low, let close = bar.close
      else { return nil }
      tradeDate = bar.tradeDate
      self.open = open
      self.high = high
      self.low = low
      self.close = close
      ma = bar.ma
      disparity = bar.disparity
      inRoll = bar.inRoll
      holdings = bar.holdings
    }
  }

  /// 십자선 상세에 쓰는 선 이름: 이평선, 또는 rare-level 방향·레벨
  enum LineLabel: Equatable, Sendable {
    case movingAverage
    case band(direction: Direction, level: Double)
  }

  typealias RollMarks = ChartRollMarks
  typealias PriceLabel = ChartPriceLabel

  /// 보이는 봉의 최고가·최저가 봉과 현재가 기준 저점대비(LC)·고점대비(HC) %
  struct VisibleStats: Equatable, Sendable {
    let highIndex: Int
    let lowIndex: Int
    let fromLowPct: Double
    let fromHighPct: Double
  }

  static let movingAverageWidth = 2.5
  static let bandWidth = 1.0

  let basis: Basis
  let bars: [Bar]
  /// 밴드 다음 이평선 순서(이평선이 위에 그려진다). `lineLabels`와 같은 순서
  let series: CandleSeries
  /// 봉 순번별 거래일(x축 월 눈금·십자선 날짜)
  let dates: [LocalDate]
  /// 봉·선 전체의 가장 큰 값(y축 자리 폭)
  let maxPrice: Double
  let lineLabels: [LineLabel]
  let roll: RollMarks
  /// 대표월물 전환일 봉 순번 → 새 월물명(십자선 상세용)
  let frontSwitchAt: [Int: String]

  init(basis: Basis, bars source: [DisparityBar], rareLevels: [RareLevelLine]) {
    self.basis = basis
    let bars = source.compactMap(Bar.init)
    self.bars = bars
    let bands = Self.bandLines(bars: bars, rareLevels: rareLevels)
    let lines =
      bands.map { band in
        CandleSeries.Line(
          id: band.id, values: band.values, color: Self.bandColor(rank: band.rank),
          width: Self.bandWidth)
      } + [
        CandleSeries.Line(
          id: "ma", values: bars.map(\.ma), color: Theme.ChartColors.movingAverage,
          width: Self.movingAverageWidth)
      ]
    lineLabels =
      bands.map { .band(direction: $0.direction, level: $0.level) } + [.movingAverage]
    series = CandleSeries(
      bars: bars.map { .init(open: $0.open, high: $0.high, low: $0.low, close: $0.close) },
      lines: lines)
    dates = bars.map(\.tradeDate)
    maxPrice = series.high.max() ?? 1
    // 실제로 그린 기준값의 롤 정보만
    if basis == .front {
      let switches = Self.frontSwitches(bars)
      roll = RollMarks(switches: switches.map(\.index))
      frontSwitchAt = Dictionary(
        uniqueKeysWithValues: switches.map {
          ($0.index, NumberFormat.contractMonth($0.contractMonth))
        })
    } else {
      roll = RollMarks(shading: Self.rollSegments(bars))
      frontSwitchAt = [:]
    }
  }

  // MARK: - 계열

  struct BandLine: Equatable {
    let id: String
    let direction: Direction
    let level: Double
    /// 0 = 가장 덜 드문 레벨(옅음) … 레벨 수−1 = 가장 드문 레벨(진함). 색은 레벨 값이 아니라 순위로 고른다
    let rank: Int
    /// 이평선(t) × (1 + 레벨 이격도/100). 이평선이 없는 날은 nil
    let values: [Double?]
  }

  static func bandLines(bars: [Bar], rareLevels: [RareLevelLine]) -> [BandLine] {
    rareLevels.map { line in
      // 응답은 방향마다 레벨 오름차순이라, 같은 방향 안에서 작은 레벨(드묾)일수록 순위가 높다
      let same = rareLevels.filter { $0.direction == line.direction }
      let position = same.firstIndex { $0.level == line.level } ?? 0
      return BandLine(
        id: "\(line.direction.rawValue)-\(RareLevels.text(line.level))",
        direction: line.direction, level: line.level, rank: same.count - 1 - position,
        values: bars.map { bar in bar.ma.map { $0 * (1 + line.disparity / 100) } })
    }
  }

  static func bandColor(rank: Int) -> Color {
    let colors = Theme.ChartColors.rareLevels
    return colors[min(max(rank, 0), colors.count - 1)]
  }

  /// 이어진 롤 중 봉을 구간 하나로 묶는다(한국형·미국형 음영)
  static func rollSegments(_ bars: [Bar]) -> [ClosedRange<Int>] {
    var segments: [ClosedRange<Int>] = []
    for (i, bar) in bars.enumerated() where bar.inRoll {
      if let last = segments.last, last.upperBound == i - 1 {
        segments[segments.count - 1] = last.lowerBound...i
      } else {
        segments.append(i...i)
      }
    }
    return segments
  }

  /// 대표월물 전환일과 새 월물(D-103). 봉 t의 보유 월물은 t−1 종가 뒤 비중이라,
  /// 보유 월물이 바뀐 봉의 바로 앞 봉(옛 월물의 마지막 날)이 전환일이다
  static func frontSwitches(_ bars: [Bar]) -> [(index: Int, contractMonth: ContractMonth)] {
    guard bars.count > 1 else { return [] }
    return (1..<bars.count).compactMap { i in
      guard let previous = bars[i - 1].holdings.first?.contractMonth,
        let current = bars[i].holdings.first?.contractMonth, previous != current
      else { return nil }
      return (i - 1, current)
    }
  }

  // MARK: - 화면 값

  /// 우측 y축 라벨 자리
  func yLabelWidth(decimals: Int) -> Double {
    CandleAxes.yLabelWidth(maxPrice: maxPrice, decimals: decimals)
  }

  /// 보이는 봉 `indices`의 최고가·최저가 봉과 현재가(마지막 봉 종가) 대비 % (screens.md C-a)
  func visibleStats(_ indices: ClosedRange<Int>) -> VisibleStats? {
    guard let current = bars.last, indices.lowerBound >= 0, indices.upperBound < bars.count
    else { return nil }
    var highIndex = indices.lowerBound
    var lowIndex = indices.lowerBound
    for i in indices {
      if bars[i].high > bars[highIndex].high { highIndex = i }
      if bars[i].low < bars[lowIndex].low { lowIndex = i }
    }
    return VisibleStats(
      highIndex: highIndex, lowIndex: lowIndex,
      fromLowPct: (current.close / bars[lowIndex].low - 1) * 100,
      fromHighPct: (current.close / bars[highIndex].high - 1) * 100)
  }

  /// y축 특수 라벨: 마지막 봉 종가(흰색), 봉 `index`(보이는 마지막 봉)의 종가(회색)와 이평선·rare-level 값(선 색).
  /// 보이는 마지막 봉이 마지막 봉이면 종가는 흰색 하나만 (screens.md C-a y축 라벨)
  func priceLabels(at index: Int) -> [PriceLabel] {
    guard bars.indices.contains(index), let last = bars.last else { return [] }
    var labels = [PriceLabel(id: "last", price: last.close, color: Theme.ChartColors.lastPrice)]
    if index != bars.count - 1 {
      labels.append(
        PriceLabel(id: "current", price: bars[index].close, color: Theme.ChartColors.currentPrice))
    }
    for line in series.lines {
      if let price = line.values[index] {
        labels.append(PriceLabel(id: line.id, price: price, color: line.color))
      }
    }
    return labels
  }

  /// 십자선 상세의 월물 구성: 대표월물은 월물명, 한국형·미국형은 `DEC26 60% · JAN27 40%`. 보유 월물이 없으면(첫날) nil
  static func holdingsText(_ bar: Bar, basis: Basis) -> String? {
    guard let first = bar.holdings.first else { return nil }
    if basis == .front { return NumberFormat.contractMonth(first.contractMonth) }
    return bar.holdings
      .map {
        "\(NumberFormat.contractMonth($0.contractMonth)) \(Int(($0.weight * 100).rounded()))%"
      }
      .joined(separator: " · ")
  }

  /// 꼬리 백분위 표시값. 1% 미만은 소수 첫째 자리까지 보여 0%로 뭉개지지 않게 한다
  static func tailPct(_ pct: Double) -> String {
    pct < 1 ? NumberFormat.toFixed(pct, decimals: 1) : String(Int(pct.rounded()))
  }
}
