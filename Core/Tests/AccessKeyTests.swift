import Core
import Testing

private let validKey = String(repeating: "aZ09_-", count: 7) + "x"  // 43자

@Suite struct AccessKeyTests {
  @Test func acceptsBareKeyWhenPasted() {
    #expect(AccessKey.parse(validKey) == validKey)
    #expect(AccessKey.parse("  \(validKey)\n") == validKey)
  }

  @Test func acceptsPrefixedKey() {
    #expect(AccessKey.parse(AccessKey.qrPrefix + validKey) == validKey)
    #expect(AccessKey.parse(AccessKey.qrPrefix + validKey, requirePrefix: true) == validKey)
  }

  @Test func qrRequiresPrefix() {
    #expect(AccessKey.parse(validKey, requirePrefix: true) == nil)
  }

  @Test(arguments: [
    "", String(validKey.dropLast()), validKey + "a", String(validKey.dropLast()) + "=",
    String(validKey.dropLast()) + "+", "futureetp-key:v2:" + validKey,
  ])
  func rejectsBadFormat(input: String) {
    #expect(AccessKey.parse(input) == nil)
  }
}

@MainActor
@Suite struct AccessKeyStoreTests {
  @Test func readsStoredKeyFirst() {
    let store = InMemorySecureStore([AccessKeyStore.storeKey: "stored"])
    #expect(AccessKeyStore(store: store, fallback: "dev").key == "stored")
  }

  @Test func fallsBackWhenNothingStored() {
    #expect(AccessKeyStore(store: InMemorySecureStore(), fallback: "dev").key == "dev")
    #expect(AccessKeyStore(store: InMemorySecureStore()).hasKey == false)
  }

  @Test func treatsUnreadableStoreAsNoKey() {
    #expect(AccessKeyStore(store: FailingStore()).key == nil)
  }

  @Test func saveWritesStoreThenMemoryAndClearsRejection() throws {
    let store = InMemorySecureStore()
    let keys = AccessKeyStore(store: store, fallback: "old")
    keys.report(AppError(.unauthorized))
    try keys.save("new")
    #expect(keys.key == "new")
    #expect(keys.isRejected == false)
    #expect(try store.string(forKey: AccessKeyStore.storeKey) == "new")
  }

  @Test func failedSaveKeepsOldKey() {
    let keys = AccessKeyStore(store: FailingStore(), fallback: "old")
    #expect(throws: (any Error).self) { try keys.save("new") }
    #expect(keys.key == "old")
  }

  @Test func onlyUnauthorizedWithKeyIsRejection() {
    let keys = AccessKeyStore(store: InMemorySecureStore(), fallback: "k")
    keys.report(AppError(.network))
    #expect(keys.isRejected == false)
    keys.report(AppError(.unauthorized))
    #expect(keys.isRejected)
    #expect(keys.key == "k")
    keys.clearRejected()
    #expect(keys.isRejected == false)

    let empty = AccessKeyStore(store: InMemorySecureStore())
    empty.report(AppError(.unauthorized))
    #expect(empty.isRejected == false)
  }
}

private struct FailingStore: SecureStore {
  struct Broken: Error {}
  func string(forKey key: String) throws -> String? { throw Broken() }
  func set(_ value: String, forKey key: String) throws { throw Broken() }
  func removeValue(forKey key: String) throws { throw Broken() }
}
