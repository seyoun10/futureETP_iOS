import Core

/// C-d·C-d-a 공용 표기 (RN `EtpListScreen`·`EtpDetailScreen`)
enum ETPText {
  typealias Translate = (_ key: String, _ values: [String: String]) -> String

  /// 미국 상장은 티커 + 이름 (screens.md C-d)
  static func title(_ etp: ETPSummary) -> String {
    if etp.market == .us, let ticker = etp.tickers.first { return "\(ticker)  \(etp.name)" }
    return etp.name
  }

  /// `1x`, `-2x`. 배수는 JS 숫자 기본 문자열처럼 정수면 소수점 없이
  static func leverage(_ value: Double, t: Translate) -> String {
    t("etp.leverageValue", ["n": number(value)])
  }

  /// 둘째 줄: `KRX · ETF · 1x · 환헤지`, 정렬 값이 있으면 끝에 `순자산 1,234억 원`
  static func attributes(_ etp: ETPSummary, sort: ETPSort, t: Translate) -> String {
    var parts = [
      etp.market.rawValue, etp.type.rawValue, leverage(etp.leverage, t: t),
      t("etp.fxHedges.\(etp.fxHedge.rawValue)", [:]),
    ]
    if case .some(let value) = ETPListModel.sortValue(etp, sort) {
      let amount = value.map { self.amount($0, market: etp.market, t: t) } ?? t("etp.noValue", [:])
      parts.append(
        t("etp.sortValue", ["label": t("etp.sorts.\(sort.rawValue)", [:]), "amount": amount]))
    }
    return parts.joined(separator: " · ")
  }

  /// 순자산·거래대금. 원은 언어 따라(ko 억·만, en si), 달러는 언어와 상관없이 si
  static func amount(_ value: Double, market: ETPMarket, t: Translate) -> String {
    let scheme: AmountFormat.Scheme =
      market == .us || t("etp.krwScheme", [:]) == "si" ? .si : .eok
    return t("etp.amount.\(market.rawValue)", ["n": AmountFormat.compact(value, scheme: scheme)])
  }

  static func number(_ value: Double) -> String {
    value == value.rounded() && abs(value) < 1e15 ? String(Int(value)) : String(value)
  }
}
