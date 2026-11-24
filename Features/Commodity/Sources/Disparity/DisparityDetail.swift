import Core
import SwiftUI

/// C-a 십자선 상세 박스 줄: 날짜·월물 구성, 시고저종, 전일 대비, 이격도, 이평선·rare-level 값
/// (screens.md C-a 길게 누르기, RN `DisparityChartScreen` `CrosshairDetail`).
/// 전일 대비·이격도는 부호대로 등락 색, 선 값은 가격 높은 순으로 선 색이다
enum DisparityDetail {
  static func rows(
    _ chart: DisparityChartModel, index: Int, data: DisparityChart, palette: UpDownPalette,
    t: DisparityInfo.Translate
  ) -> [DetailRow] {
    guard chart.bars.indices.contains(index) else { return [] }
    let bar = chart.bars[index]
    let decimals = data.priceDecimals
    var holdings = DisparityChartModel.holdingsText(bar, basis: data.basis)
    // 대표월물 전환일 봉이면 새 월물명을 이어 쓴다(차트에는 세로 점선만 있다, D-103)
    if let current = holdings, let next = chart.frontSwitchAt[index] {
      holdings = "\(current) → \(next)"
    }
    func price(_ key: String, _ value: Double) -> DetailRow.Cell {
      DetailRow.Cell(
        label: t("disparity.\(key)", [:]), value: NumberFormat.price(value, decimals: decimals))
    }
    var rows: [DetailRow] = [
      .single(.init(label: bar.tradeDate.description, value: holdings)),
      .pair(price("open", bar.open), price("high", bar.high)),
      .pair(price("close", bar.close), price("low", bar.low)),
    ]
    if index > 0 {
      let previous = chart.bars[index - 1].close
      let change = bar.close - previous
      let pct = (bar.close / previous - 1) * 100
      rows.append(
        .single(
          .init(
            label: t("disparity.prevChange", [:]),
            value:
              "\(NumberFormat.change(change, decimals: decimals)) (\(NumberFormat.changePct(pct)))",
            color: palette.color(change: change, changePct: pct, decimals: decimals))))
    }
    if let disparity = bar.disparity {
      rows.append(
        .single(
          .init(
            label: t("disparity.disparityLabel", [:]), value: DisparityInfo.disparity(disparity),
            color: palette.color(for: disparity, decimals: DisparityInfo.disparityDecimals))))
    }
    let lines = zip(chart.series.lines, chart.lineLabels)
      .compactMap { line, label in line.values[index].map { (line, label, $0) } }
      .sorted { $0.2 > $1.2 }
    for (line, label, value) in lines {
      let name =
        switch label {
        case .movingAverage: t("disparity.ma", ["n": String(data.maPeriod.rawValue)])
        case .band(let direction, let level):
          t("disparity.tail\(direction.rawValue)", ["pct": RareLevels.text(level)])
        }
      rows.append(
        .single(
          .init(
            label: name, value: NumberFormat.price(value, decimals: decimals), color: line.color)))
    }
    return rows
  }
}
