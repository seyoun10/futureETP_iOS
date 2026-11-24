import Core

/// C-b 십자선 상세 박스 줄: 월물 / 기준일 값 / 비교일 값 / 변화율. 날짜는 범례와 같다(D-116).
/// 그 커브에 없는 값은 줄을 뺀다 (screens.md C-b 선차트, RN `CurveScreen` `CurveDetail`)
enum CurveDetail {
  static func rows(_ curve: Curve, index: Int, t: DisparityInfo.Translate) -> [DetailRow] {
    guard curve.points.indices.contains(index) else { return [] }
    let point = curve.points[index]
    let price = { (v: Double) in NumberFormat.price(v, decimals: curve.priceDecimals) }
    let date = { (d: LocalDate) in CurveFormat.legendDate(d, current: curve.freshness.tradeDate) }
    var rows: [DetailRow] = [
      .single(.init(label: NumberFormat.contractMonth(point.contractMonth), value: nil))
    ]
    if let base = point.basePrice {
      rows.append(.single(.init(label: date(curve.baseDate), value: price(base))))
    }
    if let current = point.currentPrice {
      rows.append(.single(.init(label: date(curve.compareDate), value: price(current))))
    }
    if let pct = point.changePct {
      rows.append(
        .single(.init(label: t("curve.tooltipChange", [:]), value: CurveFormat.pct(pct))))
    }
    return rows
  }
}
