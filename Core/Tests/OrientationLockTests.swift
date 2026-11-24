import Testing
import UIKit

@testable import Core

@MainActor
struct OrientationLockTests {
  @Test func startsInPortrait() {
    #expect(OrientationLock.mask == .portrait)
  }

  // [⟲]는 잠금 상태가 아니라 지금 창 모양의 반대로 잠근다 (D-076)
  @Test func toggleLocksTheOppositeOfTheWindowShape() {
    #expect(OrientationLock.mask(togglingFrom: false) == .landscape)
    #expect(OrientationLock.mask(togglingFrom: true) == .portrait)
  }
}
