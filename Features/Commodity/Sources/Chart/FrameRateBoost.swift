import QuartzCore

/// 차트 제스처 동안 ProMotion 기기에 120Hz 갱신을 요청한다.
/// 스크롤 뷰가 아닌 인식기로 SwiftUI 상태를 바꾸면 시스템이 빈도를 올리지 않아 60Hz에 머문다(14P Animation Hitches, IOS-008).
/// 선호 빈도를 단 `CADisplayLink`가 돌고 있는 동안만 앱 갱신 빈도가 올라가므로, 제스처가 끝나면 바로 멈춘다
@MainActor
final class FrameRateBoost {
  static let range = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)

  private let tick = Tick()
  private var link: CADisplayLink?
  private var holders = Set<ObjectIdentifier>()

  var isActive: Bool { link != nil }

  /// `holder`가 빈도를 요청한다. 같은 holder를 두 번 넣어도 한 번으로 센다
  func hold(_ holder: ObjectIdentifier) {
    holders.insert(holder)
    guard link == nil else { return }
    let link = CADisplayLink(target: tick, selector: #selector(Tick.tick(_:)))
    link.preferredFrameRateRange = Self.range
    link.add(to: .main, forMode: .common)
    self.link = link
  }

  /// `holder`의 요청을 거둔다. 남은 요청이 없으면 멈춘다
  func release(_ holder: ObjectIdentifier) {
    holders.remove(holder)
    guard holders.isEmpty else { return }
    link?.invalidate()
    link = nil
  }

  isolated deinit {
    link?.invalidate()
  }

  /// 할 일 없는 target. `CADisplayLink`가 target을 강하게 잡으므로 이 객체 대신 넘긴다
  private final class Tick: NSObject {
    @objc func tick(_ link: CADisplayLink) {}
  }
}
