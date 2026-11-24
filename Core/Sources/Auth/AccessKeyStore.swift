import Foundation
import Observation

/// 서버 접근 키를 읽고 쓰는 유일한 곳 (D-044, D-072).
/// 저장된 키는 만들 때 한 번 읽어 메모리에 둔다. 저장된 키가 없으면 dev 변형만 `DEV_API_TOKEN`을 쓴다
@MainActor
@Observable
public final class AccessKeyStore {
  public static let storeKey = "access-key"

  /// 지금 쓰는 키. nil이면 B-b가 첫 화면이다
  public private(set) var key: String?
  /// 저장된 키를 서버가 거절함(`UNAUTHORIZED`). 앱 루트가 보고 B-b로 보낸다.
  /// 키는 새 키를 확인할 때까지 지우지 않는다
  public private(set) var isRejected = false

  @ObservationIgnored private let store: any SecureStore

  /// - Parameter fallback: 저장된 키가 없을 때 쓸 키(dev 변형의 `DEV_API_TOKEN`)
  public init(store: any SecureStore = Keychain(), fallback: String? = nil) {
    self.store = store
    // 읽기 실패(Keychain 손상 등)는 키 없음으로 보고 B-b에서 다시 넣게 한다
    let stored = (try? store.string(forKey: Self.storeKey)).flatMap { $0.isEmpty ? nil : $0 }
    key = stored ?? fallback
  }

  public var hasKey: Bool { key != nil }

  /// 서버에서 확인한 키만 넘긴다. 저장에 성공해야 메모리 값도 바꾼다
  public func save(_ newKey: String) throws {
    try store.set(newKey, forKey: Self.storeKey)
    key = newKey
    isRejected = false
  }

  /// 저장된 키로 보낸 요청의 실패를 넘긴다. 키가 있을 때의 `UNAUTHORIZED`만 거절로 본다
  /// (키가 없어 보내지 않은 요청도 `UNAUTHORIZED`다)
  public func report(_ error: any Error) {
    guard key != nil, (error as? AppError)?.code == .unauthorized else { return }
    isRejected = true
  }

  /// B-b를 떠나면 지운다. 옛 키로 다시 거절되면 다시 B-b로 온다
  public func clearRejected() {
    isRejected = false
  }
}
