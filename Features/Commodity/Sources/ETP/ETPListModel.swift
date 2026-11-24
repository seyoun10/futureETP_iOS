import Core
import Foundation

/// C-d 정렬 기준 (RN `lib/etpSort.ts`). 문구 키 `etp.sorts.<rawValue>`
enum ETPSort: String, CaseIterable, Sendable {
  case `default` = "DEFAULT"
  case aum = "AUM"
  case tradingValue = "TRADING_VALUE"
}

/// C-d 필터. nil은 거르지 않는다(전체). 선택은 기억하지 않는다 (D-017, RN `etpListModel.ts`)
struct ETPFilters: Equatable, Sendable {
  var market: ETPMarket?
  var type: ETPType?
  var leverage: Double?
  var fxHedge: FXHedge?
}

enum ETPListModel {
  static func filter(_ etps: [ETPSummary], by filters: ETPFilters) -> [ETPSummary] {
    etps.filter { etp in
      (filters.market == nil || etp.market == filters.market)
        && (filters.type == nil || etp.type == filters.type)
        && (filters.leverage == nil || etp.leverage == filters.leverage)
        && (filters.fxHedge == nil || etp.fxHedge == filters.fxHedge)
    }
  }

  /// 배수 순서: 양수 먼저, 각각 절댓값 오름차순(1, 2, -1, -2)
  static func leverageOrder(_ a: Double, _ b: Double) -> ComparisonResult {
    if (a < 0) != (b < 0) { return a < 0 ? .orderedDescending : .orderedAscending }
    return compare(abs(a), abs(b))
  }

  /// 기본: 시장(KRX → US), 배수, 이름순. 순자산·거래대금은 통화가 달라 시장 안에서만 큰 순서이고 값이 없으면 뒤로 (D-017)
  static func sort(_ etps: [ETPSummary], by sort: ETPSort) -> [ETPSummary] {
    etps.sorted { a, b in
      let order: ComparisonResult =
        switch sort {
        case .default: byDefault(a, b)
        case .aum, .tradingValue:
          byMarket(a, b).then(byValueDescending(value(a, sort), value(b, sort))).then(
            byDefault(a, b))
        }
      return order == .orderedAscending
    }
  }

  /// 배수 필터 선택지: 받은 상품에 있는 배수만
  static func leverageOptions(_ etps: [ETPSummary]) -> [Double] {
    Set(etps.map(\.leverage)).sorted { leverageOrder($0, $1) == .orderedAscending }
  }

  /// 행 둘째 줄 끝에 붙일 정렬 값. 기본 정렬이면 `.none`(붙이지 않음), 값이 없으면 `.some(nil)`
  static func sortValue(_ etp: ETPSummary, _ sort: ETPSort) -> Double?? {
    sort == .default ? .none : .some(value(etp, sort))
  }

  private static func value(_ etp: ETPSummary, _ sort: ETPSort) -> Double? {
    switch sort {
    case .default: nil
    case .aum: etp.aum
    case .tradingValue: etp.avgTradingValue
    }
  }

  private static func byMarket(_ a: ETPSummary, _ b: ETPSummary) -> ComparisonResult {
    let markets = ETPMarket.allCases
    return compare(markets.firstIndex(of: a.market)!, markets.firstIndex(of: b.market)!)
  }

  private static func byDefault(_ a: ETPSummary, _ b: ETPSummary) -> ComparisonResult {
    byMarket(a, b).then(leverageOrder(a.leverage, b.leverage)).then(a.name.localizedCompare(b.name))
  }

  private static func byValueDescending(_ a: Double?, _ b: Double?) -> ComparisonResult {
    switch (a, b) {
    case (nil, nil): .orderedSame
    case (nil, _): .orderedDescending
    case (_, nil): .orderedAscending
    case (let a?, let b?): compare(b, a)
    }
  }

  private static func compare<T: Comparable>(_ a: T, _ b: T) -> ComparisonResult {
    a < b ? .orderedAscending : a > b ? .orderedDescending : .orderedSame
  }
}

extension ComparisonResult {
  /// 같으면 다음 기준으로
  fileprivate func then(_ next: @autoclosure () -> ComparisonResult) -> ComparisonResult {
    self == .orderedSame ? next() : self
  }
}
