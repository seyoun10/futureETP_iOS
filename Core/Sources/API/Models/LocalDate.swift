import Foundation

/// 시간대 없는 날짜 `YYYY-MM-DD` (계약 `format: date`). CME 거래일·기준일에 쓴다
public struct LocalDate: Hashable, Comparable, Sendable, CustomStringConvertible {
  public let year: Int
  public let month: Int
  public let day: Int

  /// 달력에 없는 날짜(2월 30일 등)면 nil
  public init?(year: Int, month: Int, day: Int) {
    guard (1...9999).contains(year), (1...12).contains(month), day >= 1,
      day <= Self.daysInMonth(year: year, month: month)
    else { return nil }
    self.year = year
    self.month = month
    self.day = day
  }

  /// `YYYY-MM-DD`만 받는다
  public init?(_ string: String) {
    let parts = string.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
      parts.allSatisfy({ $0.allSatisfy(\.isASCIIDigit) }),
      let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
    else { return nil }
    self.init(year: year, month: month, day: day)
  }

  public var description: String {
    String(format: "%04d-%02d-%02d", year, month, day)
  }

  public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
    (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
  }

  /// `self`에서 `other`까지 달력 일수(`other`가 이르면 음수). 롤 수익률 만기 간격에 쓴다
  public func days(to other: LocalDate) -> Int {
    other.dayNumber - dayNumber
  }

  /// 그레고리력 일 번호(Julian Day Number). 두 날짜의 차이만 쓴다
  private var dayNumber: Int {
    let a = (14 - month) / 12
    let y = year + 4800 - a
    let m = month + 12 * a - 3
    return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
  }

  static func daysInMonth(year: Int, month: Int) -> Int {
    switch month {
    case 2: (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 ? 29 : 28
    case 4, 6, 9, 11: 30
    default: 31
    }
  }
}

extension LocalDate: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let string = try container.decode(String.self)
    guard let date = LocalDate(string) else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Invalid date: \(string)")
    }
    self = date
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(description)
  }
}

/// 월물 만기 월 `YYYY-MM`. 표시 표기(`DEC26`)는 포맷 함수가 만든다
public struct ContractMonth: Hashable, Comparable, Sendable, CustomStringConvertible {
  public let year: Int
  public let month: Int

  public init?(year: Int, month: Int) {
    guard (1...9999).contains(year), (1...12).contains(month) else { return nil }
    self.year = year
    self.month = month
  }

  /// `YYYY-MM`만 받는다
  public init?(_ string: String) {
    let parts = string.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 2, parts[0].count == 4, parts[1].count == 2,
      parts.allSatisfy({ $0.allSatisfy(\.isASCIIDigit) }),
      let year = Int(parts[0]), let month = Int(parts[1])
    else { return nil }
    self.init(year: year, month: month)
  }

  public var description: String {
    String(format: "%04d-%02d", year, month)
  }

  public static func < (lhs: ContractMonth, rhs: ContractMonth) -> Bool {
    (lhs.year, lhs.month) < (rhs.year, rhs.month)
  }
}

extension ContractMonth: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let string = try container.decode(String.self)
    guard let month = ContractMonth(string) else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Invalid contract month: \(string)")
    }
    self = month
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(description)
  }
}

extension Character {
  fileprivate var isASCIIDigit: Bool { isASCII && isNumber }
}
