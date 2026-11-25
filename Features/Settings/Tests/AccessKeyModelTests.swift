import Core
import Foundation
import Testing

@testable import Settings

private let validKey = String(repeating: "a", count: 43)

/// 정해 둔 결과를 돌려주고 받은 키를 기록한다
private final class StubVerifier: AccessKeyVerifier, @unchecked Sendable {
  var error: (any Error)?
  private(set) var keys: [String] = []

  init(error: (any Error)? = nil) {
    self.error = error
  }

  func verify(_ key: String) async throws {
    keys.append(key)
    if let error { throw error }
  }
}

private struct FailingStore: SecureStore {
  struct Failure: Error {}
  func string(forKey key: String) throws -> String? { nil }
  func set(_ value: String, forKey key: String) throws { throw Failure() }
  func removeValue(forKey key: String) throws {}
}

struct AccessKeyModelTests {
  @Test func savesVerifiedKeyAndCallsOnSaved() async {
    let store = AccessKeyStore(store: InMemorySecureStore())
    let verifier = StubVerifier()
    var saved = 0
    let model = AccessKeyModel(store: store, verifier: verifier, onSaved: { saved += 1 })
    model.input = "  \(validKey)\n"
    #expect(await model.submit())
    #expect(verifier.keys == [validKey])
    #expect(store.key == validKey)
    #expect(saved == 1)
    #expect(model.message == nil)
  }

  @Test func badFormatIsNotSentToServer() async {
    let verifier = StubVerifier()
    let model = AccessKeyModel(
      store: AccessKeyStore(store: InMemorySecureStore()), verifier: verifier)
    model.input = "short"
    #expect(await model.submit() == false)
    #expect(verifier.keys.isEmpty)
    #expect(model.message == .notice(.badFormat))
  }

  @Test func emptyInputCannotSubmit() async {
    let verifier = StubVerifier()
    let model = AccessKeyModel(
      store: AccessKeyStore(store: InMemorySecureStore()), verifier: verifier)
    model.input = "  "
    #expect(model.canSubmit == false)
    #expect(await model.submit() == false)
    #expect(verifier.keys.isEmpty)
    #expect(model.message == nil)
  }

  @Test func serverRejectionShowsRejectedAndKeepsOldKey() async {
    let store = AccessKeyStore(store: InMemorySecureStore(), fallback: "old")
    let model = AccessKeyModel(
      store: store, verifier: StubVerifier(error: AppError(.unauthorized, status: 401)))
    model.input = validKey
    #expect(await model.submit() == false)
    #expect(model.message == .rejected)
    #expect(store.key == "old")
  }

  @Test func otherFailureShowsItsErrorCode() async {
    let model = AccessKeyModel(
      store: AccessKeyStore(store: InMemorySecureStore()),
      verifier: StubVerifier(error: AppError(.network)))
    model.input = validKey
    #expect(await model.submit() == false)
    #expect(model.message == .error(.network))
  }

  @Test func keychainFailureIsInternalAndNotSaved() async {
    var saved = 0
    let store = AccessKeyStore(store: FailingStore())
    let model = AccessKeyModel(store: store, verifier: StubVerifier(), onSaved: { saved += 1 })
    model.input = validKey
    #expect(await model.submit() == false)
    #expect(model.message == .error(.internal))
    #expect(store.key == nil)
    #expect(saved == 0)
  }

  @Test func rejectedStoredKeyShowsRejectedUntilLeaving() {
    let store = AccessKeyStore(store: InMemorySecureStore(), fallback: "old")
    store.report(AppError(.unauthorized))
    let model = AccessKeyModel(store: store, verifier: StubVerifier())
    #expect(model.message == .rejected)
    model.leave()
    #expect(store.isRejected == false)
    #expect(model.message == nil)
  }

  @Test func noticeComesBeforeServerError() async {
    let model = AccessKeyModel(
      store: AccessKeyStore(store: InMemorySecureStore()),
      verifier: StubVerifier(error: AppError(.network)))
    model.input = validKey
    _ = await model.submit()
    model.cameraUnavailable()
    #expect(model.message == .notice(.cameraUnavailable))
    model.startScan()
    #expect(model.message == nil)
  }

  @Test func scannedRequiresQrPrefix() {
    let model = AccessKeyModel(
      store: AccessKeyStore(store: InMemorySecureStore()), verifier: StubVerifier())
    #expect(model.scanned(validKey) == nil)
    #expect(model.message == .notice(.notKeyQr))
    #expect(model.scanned(AccessKey.qrPrefix + validKey) == validKey)
    #expect(model.message == nil)
  }

  @Test func canGoBackOnlyWithKey() {
    let none = AccessKeyModel(
      store: AccessKeyStore(store: InMemorySecureStore()), verifier: StubVerifier())
    let some = AccessKeyModel(
      store: AccessKeyStore(store: InMemorySecureStore(), fallback: "old"), verifier: StubVerifier()
    )
    #expect(none.canGoBack == false)
    #expect(some.canGoBack)
  }
}

/// 오류 줄 문구 키가 앱 카탈로그에 그대로 있어야 한다.
/// `LocalizedStringKey("accessKey.\(…)")`로 보간하면 키가 `accessKey.%@`가 되어 키 이름이 그대로 보였다
struct AccessKeyMessageKeyTests {
  private static func catalogKeys() throws -> Set<String> {
    let url = URL(filePath: #filePath)
      .deletingLastPathComponent()
      .appending(path: "../../../App/Resources/Localizable.xcstrings")
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
    let strings = (object as? [String: Any])?["strings"] as? [String: Any]
    return Set((strings ?? [:]).keys)
  }

  @Test func everyMessageKeyIsInTheCatalog() throws {
    let keys = try Self.catalogKeys()
    let notices: [AccessKeyModel.Notice] = [.badFormat, .notKeyQr, .cameraUnavailable]
    let messages: [AccessKeyModel.Message] =
      notices.map { .notice($0) } + [.rejected] + AppError.Code.allCases.map { .error($0) }
    for message in messages {
      #expect(keys.contains(message.key), "\(message.key)")
    }
    #expect(AccessKeyModel.Message.notice(.badFormat).key == "accessKey.badFormat")
  }
}
