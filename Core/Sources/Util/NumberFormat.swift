import Foundation

/// 시세 숫자·월물 표기. 언어와 상관없이 `2,405.1`·`+12.2`·`-1.04%`·`DEC26` 형식이다
/// (screens.md A, RN `lib/formatNumber.ts`와 같은 결과)
public enum NumberFormat {
  /// 등락률(%) 소수 자릿수
  public static let changePctDecimals = 2

  /// 천 단위 쉼표 + 고정 소수 자릿수. 음수는 `-`를 붙이고, 반올림해 0이면 붙이지 않는다
  public static func price(_ value: Double, decimals: Int) -> String {
    let fixed = toFixed(abs(value), decimals: decimals)
    let parts = fixed.split(separator: ".", omittingEmptySubsequences: false)
    let integer = grouped(String(parts[0]))
    let body = parts.count > 1 ? "\(integer).\(parts[1])" : integer
    return value < 0 && !isZero(fixed) ? "-\(body)" : body
  }

  /// 부호 붙인 변화량. 반올림해서 0이면 부호를 붙이지 않는다
  public static func change(_ value: Double, decimals: Int) -> String {
    let body = price(abs(value), decimals: decimals)
    if isZero(body) { return body }
    return "\(value < 0 ? "-" : "+")\(body)"
  }

  /// 소수 둘째 자리 등락률 `+0.51%`
  public static func changePct(_ pct: Double) -> String {
    "\(change(pct, decimals: changePctDecimals))%"
  }

  /// 월물 `2026-12` → `DEC26` (CME 월물 표기라 언어와 상관없다)
  public static func contractMonth(_ month: ContractMonth) -> String {
    "\(monthNames[month.month - 1])\(twoDigits(month.year % 100))"
  }

  /// 월물 `2026-12` → `2612` (C-b x축은 월물이 많아 숫자로 줄인다)
  public static func contractMonthShort(_ month: ContractMonth) -> String {
    "\(twoDigits(month.year % 100))\(twoDigits(month.month))"
  }

  /// JS `Number.prototype.toFixed`와 같은 반올림(정확한 2진 값 기준, 정확히 가운데면 올림).
  /// `0 ≤ value < 1e21`만 쓴다
  public static func toFixed(_ value: Double, decimals: Int) -> String {
    // 2진 값의 10진 전개를 넉넉히 받아 직접 반올림한다(printf는 가운데 값을 짝수로 보낸다)
    let exact = String(format: "%.\(decimals + 40)f", value)
    let parts = exact.split(separator: ".")
    var digits = Array(parts[0]) + Array(parts[1].prefix(decimals))
    if let next = parts[1].dropFirst(decimals).first, next >= "5" {
      var index = digits.count - 1
      while index >= 0, digits[index] == "9" {
        digits[index] = "0"
        index -= 1
      }
      if index >= 0 {
        digits[index] = Character(String(digits[index].wholeNumberValue! + 1))
      } else {
        digits.insert("1", at: 0)
      }
    }
    let integerCount = digits.count - decimals
    let integer = String(digits[..<integerCount])
    return decimals == 0 ? integer : "\(integer).\(String(digits[integerCount...]))"
  }

  private static let monthNames = [
    "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC",
  ]

  private static func grouped(_ integer: String) -> String {
    var result = ""
    for (offset, digit) in integer.enumerated() {
      if offset > 0, (integer.count - offset) % 3 == 0 { result.append(",") }
      result.append(digit)
    }
    return result
  }

  private static func isZero(_ text: String) -> Bool {
    text.allSatisfy { $0 == "0" || $0 == "." || $0 == "," }
  }

  private static func twoDigits(_ value: Int) -> String {
    value < 10 ? "0\(value)" : "\(value)"
  }
}
