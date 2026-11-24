/// 순자산·거래대금 같은 큰 금액을 단위로 줄인다(screens.md C-d 예: `1,234억 원`, `$12.3M`).
/// 통화 표기는 문구(`etp.amount`)가 붙인다. 단위는 월물 표기처럼 숫자 표기로 본다 (RN `lib/formatAmount.ts`)
public enum AmountFormat {
  public enum Scheme: Sendable {
    /// 억·만, 정수(`1,234억`). 그 아래는 원 단위
    case eok
    /// T·B·M·K, 소수 한 자리(`12.3M`)
    case si

    fileprivate var units: [(name: String, size: Double)] {
      switch self {
      case .eok: [("억", 1e8), ("만", 1e4)]
      case .si: [("T", 1e12), ("B", 1e9), ("M", 1e6), ("K", 1e3)]
      }
    }

    fileprivate var decimals: Int { self == .eok ? 0 : 1 }
  }

  public static func compact(_ value: Double, scheme: Scheme) -> String {
    let units = scheme.units
    let decimals = scheme.decimals
    guard let index = units.firstIndex(where: { abs(value) >= $0.size }) else {
      return NumberFormat.price(value, decimals: 0)
    }
    let unit = units[index]
    // 반올림해서 위 단위에 닿으면(9,999.6만 → 10,000만) 위 단위로 쓴다(1억)
    let rounded = Double(NumberFormat.toFixed(abs(value / unit.size), decimals: decimals)) ?? 0
    if index > 0, rounded >= units[index - 1].size / unit.size {
      let upper = units[index - 1]
      return "\(NumberFormat.price(value / upper.size, decimals: decimals))\(upper.name)"
    }
    return "\(NumberFormat.price(value / unit.size, decimals: decimals))\(unit.name)"
  }
}
