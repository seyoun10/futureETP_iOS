import Testing

@testable import Commodity

@MainActor
struct FrameRateBoostTests {
  private final class Holder {}

  @Test func staysOnUntilEveryHolderReleases() {
    let boost = FrameRateBoost()
    let drag = Holder()
    let pinch = Holder()
    #expect(boost.isActive == false)
    boost.hold(ObjectIdentifier(drag))
    boost.hold(ObjectIdentifier(pinch))
    boost.release(ObjectIdentifier(drag))
    #expect(boost.isActive)
    boost.release(ObjectIdentifier(pinch))
    #expect(boost.isActive == false)
  }

  @Test func holdingTwiceCountsOnce() {
    let boost = FrameRateBoost()
    let drag = Holder()
    boost.hold(ObjectIdentifier(drag))
    boost.hold(ObjectIdentifier(drag))
    boost.release(ObjectIdentifier(drag))
    #expect(boost.isActive == false)
  }

  @Test func requestsUpTo120Hz() {
    #expect(FrameRateBoost.range.preferred == 120)
    #expect(FrameRateBoost.range.maximum == 120)
  }
}
