// API에서 함께 쓰는 도메인 값 (계약 `schemas/*.json`의 enum, 원본 `packages/shared/src/domain.ts`).
// 모르는 값이 오면 디코딩이 실패해 `SCHEMA_MISMATCH`가 된다 (D-042)

public enum CommodityCode: String, Codable, Sendable, CaseIterable {
  case gc = "GC"
  case si = "SI"
  case cl = "CL"
  case ng = "NG"
}

/// 기준값: 대표월물·한국형·미국형
public enum Basis: String, Codable, Sendable, CaseIterable {
  case front = "FRONT"
  case kr = "KR"
  case us = "US"
}

public enum MAPeriod: Int, Codable, Sendable, CaseIterable {
  case days20 = 20
  case days50 = 50
  case days100 = 100
  case days200 = 200
}

/// 분포 기간 N
public enum DistributionWindow: String, Codable, Sendable, CaseIterable {
  case years3 = "Y3"
  case years5 = "Y5"
  case years10 = "Y10"
  case all = "ALL"
}

public enum Direction: String, Codable, Sendable, CaseIterable {
  case up = "UP"
  case down = "DOWN"
}

/// 서버 기기 설정 언어. Foundation `Locale`과 구분한다
public enum AppLanguage: String, Codable, Sendable, CaseIterable {
  case ko
  case en
}

public enum Platform: String, Codable, Sendable, CaseIterable {
  case ios = "IOS"
  case android = "ANDROID"
}

/// ETP 상장 시장
public enum ETPMarket: String, Codable, Sendable, CaseIterable {
  case krx = "KRX"
  case us = "US"
}

public enum ETPType: String, Codable, Sendable, CaseIterable {
  case etf = "ETF"
  case etn = "ETN"
}

/// 환헤지. 미국 상장은 구분이 없어 `na`다
public enum FXHedge: String, Codable, Sendable, CaseIterable {
  case hedged = "HEDGED"
  case unhedged = "UNHEDGED"
  case na = "NA"
}

/// 장 상태 (D-022)
public enum MarketState: String, Codable, Sendable, CaseIterable {
  case open = "OPEN"
  case closed = "CLOSED"
  case settlementPending = "SETTLEMENT_PENDING"
}

/// 커브 상태(M1→M2로 판정)
public enum CurveState: String, Codable, Sendable, CaseIterable {
  case contango = "CONTANGO"
  case backwardation = "BACKWARDATION"
  case flat = "FLAT"
}

/// 휴장 달력 시장 (D-143)
public enum CalendarMarket: String, Codable, Sendable, CaseIterable {
  case cme = "CME"
  case krx = "KRX"
  case nyse = "NYSE"
}

/// 휴장 달력 예외 일정 종류. `halt`는 CME 공휴일 중간 정지, `lateOpen`은 KRX 개장 지연
public enum CalendarExceptionKind: String, Codable, Sendable, CaseIterable {
  case closed = "CLOSED"
  case halt = "HALT"
  case earlyClose = "EARLY_CLOSE"
  case lateOpen = "LATE_OPEN"
}
