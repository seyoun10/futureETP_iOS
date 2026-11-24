import Core
import Foundation
import Testing

/// 계약 테스트의 요청 쪽: 모델을 인코딩한 결과가 `Fixtures/Requests/`의 예시와 같은지 본다.
/// 같은 예시가 원본 zod 스키마를 통과하는지는 `scripts/validate-fixtures.mjs`가 본다 (D-142, IOS-007)
struct RequestEncodingTests {
  private static let levels = RareLevels([20, 1, 5, 2.5, 10])!

  @Test func settingsPatchSendsNullToTurnOff() throws {
    let patch = SettingsPatch(
      rareLevels: RareLevels([25, 0.1, 49.9, 10.5, 3]),
      alertCommodity: .some(nil),
      quietTime: QuietTime(startMin: 1320, endMin: 420))
    try expectBody(patch, equals: "settingsPatch")
  }

  @Test func settingsPatchWithEveryOtherField() throws {
    let patch = SettingsPatch(
      locale: .en, timezone: "Asia/Seoul", basis: .kr, maPeriod: .days200, window: .years10,
      alertCommodity: .gc, quietTime: .some(nil))
    try expectBody(patch, equals: "settingsPatch.all")
  }

  @Test func emptySettingsPatchOmitsEveryField() throws {
    let data = try JSONEncoder().encode(SettingsPatch())
    #expect(String(decoding: data, as: UTF8.self) == "{}")
  }

  @Test func deviceRegistration() throws {
    let registration = DeviceRegistration(
      pushToken: " a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90\n",
      version: "1.0.0")
    try expectBody(registration, equals: "deviceRegistration")
  }

  @Test(arguments: [nil, "", "  "])
  func deviceRegistrationSendsNullWithoutTokenOrVersion(_ token: String?) throws {
    try expectBody(
      DeviceRegistration(pushToken: token, version: nil), equals: "deviceRegistration.null")
  }

  @Test func deviceRegistrationDropsOverlongValues() {
    let registration = DeviceRegistration(
      pushToken: String(repeating: "a", count: 4097), version: String(repeating: "1", count: 61))
    #expect(registration.pushToken == nil)
    #expect(registration.appVersion == nil)
  }

  @Test func disparityQuery() throws {
    let query = DisparityQuery(
      basis: .kr, maPeriod: .days200, window: .years10, levels: Self.levels)
    try expectQuery(query, equals: "disparityQuery")
  }

  @Test func disparityQueryBefore() throws {
    let query = DisparityQuery(
      basis: .front, maPeriod: .days20, window: .all,
      levels: try #require(RareLevels([0.30000000000000004, 0.1, 16, 1, 49.9])),
      before: LocalDate(year: 2023, month: 11, day: 24))
    try expectQuery(query, equals: "disparityQuery.before")
  }

  @Test func contractsQuery() throws {
    try expectQuery(ContractsQuery(), equals: "contractsQuery")
    try expectQuery(
      ContractsQuery(before: LocalDate(year: 2023, month: 11, day: 24)),
      equals: "contractsQuery.before")
  }

  @Test func curveQuery() throws {
    try expectQuery(CurveQuery(), equals: "curveQuery")
    try expectQuery(
      CurveQuery(baseDate: LocalDate(year: 2026, month: 2, day: 27)), equals: "curveQuery.baseDate")
  }

  @Test func calendarQuery() throws {
    let query = try #require(
      CalendarQuery(from: date("2026-10-31"), to: date("2027-02-01")))
    try expectQuery(query, equals: "calendarQuery")
  }

  @Test(arguments: [
    // 원본과 같이 날짜 차이가 366일 미만이면 받는다
    ("2026-01-01", "2027-01-01", true),  // 365일 차이
    ("2026-01-01", "2027-01-02", false),  // 366일 차이
    ("2028-01-01", "2029-01-01", false),  // 윤년 366일 차이
    ("2026-01-01", "2026-01-01", true),
    ("2026-01-02", "2026-01-01", false),
  ])
  func calendarQueryRange(_ from: String, _ to: String, _ valid: Bool) {
    #expect((CalendarQuery(from: date(from), to: date(to)) != nil) == valid)
  }

  private func date(_ string: String) -> LocalDate { LocalDate(string)! }

  private func expectBody(_ body: some Encodable, equals fixture: String) throws {
    let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(body))
    let expected = try JSONSerialization.jsonObject(with: requestFixture(fixture))
    #expect((encoded as? NSDictionary) == (expected as? NSDictionary))
  }

  private func expectQuery(_ query: some APIQuery, equals fixture: String) throws {
    let names = query.queryItems.map(\.name)
    #expect(Set(names).count == names.count)
    let encoded = Dictionary(uniqueKeysWithValues: query.queryItems.map { ($0.name, $0.value) })
    let expected = try JSONDecoder().decode([String: String].self, from: requestFixture(fixture))
    #expect(encoded == expected)
  }

  private func requestFixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
  }
}

/// rare 레벨 입력 규칙 (원본 `rareLevelsSchema`, futureETP 품질 검증 B2/D1)
struct RareLevelsTests {
  @Test func sortsAndRoundsToOneDecimal() throws {
    let levels = try #require(RareLevels([0.30000000000000004, 49.9, 1, 2.5, 0.1]))
    #expect(levels.values == [0.1, 0.3, 1, 2.5, 49.9])
    #expect(levels.queryValue == "0.1,0.3,1,2.5,49.9")
  }

  @Test(arguments: [
    [1, 2, 4, 8],  // 4개
    [1, 2, 4, 8, 16, 32],  // 6개
    [1, 2, 4, 8, 50],  // 범위 밖
    [0, 2, 4, 8, 16],
    [1, 2, 4, 8, 1.25],  // 소수 둘째 자리
    [1, 1.00000000001, 2, 4, 8],  // 반올림하면 중복
    [1, 1, 2, 4, 8],
    [1, 2, 4, 8, .nan],
  ])
  func rejects(_ levels: [Double]) {
    #expect(RareLevels(levels) == nil)
  }

  @Test(arguments: [
    (QuietTime(startMin: 1320, endMin: 420), true),  // 자정 넘김
    (QuietTime(startMin: 0, endMin: 1410), true),
    (QuietTime(startMin: 60, endMin: 60), false),
    (QuietTime(startMin: 0, endMin: 1440), false),
    (QuietTime(startMin: 15, endMin: 60), false),
    (QuietTime(startMin: -30, endMin: 60), false),
  ])
  func quietTimePatchRule(_ time: QuietTime, _ valid: Bool) {
    #expect(time.isValidForPatch == valid)
  }
}
