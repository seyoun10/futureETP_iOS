import Core

/// C-a 차트 위 정보 줄 두 줄의 문구 (screens.md C-a 상단 첫 줄·둘째 줄, RN `DisparityChartScreen` `TodayLine`·`StatsLine`).
/// 문구 찾기는 `t(key, values)`로 받아 테스트에서 바꿔 끼운다
enum DisparityInfo {
  typealias Translate = (_ key: String, _ values: [String: String]) -> String

  /// 이격도(%) 표시 자릿수
  static let disparityDecimals = 1

  /// 기준값 이름. 대표월물이면 지금 월물을 붙이고(`대표월물 DEC26`), 한국형·미국형은 롤 중일 때만 `(롤 중)`.
  /// 기준값이 없어 대표월물로 대신 보이면 `대표월물*`
  static func basisLabel(_ data: DisparityChart, today: DisparityChartModel.Bar, t: Translate)
    -> String
  {
    let name = basisName(data.basis, t: t)
    var label = data.fallback ? t("disparity.basisFallback", ["basis": name]) : name
    if data.basis == .front {
      if let front = today.holdings.first?.contractMonth {
        label += " " + NumberFormat.contractMonth(front)
      }
    } else if today.inRoll {
      label = t("disparity.basisInRoll", ["basis": name])
    }
    return label
  }

  /// `시3.151 고3.184 저3.098 종3.120`
  static func ohlc(_ bar: DisparityChartModel.Bar, decimals: Int, t: Translate) -> String {
    [("open", bar.open), ("high", bar.high), ("low", bar.low), ("close", bar.close)]
      .map { t("disparity.\($0.0)", [:]) + NumberFormat.price($0.1, decimals: decimals) }
      .joined(separator: " ")
  }

  /// 기준값을 누르면 여는 안내: 조정 가격(또는 대표월물) 설명, 대체 안내, 금·은 미국형은 한국형과 같음 (D-014)
  static func hints(
    _ data: DisparityChart, code: CommodityCode, requestedBasis: Basis?, t: Translate
  ) -> [String] {
    var hints = [
      data.basis == .front
        ? t("disparity.hint.FRONT", [:])
        : t("disparity.hint.adjusted", ["basis": basisName(data.basis, t: t)])
    ]
    if data.fallback, let requestedBasis, requestedBasis != .front {
      hints.append(t("disparity.hint.fallback", ["basis": basisName(requestedBasis, t: t)]))
    }
    if data.basis == .us, code == .gc || code == .si {
      hints.append(t("disparity.hint.sameAsKR", [:]))
    }
    return hints
  }

  /// `이격도 -18.7% (하위 9%) · 저점대비 +29.5% · 고점대비 -46.3%`. LC·HC는 보이는 봉 `visible` 기준이다
  static func stats(
    _ data: DisparityChart, chart: DisparityChartModel, visible: ClosedRange<Int>?, t: Translate
  ) -> String {
    var items: [String] = []
    if let today = chart.bars.last, let disparity = today.disparity {
      let tail = data.currentTail.map {
        " ("
          + t(
            "disparity.tail\($0.side.rawValue)", ["pct": DisparityChartModel.tailPct($0.pct)]) + ")"
      }
      items.append(t("disparity.disparity", ["value": Self.disparity(disparity)]) + (tail ?? ""))
    }
    // 새로 조회해 봉이 줄었을 수 있어 범위를 봉 안으로 자른다
    if let visible, !chart.bars.isEmpty,
      let stats = chart.visibleStats(
        visible.lowerBound...min(visible.upperBound, chart.bars.count - 1))
    {
      items.append(t("disparity.fromLow", ["pct": NumberFormat.changePct(stats.fromLowPct)]))
      items.append(t("disparity.fromHigh", ["pct": NumberFormat.changePct(stats.fromHighPct)]))
    }
    return items.joined(separator: " · ")
  }

  /// `-18.7%`
  static func disparity(_ value: Double) -> String {
    NumberFormat.change(value, decimals: disparityDecimals) + "%"
  }

  private static func basisName(_ basis: Basis, t: Translate) -> String {
    t("settings.basis\(basis.rawValue)", [:])
  }
}
