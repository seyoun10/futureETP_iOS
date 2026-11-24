import Core
import Foundation

/// C-b 날짜·변화율 표기 (RN `curve/curveModel.ts`)
enum CurveFormat {
  /// 차트 점·상세 박스 변화율 소수 자릿수. 커브는 점이 많아 소수 첫째 자리까지
  static let pctDecimals = 1

  /// `+1.2%`
  static func pct(_ pct: Double) -> String {
    "\(NumberFormat.change(pct, decimals: pctDecimals))%"
  }

  /// 기준일 버튼 `2026/11/20`. 멀리 옮길 수 있어 연도를 항상 쓴다(screens.md C-b 버튼)
  static func fullDate(_ date: LocalDate) -> String {
    date.description.replacing("-", with: "/")
  }

  /// 범례·상세 박스 날짜: D(`current`)와 같은 해면 `MM/DD`, 아니면 `YYYY/MM/DD`(screens.md C-b 기준일 선택 시트)
  static func legendDate(_ date: LocalDate, current: LocalDate) -> String {
    let full = fullDate(date)
    return date.year == current.year ? String(full.dropFirst(5)) : full
  }

  /// 휴장일 안내의 요일(`금`·`Fri`). 날짜만이라 UTC로 센다
  static func weekday(_ date: LocalDate, locale: Locale) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.setLocalizedDateFormatFromTemplate("EEE")
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = formatter.timeZone
    let day = calendar.date(
      from: DateComponents(year: date.year, month: date.month, day: date.day))!
    return formatter.string(from: day)
  }

  /// 롤 수익률 줄(비교일 커브 값만, 범례와 같은 줄). 산출할 수 없으면 "산출 불가"
  static func rollLine(_ curve: Curve, t: DisparityInfo.Translate) -> String {
    let value =
      curve.current.map { t("curve.perYear", ["pct": pct($0.rollYieldPct)]) }
      ?? t("curve.unavailable", [:])
    return t("curve.rollYield", ["value": value])
  }
}
