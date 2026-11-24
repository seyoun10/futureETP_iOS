import Foundation
import Security

/// 작은 비밀 값 저장소. 접근 키·installation ID만 둔다 (D-043, D-044)
public protocol SecureStore: Sendable {
  func string(forKey key: String) throws -> String?
  func set(_ value: String, forKey key: String) throws
  func removeValue(forKey key: String) throws
}

/// Keychain 일반 암호 항목(`kSecClassGenericPassword`) 래퍼.
/// 첫 잠금 해제 뒤 읽을 수 있고(백그라운드 푸시 처리), 다른 기기로 옮기지 않는다
public struct Keychain: SecureStore {
  public struct Failure: Error, Equatable {
    public let status: OSStatus
  }

  private let service: String

  public init(service: String = Bundle.main.bundleIdentifier ?? "io.github.seyoon.futureetp") {
    self.service = service
  }

  public func string(forKey key: String) throws -> String? {
    var query = baseQuery(key)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    switch status {
    case errSecSuccess:
      return (result as? Data).flatMap { String(data: $0, encoding: .utf8) }
    case errSecItemNotFound:
      return nil
    default:
      throw Failure(status: status)
    }
  }

  public func set(_ value: String, forKey key: String) throws {
    let data = Data(value.utf8)
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    let status = SecItemUpdate(baseQuery(key) as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      let addStatus = SecItemAdd(
        baseQuery(key).merging(attributes) { $1 } as CFDictionary, nil)
      guard addStatus == errSecSuccess else { throw Failure(status: addStatus) }
    } else if status != errSecSuccess {
      throw Failure(status: status)
    }
  }

  public func removeValue(forKey key: String) throws {
    let status = SecItemDelete(baseQuery(key) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw Failure(status: status)
    }
  }

  private func baseQuery(_ key: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]
  }
}

/// 테스트·미리보기용 메모리 저장소
public final class InMemorySecureStore: SecureStore, @unchecked Sendable {
  private let lock = NSLock()
  private var values: [String: String]

  public init(_ values: [String: String] = [:]) {
    self.values = values
  }

  public func string(forKey key: String) throws -> String? {
    lock.withLock { values[key] }
  }

  public func set(_ value: String, forKey key: String) throws {
    lock.withLock { values[key] = value }
  }

  public func removeValue(forKey key: String) throws {
    _ = lock.withLock { values.removeValue(forKey: key) }
  }
}
