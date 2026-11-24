import Foundation
import Testing

@testable import Core

@Suite struct InstallationIDTests {
  struct BrokenStore: SecureStore {
    struct Failure: Error {}
    func string(forKey key: String) throws -> String? { throw Failure() }
    func set(_ value: String, forKey key: String) throws { throw Failure() }
    func removeValue(forKey key: String) throws { throw Failure() }
  }

  @Test func createsLowercaseUUIDv4AndSavesIt() throws {
    let store = InMemorySecureStore()
    let id = InstallationID(store: store).value
    #expect(InstallationID.isValid(id))
    #expect(try store.string(forKey: InstallationID.storeKey) == id)
  }

  @Test func reusesStoredValueAcrossLaunches() {
    let store = InMemorySecureStore()
    let first = InstallationID(store: store).value
    #expect(InstallationID(store: store).value == first)
  }

  @Test func keepsSameValueWithinLaunch() {
    let installationID = InstallationID(store: InMemorySecureStore())
    #expect(installationID.value == installationID.value)
  }

  @Test(arguments: [
    "", "not-a-uuid",
    "6F1C2B3A-1D2E-4F3A-8B9C-0D1E2F3A4B5C",  // 대문자
    "6f1c2b3a-1d2e-1f3a-8b9c-0d1e2f3a4b5c",  // v1
    "6f1c2b3a-1d2e-4f3a-cb9c-0d1e2f3a4b5c",  // variant 아님
  ])
  func replacesInvalidStoredValue(stored: String) throws {
    let store = InMemorySecureStore([InstallationID.storeKey: stored])
    let id = InstallationID(store: store).value
    #expect(id != stored)
    #expect(InstallationID.isValid(id))
    #expect(try store.string(forKey: InstallationID.storeKey) == id)
  }

  @Test func usesGeneratedValueWhenStoreFails() {
    let uuid = UUID(uuidString: "6F1C2B3A-1D2E-4F3A-8B9C-0D1E2F3A4B5C")!
    let installationID = InstallationID(store: BrokenStore(), makeUUID: { uuid })
    #expect(installationID.value == "6f1c2b3a-1d2e-4f3a-8b9c-0d1e2f3a4b5c")
    #expect(installationID.value == "6f1c2b3a-1d2e-4f3a-8b9c-0d1e2f3a4b5c")
  }
}
