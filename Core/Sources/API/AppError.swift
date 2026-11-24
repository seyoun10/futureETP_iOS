import Foundation

/// 모든 API 실패 (D-042). 화면은 `code`만 보고 `errors.<code>` 문구를 고른다
public struct AppError: Error, Sendable, Equatable {
  /// 서버 코드(`contract/schemas/error.json`) + 앱 코드
  public enum Code: String, Sendable, CaseIterable, Decodable {
    case unauthorized = "UNAUTHORIZED"
    case rateLimited = "RATE_LIMITED"
    case validationFailed = "VALIDATION_FAILED"
    case notFound = "NOT_FOUND"
    case `internal` = "INTERNAL"
    case network = "NETWORK"
    case timeout = "TIMEOUT"
    case schemaMismatch = "SCHEMA_MISMATCH"

    /// 서버가 봉투 `error.code`로 보내는 값
    static let server: Set<Code> = [
      .unauthorized, .rateLimited, .validationFailed, .notFound, .internal,
    ]
  }

  public let code: Code
  /// HTTP 상태. 응답을 받기 전 실패(`NETWORK`·`TIMEOUT`)는 nil
  public let status: Int?
  /// 진단용. 화면에 보이지 않는다
  public let message: String

  public init(_ code: Code, status: Int? = nil, message: String? = nil) {
    self.code = code
    self.status = status
    self.message = message ?? code.rawValue
  }

  /// 자동 재시도 대상 (D-072). 4xx·`SCHEMA_MISMATCH`는 재시도하지 않는다
  public var isRetryable: Bool {
    [.network, .timeout, .internal].contains(code)
  }
}
