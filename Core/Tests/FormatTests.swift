import Core
import Foundation
import Testing

// RN `lib/format*.test.ts`와 같은 기대값. 반올림 경계는 JS `toFixed` 결과(node로 확인)
@Suite struct NumberFormatTests {
  @Test func priceGroupsThousandsAndFixesDecimals() {
    #expect(NumberFormat.price(2405.1, decimals: 1) == "2,405.1")
    #expect(NumberFormat.price(1_234_567.891, decimals: 2) == "1,234,567.89")
    #expect(NumberFormat.price(2.7656, decimals: 3) == "2.766")
    #expect(NumberFormat.price(80, decimals: 2) == "80.00")
    #expect(NumberFormat.price(999, decimals: 0) == "999")
  }

  @Test func priceSignsNegativesUnlessRoundedToZero() {
    #expect(NumberFormat.price(-1234.5, decimals: 1) == "-1,234.5")
    #expect(NumberFormat.price(-0.001, decimals: 2) == "0.00")
  }

  @Test(arguments: [
    (0.125, 2, "0.13"), (2.5, 0, "3"), (0.5, 0, "1"), (1.005, 2, "1.00"), (1.45, 1, "1.4"),
    (2.675, 2, "2.67"), (1e-7, 2, "0.00"), (123_456.785, 2, "123,456.79"), (999.96, 1, "1,000.0"),
  ])
  func priceRoundsLikeJavaScriptToFixed(value: Double, decimals: Int, expected: String) {
    #expect(NumberFormat.price(value, decimals: decimals) == expected)
  }

  @Test func changeSignsUpAndDown() {
    #expect(NumberFormat.change(12.15, decimals: 1) == "+12.2")
    #expect(NumberFormat.change(-0.029, decimals: 3) == "-0.029")
    #expect(NumberFormat.change(-1250, decimals: 1) == "-1,250.0")
  }

  @Test func changeHasNoSignAtZero() {
    #expect(NumberFormat.change(0, decimals: 2) == "0.00")
    #expect(NumberFormat.change(0.004, decimals: 2) == "0.00")
  }

  @Test func changePctUsesTwoDecimals() {
    #expect(NumberFormat.changePct(0.5075) == "+0.51%")
    #expect(NumberFormat.changePct(-1.04) == "-1.04%")
  }

  @Test func contractMonthUsesCmeNotation() {
    #expect(NumberFormat.contractMonth(ContractMonth("2026-12")!) == "DEC26")
    #expect(NumberFormat.contractMonth(ContractMonth("2027-01")!) == "JAN27")
    #expect(NumberFormat.contractMonth(ContractMonth("2105-03")!) == "MAR05")
  }

  @Test func contractMonthShortUsesDigits() {
    #expect(NumberFormat.contractMonthShort(ContractMonth("2026-12")!) == "2612")
    #expect(NumberFormat.contractMonthShort(ContractMonth("2027-02")!) == "2702")
  }
}

@Suite struct AmountFormatTests {
  @Test func eokUsesIntegers() {
    #expect(AmountFormat.compact(1_555_015_000_000, scheme: .eok) == "15,550억")
    #expect(AmountFormat.compact(1_198_418_445, scheme: .eok) == "12억")
    #expect(AmountFormat.compact(45_000_000, scheme: .eok) == "4,500만")
    #expect(AmountFormat.compact(9_999, scheme: .eok) == "9,999")
  }

  @Test func siUsesOneDecimal() {
    #expect(AmountFormat.compact(12_345_678, scheme: .si) == "12.3M")
    #expect(AmountFormat.compact(1_555_015_000_000, scheme: .si) == "1.6T")
    #expect(AmountFormat.compact(850, scheme: .si) == "850")
  }

  @Test func roundingUpToNextUnitUsesThatUnit() {
    #expect(AmountFormat.compact(99_999_999, scheme: .eok) == "1억")
    #expect(AmountFormat.compact(999_960, scheme: .si) == "1.0M")
    #expect(AmountFormat.compact(999_940, scheme: .si) == "999.9K")
  }
}

@Suite struct DateTimeFormatTests {
  private func date(_ iso: String) -> Date { try! Date(iso, strategy: .iso8601) }

  @Test func localDateTimeUsesGivenTimeZone() {
    #expect(
      DateTimeFormat.localDateTime(
        date("2026-10-22T00:00:00Z"), timeZone: TimeZone(identifier: "Asia/Seoul")!)
        == "10/22 09:00")
    #expect(
      DateTimeFormat.localDateTime(
        date("2026-10-22T14:05:00Z"), timeZone: TimeZone(identifier: "America/Chicago")!)
        == "10/22 09:05")
  }

  @Test func midnightIsZeroHourOnLocalDate() {
    #expect(
      DateTimeFormat.localDateTime(
        date("2026-10-22T15:00:00Z"), timeZone: TimeZone(identifier: "Asia/Seoul")!)
        == "10/23 00:00")
  }

  @Test func tradeDateIsMonthAndDay() {
    #expect(DateTimeFormat.tradeDate(LocalDate("2026-01-05")!) == "01/05")
  }
}
