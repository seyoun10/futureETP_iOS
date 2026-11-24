import Core
import SwiftUI

/// C-c 십자선 상세 박스 줄: 날짜(마지막 날이 잠정 값이면 표시), 그날 값이 있는 월물별 가격(선 색, 대표월물 ●),
/// 맨 아래 양끝 월물의 연환산 롤 수익률(값이 있는 월물이 둘 이상일 때만) (RN `ContractChartScreen` `CrosshairDetail`)
enum ContractDetail {
  static func rows(
    _ chart: ContractChartModel, index: Int, t: DisparityInfo.Translate
  ) -> [DetailRow] {
    let data = chart.chart
    guard data.dates.indices.contains(index) else { return [] }
    let provisional = data.provisional && index == data.dates.count - 1
    var rows: [DetailRow] = [
      .single(
        .init(
          label: data.dates[index].description,
          value: provisional ? t("contracts.provisional", [:]) : nil))
    ]
    for (i, contract) in data.contracts.enumerated() {
      guard contract.prices.indices.contains(index), let price = contract.prices[index] else {
        continue
      }
      rows.append(
        .single(
          .init(
            label: NumberFormat.contractMonth(contract.contractMonth),
            value: NumberFormat.price(price, decimals: data.priceDecimals),
            color: ContractChartModel.lineColor(i),
            mark: contract.isFront ? ContractChartModel.frontMark : nil)))
    }
    if let rollYield = chart.endsRollYieldPct(at: index) {
      rows.append(
        .single(
          .init(
            label: t("contracts.rollYield", [:]),
            value: t("curve.perYear", ["pct": NumberFormat.changePct(rollYield)]))))
    }
    return rows
  }
}
