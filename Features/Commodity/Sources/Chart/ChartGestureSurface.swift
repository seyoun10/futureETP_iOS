import SwiftUI
import UIKit

/// 차트 위에 겹치는 투명 터치 면. UIKit 인식기 4개(탭·길게 누르기·한 손가락 끌기·핀치)의 관계를 직접 정한다.
/// SwiftUI `LongPressGesture`는 손가락 위치를 주지 않고, 제스처 사이 실패 의존(`require(toFail:)`)도 없어 UIKit으로 둔다
struct ChartGestureSurface: UIViewRepresentable {
  enum Event {
    /// 손가락이 하나도 없던 면에 새 터치가 시작됐다
    case touchSequenceBegan
    case tapped
    /// 길게 누른 채 있거나 끈다(0.3초 뒤부터)
    case pressed(x: Double)
    /// 한 손가락 끌기. `deltaX`는 직전 이벤트 뒤 이동량
    case dragged(deltaX: Double, x: Double)
    case pinched(scale: Double, startFocalX: Double, focalX: Double)
    case pinchEnded
    /// 끌기·핀치가 시작되거나 모두 끝났다(측정용)
    case activeChanged(Bool)
  }

  /// RN `LONG_PRESS_MS`
  static let longPressDuration: TimeInterval = 0.3

  let onEvent: (Event) -> Void

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.backgroundColor = .clear
    context.coordinator.install(on: view)
    return view
  }

  func updateUIView(_ view: UIView, context: Context) {
    context.coordinator.onEvent = onEvent
  }

  func makeCoordinator() -> Coordinator { Coordinator(onEvent: onEvent) }

  @MainActor
  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    var onEvent: (Event) -> Void
    private weak var view: UIView?
    private var pinchStartFocalX = 0.0
    private var active = Set<ObjectIdentifier>()
    /// 길게 누르기(십자선 끌기)·끌기·핀치 동안 120Hz를 요청한다
    let frameRate = FrameRateBoost()

    init(onEvent: @escaping (Event) -> Void) { self.onEvent = onEvent }

    func install(on view: UIView) {
      self.view = view
      let press = UILongPressGestureRecognizer(target: self, action: #selector(handlePress(_:)))
      press.minimumPressDuration = ChartGestureSurface.longPressDuration
      let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
      // 길게 누르다 뗀 것을 탭으로 보지 않는다
      tap.require(toFail: press)
      let drag = UIPanGestureRecognizer(target: self, action: #selector(handleDrag(_:)))
      drag.maximumNumberOfTouches = 1
      // 움직이지 않고 0.3초 누르면 끌기가 아니라 길게 누르기다
      drag.require(toFail: press)
      let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
      for recognizer in [press, tap, drag, pinch] as [UIGestureRecognizer] {
        recognizer.delegate = self
        view.addGestureRecognizer(recognizer)
      }
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
      if recognizer.state == .ended { onEvent(.tapped) }
    }

    @objc private func handlePress(_ recognizer: UILongPressGestureRecognizer) {
      boost(recognizer)
      guard recognizer.state == .began || recognizer.state == .changed else { return }
      onEvent(.pressed(x: recognizer.location(in: view).x))
    }

    @objc private func handleDrag(_ recognizer: UIPanGestureRecognizer) {
      track(recognizer)
      guard recognizer.state == .began || recognizer.state == .changed else { return }
      let delta = recognizer.translation(in: view).x
      recognizer.setTranslation(.zero, in: view)
      onEvent(.dragged(deltaX: delta, x: recognizer.location(in: view).x))
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
      track(recognizer)
      let focalX = recognizer.location(in: view).x
      switch recognizer.state {
      case .began:
        pinchStartFocalX = focalX
        fallthrough
      case .changed:
        // 손가락 하나를 떼면 위치가 남은 손가락으로 튀므로, 두 손가락일 때만 따라간다
        guard recognizer.numberOfTouches >= 2 else { return }
        onEvent(
          .pinched(scale: recognizer.scale, startFocalX: pinchStartFocalX, focalX: focalX))
      default:
        onEvent(.pinchEnded)
      }
    }

    private func boost(_ recognizer: UIGestureRecognizer) {
      switch recognizer.state {
      case .began: frameRate.hold(ObjectIdentifier(recognizer))
      case .ended, .cancelled, .failed: frameRate.release(ObjectIdentifier(recognizer))
      default: break
      }
    }

    private func track(_ recognizer: UIGestureRecognizer) {
      boost(recognizer)
      let wasActive = !active.isEmpty
      switch recognizer.state {
      case .began: active.insert(ObjectIdentifier(recognizer))
      case .ended, .cancelled, .failed: active.remove(ObjectIdentifier(recognizer))
      default: break
      }
      if wasActive != !active.isEmpty { onEvent(.activeChanged(!active.isEmpty)) }
    }

    // 끌기와 핀치, 길게 누르기와 핀치는 함께 인식한다(핀치 뒤 길게 누르기는 ChartInteraction이 막는다)
    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
      true
    }

    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent
    ) -> Bool {
      // 모든 손가락이 막 닿은 이벤트면 새 터치다. 인식기마다 불리니 탭 인식기에서만 알린다
      if gestureRecognizer is UITapGestureRecognizer,
        let touches = event.allTouches, !touches.isEmpty,
        touches.allSatisfy({ $0.phase == .began })
      {
        onEvent(.touchSequenceBegan)
      }
      return true
    }
  }
}
