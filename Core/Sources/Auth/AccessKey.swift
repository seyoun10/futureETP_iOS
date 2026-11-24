import Foundation

/// 서버 접근 키 형식 (D-044): 32바이트 난수 base64url(패딩 없음) = 43자
public enum AccessKey {
  /// Mac 키 스크립트가 띄우는 QR 내용의 접두사
  public static let qrPrefix = "futureetp-key:v1:"

  /// QR은 접두사가 있어야 받고, 붙여넣기는 키만 넣어도 받는다. 형식이 아니면 nil (RN `parseAccessKey`)
  public static func parse(_ input: String, requirePrefix: Bool = false) -> String? {
    let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
    let hasPrefix = text.hasPrefix(qrPrefix)
    if requirePrefix && !hasPrefix { return nil }
    let key = hasPrefix ? String(text.dropFirst(qrPrefix.count)) : text
    return key.wholeMatch(of: /[A-Za-z0-9_-]{43}/) != nil ? key : nil
  }
}
