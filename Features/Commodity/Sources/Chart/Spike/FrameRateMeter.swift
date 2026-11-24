#if DEBUG
  import QuartzCore

  /// 화면 갱신 간격을 재는 측정기(C-a 스파이크). 메인 스레드가 그리기로 막히면 다음 갱신이 늦어져 긴 간격으로 잡힌다
  @Observable
  final class FrameRateMeter {
    struct Report: Equatable {
      let frames: Int
      let seconds: Double
      /// 가장 긴 갱신 간격(ms)
      let worstMs: Double
      /// 목표 간격의 1.5배를 넘긴 갱신 수
      let hitches: Int
      /// 기기 목표 갱신 빈도(Hz)
      let targetFps: Double

      var fps: Double { seconds > 0 ? Double(frames) / seconds : 0 }
    }

    private(set) var report: Report?
    private(set) var isRunning = false

    private var link: CADisplayLink?
    private var proxy: Proxy?
    private var start: CFTimeInterval = 0
    private var last: CFTimeInterval = 0
    private var frames = 0
    private var worst: CFTimeInterval = 0
    private var hitches = 0
    private var target: CFTimeInterval = 1 / 60
    private var duration: CFTimeInterval?
    private var onFrame: ((Double) -> Void)?

    /// 측정을 시작한다. `duration`을 주면 그 시간 뒤 멈추고, 매 갱신 `onFrame(진행률 0…1)`을 부른다
    func begin(duration: CFTimeInterval? = nil, onFrame: ((Double) -> Void)? = nil) {
      end()
      self.duration = duration
      self.onFrame = onFrame
      frames = 0
      worst = 0
      hitches = 0
      start = 0
      last = 0
      let proxy = Proxy { [weak self] link in self?.tick(link) }
      let link = CADisplayLink(target: proxy, selector: #selector(Proxy.tick(_:)))
      link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
      link.add(to: .main, forMode: .common)
      self.proxy = proxy
      self.link = link
      isRunning = true
    }

    func end() {
      guard let link else { return }
      link.invalidate()
      self.link = nil
      proxy = nil
      onFrame = nil
      isRunning = false
      if last > start {
        report = Report(
          frames: frames, seconds: last - start, worstMs: worst * 1000, hitches: hitches,
          targetFps: (1 / target).rounded())
      }
    }

    private func tick(_ link: CADisplayLink) {
      let now = link.timestamp
      if start == 0 {
        start = now
        last = now
        target = link.targetTimestamp - link.timestamp
      } else {
        let interval = now - last
        frames += 1
        worst = max(worst, interval)
        if interval > target * 1.5 { hitches += 1 }
        last = now
      }
      if let duration {
        let progress = min((now - start) / duration, 1)
        let onFrame = onFrame
        // 마지막 갱신은 보고서를 만든 뒤 알린다(콜백이 이번 측정의 보고서를 읽게)
        if progress >= 1 { end() }
        onFrame?(progress)
      } else {
        onFrame?(0)
      }
    }

    /// `CADisplayLink`가 target을 강하게 잡으므로 측정기 대신 이 객체를 넘긴다
    private final class Proxy: NSObject {
      let handler: (CADisplayLink) -> Void
      init(_ handler: @escaping (CADisplayLink) -> Void) { self.handler = handler }
      @objc func tick(_ link: CADisplayLink) { handler(link) }
    }
  }
#endif
