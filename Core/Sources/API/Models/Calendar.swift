import Foundation

/// `GET /v1/calendar` 응답 `data` (계약 `schemas/calendar.json`, 휴장 달력 화면).
/// 평일 중 예외 일정만 준다. 주말은 앱이 직접 센다
public struct MarketCalendar: Codable, Sendable, Equatable {
  public let from: LocalDate
  public let to: LocalDate
  /// 날짜순, 같은 날은 시장 순(`CalendarMarket` 순서)
  public let exceptions: [CalendarException]
  /// 범위에 걸친 연도 중 휴장 일정이 입력되지 않은 (시장, 연도)
  public let missing: [CalendarMissingYear]
}

/// 예외 일정 하나
public struct CalendarException: Codable, Sendable, Equatable {
  public let market: CalendarMarket
  public let date: LocalDate
  public let kind: CalendarExceptionKind
  /// 그 시장 현지 시각 `HH:mm`(CME CT, KRX KST, NYSE ET). `CLOSED`는 nil
  public let at: String?
  /// 휴일 이름. 입력 원문(CME·NYSE 영어, KRX 한국어)
  public let note: String

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    market = try container.decode(CalendarMarket.self, forKey: .market)
    date = try container.decode(LocalDate.self, forKey: .date)
    kind = try container.decode(CalendarExceptionKind.self, forKey: .kind)
    at = try container.decodeIfPresent(String.self, forKey: .at)
    note = try container.decode(String.self, forKey: .note)
    if let at, at.wholeMatch(of: /\d{2}:\d{2}/) == nil {
      throw DecodingError.dataCorruptedError(
        forKey: .at, in: container, debugDescription: "\(at) is not HH:mm")
    }
  }
}

/// 휴장 일정이 없는 (시장, 연도)
public struct CalendarMissingYear: Codable, Sendable, Equatable {
  public let market: CalendarMarket
  public let year: Int
}
