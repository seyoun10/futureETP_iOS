import Foundation

extension JSONDecoder {
  /// API 응답용 디코더. `date-time`은 UTC ISO 8601(`Z`, 소수 초는 있어도 없어도 됨)만 `Date`로 받는다
  public static func api() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let string = try container.decode(String.self)
      guard let date = APIDateTime.parse(string) else {
        throw DecodingError.dataCorruptedError(
          in: container, debugDescription: "Invalid date-time: \(string)")
      }
      return date
    }
    return decoder
  }
}

enum APIDateTime {
  private static let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
  private static let withoutFraction = Date.ISO8601FormatStyle()

  /// 계약 `date-time`(zod `z.iso.datetime()`): `Z`로 끝나는 UTC만. 오프셋 표기는 받지 않는다
  static func parse(_ string: String) -> Date? {
    guard string.hasSuffix("Z") else { return nil }
    return (try? withFraction.parse(string)) ?? (try? withoutFraction.parse(string))
  }
}

extension KeyedDecodingContainer {
  /// 계약 `integer, minimum: n`(zod `.int().nonnegative()`·`.positive()`). 범위 밖이면 디코딩 실패
  func decode(_ type: Int.Type, forKey key: Key, atLeast minimum: Int) throws -> Int {
    let value = try decode(Int.self, forKey: key)
    guard value >= minimum else {
      throw DecodingError.dataCorruptedError(
        forKey: key, in: self, debugDescription: "\(value) < \(minimum)")
    }
    return value
  }
}
