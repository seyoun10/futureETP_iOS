import Core
import Foundation
import Testing

struct ModelDecodingTests {
  private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder.api().decode(type, from: Data(json.utf8))
  }

  @Test(arguments: ["2026-11-24T03:46:00.000Z", "2026-11-24T03:46:00Z"])
  func dateTimeAcceptsUTCWithOrWithoutFraction(_ string: String) throws {
    let date = try decode([Date].self, #"["\#(string)"]"#)[0]
    #expect(date == Date(timeIntervalSince1970: 1_795_491_960))
  }

  @Test(arguments: ["2026-11-24T12:46:00+09:00", "2026-11-24", "x"])
  func dateTimeRejectsOffsetsAndOtherForms(_ string: String) {
    #expect(throws: DecodingError.self) { try decode([Date].self, #"["\#(string)"]"#) }
  }

  @Test func localDateRoundTrips() throws {
    let date = try decode([LocalDate].self, #"["2028-02-29"]"#)[0]
    #expect(date == LocalDate(year: 2028, month: 2, day: 29))
    #expect(date.description == "2028-02-29")
  }

  @Test(arguments: ["2026-02-29", "2026-13-01", "2026-1-01", "20260101", "２０２６-01-01"])
  func localDateRejectsInvalid(_ string: String) {
    #expect(LocalDate(string) == nil)
  }

  @Test func contractMonthParses() {
    #expect(ContractMonth("2026-12") == ContractMonth(year: 2026, month: 12))
    #expect(ContractMonth("2026-00") == nil)
    #expect(ContractMonth("2026-12-01") == nil)
  }

  @Test func unknownEnumValueFails() {
    #expect(throws: DecodingError.self) { try decode([MarketState].self, #"["HALTED"]"#) }
  }
}
