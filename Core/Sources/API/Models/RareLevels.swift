import Foundation

/// 검증을 마친 rare 레벨 5개 (원본 `packages/shared/src/settings.ts` `rareLevelsSchema`).
/// PATCH 본문 `rareLevels`와 C-a 조회 query `levels`에 같은 규칙으로 쓴다(futureETP 품질 검증 B2/D1·D3)
public struct RareLevels: Sendable, Equatable, Encodable {
  public static let count = 5
  public static let range: ClosedRange<Double> = 0.1...49.9

  /// 소수 첫째 자리로 반올림한 오름차순 5개
  public let values: [Double]

  /// 개수·범위·소수 첫째 자리·중복을 본다. 부동소수 오차(0.30000000000000004)는 허용하고 반올림한 값을 쓴다.
  /// 중복은 반올림 뒤 값으로 본다(1과 1.00000000001은 중복). 규칙 밖이면 nil
  public init?(_ levels: [Double]) {
    guard levels.count == Self.count, levels.allSatisfy(Self.isValid) else { return nil }
    let tenths = levels.map { Int(($0 * 10).rounded()) }
    guard Set(tenths).count == tenths.count else { return nil }
    values = tenths.sorted().map { Double($0) / 10 }
  }

  /// 레벨 하나가 범위 안이고 소수 첫째 자리까지다(원본 `rareLevelSchema`). 부동소수 오차는 허용한다
  public static func isValid(_ level: Double) -> Bool {
    guard level.isFinite, range.contains(level) else { return false }
    let scaled = level * 10
    return abs(scaled - scaled.rounded()) < 1e-9
  }

  /// 이격도차트 기본 레벨 (원본 `DISPARITY_SETTINGS_DEFAULTS.rareLevels`)
  public static let defaults = RareLevels([1, 2, 4, 8, 16])!

  /// query 문자열 `1,2.5,5,10,20`. 각 값은 JS 숫자 기본 문자열과 같다(정수는 소수점 없이)
  public var queryValue: String {
    values.map(Self.text).joined(separator: ",")
  }

  /// 레벨 하나의 문자열(`1`, `2.5`). 소수 첫째 자리로 반올림하고 정수는 소수점 없이 쓴다
  public static func text(_ level: Double) -> String {
    let tenths = Int((level * 10).rounded())
    return tenths % 10 == 0 ? "\(tenths / 10)" : "\(tenths / 10).\(tenths % 10)"
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(values)
  }
}
