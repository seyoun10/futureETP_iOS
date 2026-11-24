import Foundation

/// 조회 API의 query 문자열 (계약 `schemas/*Query.json`, 원본 `packages/shared/src/queries.ts`).
/// 없는 값(nil)은 항목을 넣지 않는다
public protocol APIQuery: Sendable {
  var queryItems: [URLQueryItem] { get }
}

/// `GET /v1/commodities/:code/disparity` (D-086, D-104). 설정 값을 query로 보낸다
public struct DisparityQuery: APIQuery, Equatable {
  public var basis: Basis
  public var maPeriod: MAPeriod
  public var window: DistributionWindow
  public var levels: RareLevels
  /// 이 거래일보다 이른 봉만(이전 3년 더 받기). nil이면 최근 3년
  public var before: LocalDate?

  public init(
    basis: Basis, maPeriod: MAPeriod, window: DistributionWindow, levels: RareLevels,
    before: LocalDate? = nil
  ) {
    self.basis = basis
    self.maPeriod = maPeriod
    self.window = window
    self.levels = levels
    self.before = before
  }

  public var queryItems: [URLQueryItem] {
    [
      URLQueryItem(name: "basis", value: basis.rawValue),
      URLQueryItem(name: "ma", value: String(maPeriod.rawValue)),
      URLQueryItem(name: "window", value: window.rawValue),
      URLQueryItem(name: "levels", value: levels.queryValue),
    ] + [before.map { URLQueryItem(name: "before", value: $0.description) }].compactMap { $0 }
  }
}

/// `GET /v1/commodities/:code/contracts` (D-104)
public struct ContractsQuery: APIQuery, Equatable {
  public var before: LocalDate?

  public init(before: LocalDate? = nil) {
    self.before = before
  }

  public var queryItems: [URLQueryItem] {
    [before.map { URLQueryItem(name: "before", value: $0.description) }].compactMap { $0 }
  }
}

/// `GET /v1/commodities/:code/curve` (D-090). nil이면 서버가 최근 거래일로 고른다
public struct CurveQuery: APIQuery, Equatable {
  public var baseDate: LocalDate?

  public init(baseDate: LocalDate? = nil) {
    self.baseDate = baseDate
  }

  public var queryItems: [URLQueryItem] {
    [baseDate.map { URLQueryItem(name: "baseDate", value: $0.description) }].compactMap { $0 }
  }
}

/// `GET /v1/calendar` (D-143). `to - from`이 0일 이상 366일 미만
public struct CalendarQuery: APIQuery, Equatable {
  public static let maxDays = 366

  public let from: LocalDate
  public let to: LocalDate

  /// `to`가 `from`보다 이르거나 날짜 차이가 366일 이상이면 nil
  public init?(from: LocalDate, to: LocalDate) {
    let days = to.daysSinceEpoch - from.daysSinceEpoch
    guard (0..<Self.maxDays).contains(days) else { return nil }
    self.from = from
    self.to = to
  }

  public var queryItems: [URLQueryItem] {
    [
      URLQueryItem(name: "from", value: from.description),
      URLQueryItem(name: "to", value: to.description),
    ]
  }
}

extension LocalDate {
  /// 1970-01-01부터 센 날 수(그레고리력). 날짜 차이 계산용
  var daysSinceEpoch: Int {
    // Howard Hinnant days_from_civil
    let y = month <= 2 ? year - 1 : year
    let era = (y >= 0 ? y : y - 399) / 400
    let yoe = y - era * 400
    let mp = (month + 9) % 12
    let doy = (153 * mp + 2) / 5 + day - 1
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    return era * 146_097 + doe - 719_468
  }
}
