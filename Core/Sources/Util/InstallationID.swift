import Foundation
import Synchronization

/// 기기 키(installation ID, D-120). 서버가 설정·알림을 이 값으로 기기별로 나누고, 모든 인증 요청의
/// `X-Device-Id`로 보낸다. 접근 키와 따로 두어 키를 바꿔도 설정이 남는다.
/// RN `api/deviceId.ts`와 같은 규칙: 처음 부를 때 저장값을 읽고, 없거나 UUID v4 소문자 형식이 아니면
/// 새로 만들어 저장한다. 저장소 읽기·쓰기가 실패해도 이번 실행은 만든 값을 쓴다(다음 실행은 새 기기로 보임).
/// Keychain 항목은 앱을 지워도 남을 수 있어 재설치 뒤에도 같은 기기로 보일 수 있다(RN의 SecureStore도 Keychain이라 같다)
public final class InstallationID: Sendable {
  static let storeKey = "device-id"

  private let store: any SecureStore
  private let makeUUID: @Sendable () -> UUID
  private let cached = Mutex<String?>(nil)

  public init(
    store: any SecureStore = Keychain(),
    makeUUID: @escaping @Sendable () -> UUID = { UUID() }
  ) {
    self.store = store
    self.makeUUID = makeUUID
  }

  public var value: String {
    cached.withLock { cached in
      if let cached { return cached }
      let id: String
      if let stored = try? store.string(forKey: Self.storeKey), Self.isValid(stored) {
        id = stored
      } else {
        // Foundation UUID()는 v4이고 uuidString은 대문자라 RN·서버 형식(소문자)으로 바꾼다
        id = makeUUID().uuidString.lowercased()
        try? store.set(id, forKey: Self.storeKey)
      }
      cached = id
      return id
    }
  }

  static func isValid(_ value: String) -> Bool {
    value.wholeMatch(
      of: /[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/) != nil
  }
}
