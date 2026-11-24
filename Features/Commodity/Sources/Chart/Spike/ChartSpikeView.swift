#if DEBUG
  import Core
  import SwiftUI

  /// C-a 차트 스파이크 화면(dev 전용, TODO 4단계). Canvas와 Swift Charts를 같은 봉·같은 제스처로 그려 갱신 빈도를 잰다.
  /// 개발 확인 화면이라 문구를 i18n 리소스에 넣지 않는다
  public struct ChartSpikeView: View {
    @State private var model = ChartSpikeModel()

    public init() {}

    public var body: some View {
      VStack(spacing: Theme.Spacing.sm) {
        controls
        GeometryReader { geometry in
          chart
            .contentShape(Rectangle())
            .gesture(gestures(width: geometry.size.width))
        }
        .background(Theme.Colors.background)
        .accessibilityIdentifier("spikeChart")
        results
      }
      .padding(.horizontal, Theme.Spacing.sm)
      .foregroundStyle(Theme.Colors.text)
      .background(Theme.Colors.background)
      .navigationTitle(Text(verbatim: "C-a spike"))
      .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var chart: some View {
      switch model.renderer {
      case .canvas:
        CanvasCandleChart(series: model.series, viewport: model.viewport, palette: model.palette)
      case .swiftCharts:
        SwiftChartsCandleChart(
          series: model.series, viewport: model.viewport, palette: model.palette)
      }
    }

    private var controls: some View {
      VStack(spacing: Theme.Spacing.xs) {
        Picker(selection: $model.renderer) {
          ForEach(ChartSpikeModel.Renderer.allCases) { Text(verbatim: $0.rawValue).tag($0) }
        } label: {
          EmptyView()
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("spikeRenderer")
        Picker(selection: $model.barCount) {
          ForEach(ChartSpikeModel.barCounts, id: \.self) { Text(verbatim: "\($0) bars").tag($0) }
        } label: {
          EmptyView()
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("spikeBarCount")
        HStack {
          Button {
            model.runBenchmark()
          } label: {
            Text(verbatim: "Run scripted")
          }
          .accessibilityIdentifier("spikeRunOne")
          Spacer()
          Button {
            model.runAllBenchmarks()
          } label: {
            Text(verbatim: "Run all")
          }
          .accessibilityIdentifier("spikeRunAll")
        }
        .disabled(model.isBenchmarking)
        .font(.footnote)
      }
    }

    private var results: some View {
      VStack(alignment: .leading, spacing: 2) {
        Text(verbatim: model.viewportLabel)
        if let live = model.meter.report {
          Text(verbatim: "last: \(ChartSpikeModel.describe(live))")
        }
        ForEach(model.results) { result in
          Text(verbatim: result.label)
        }
      }
      .font(.caption.monospaced())
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityIdentifier("spikeResults")
    }

    private func gestures(width: Double) -> some Gesture {
      let pinch = MagnifyGesture(minimumScaleDelta: 0)
        .onChanged { value in
          model.pinch(scale: value.magnification, startAnchor: value.startAnchor.x)
        }
        .onEnded { _ in model.endGesture() }
      let drag = DragGesture(minimumDistance: 4)
        .onChanged { value in model.drag(translation: value.translation.width, width: width) }
        .onEnded { _ in model.endGesture() }
      return SimultaneousGesture(pinch, drag)
    }
  }

  @Observable
  final class ChartSpikeModel {
    enum Renderer: String, CaseIterable, Identifiable {
      case canvas = "Canvas"
      case swiftCharts = "Swift Charts"
      var id: Self { self }
    }

    struct Result: Identifiable {
      let id = UUID()
      let renderer: Renderer
      let barCount: Int
      let report: FrameRateMeter.Report

      var label: String {
        "\(renderer.rawValue) \(barCount): \(ChartSpikeModel.describe(report))"
      }
    }

    /// 3년(756봉)과, 이전 3년을 세 번 이어 받은 뒤(약 3,000봉) (D-104)
    static let barCounts = [756, 3_024]
    /// 기본 기간(1년)
    static let defaultSpan = 252

    var renderer: Renderer = .canvas
    var barCount = 756 {
      didSet { reset() }
    }
    private(set) var series = SpikeSeries.make(barCount: 756)
    private(set) var viewport = CandleViewport.lastBars(defaultSpan, of: 756)
    private(set) var results: [Result] = []
    private(set) var isBenchmarking = false
    let meter = FrameRateMeter()
    let palette = UpDownPalette(.kr)

    private var gestureStart: CandleViewport?
    private var pinching = false

    var viewportLabel: String {
      String(
        format: "view %.1f–%.1f (%.0f bars)", viewport.lower, viewport.upper, viewport.span)
    }

    static func describe(_ report: FrameRateMeter.Report) -> String {
      String(
        format: "%.1f fps / %.0f Hz, worst %.1f ms, hitches %d (%d frames)", report.fps,
        report.targetFps, report.worstMs, report.hitches, report.frames)
    }

    func pinch(scale: Double, startAnchor: Double) {
      guard !isBenchmarking else { return }
      beginGestureIfNeeded()
      pinching = true
      guard let start = gestureStart else { return }
      viewport = start.zoomed(scale: scale, startAnchor: startAnchor, anchor: startAnchor)
    }

    func drag(translation: Double, width: Double) {
      guard !isBenchmarking, !pinching, width > 0 else { return }
      beginGestureIfNeeded()
      guard let start = gestureStart else { return }
      viewport = start.panned(byBars: -translation / width * start.span)
    }

    func endGesture() {
      guard gestureStart != nil else { return }
      gestureStart = nil
      pinching = false
      meter.end()
    }

    /// 4초 동안 1년 범위로 끝에서 처음까지 옮긴 뒤, 최대 확대에서 전체까지 축소한다
    func runBenchmark(then next: (() -> Void)? = nil) {
      let count = barCount
      let renderer = renderer
      isBenchmarking = true
      meter.begin(duration: 4) { [weak self] progress in
        guard let self else { return }
        viewport = Self.scripted(progress: progress, barCount: count)
        if progress >= 1 {
          isBenchmarking = false
          if let report = meter.report {
            results.append(Result(renderer: renderer, barCount: count, report: report))
          }
          next?()
        }
      }
    }

    /// 렌더러 2개 × 봉 수 2개를 차례로 잰다
    func runAllBenchmarks() {
      results = []
      let runs = Renderer.allCases.flatMap { r in Self.barCounts.map { (r, $0) } }
      run(runs[...])
    }

    private func run(_ runs: ArraySlice<(Renderer, Int)>) {
      guard let (renderer, count) = runs.first else { return }
      self.renderer = renderer
      barCount = count
      // 화면이 새 렌더러로 한 번 그려진 뒤 잰다
      Task { @MainActor [weak self] in
        try? await Task.sleep(for: .milliseconds(300))
        self?.runBenchmark { [weak self] in self?.run(runs.dropFirst()) }
      }
    }

    static func scripted(progress: Double, barCount: Int) -> CandleViewport {
      let total = Double(barCount)
      if progress < 0.5 {
        let span = Double(min(defaultSpan, barCount))
        let upper = total - progress * 2 * (total - span)
        return CandleViewport(barCount: barCount, lower: upper - span, upper: upper)
      }
      let t = (progress - 0.5) * 2
      let minSpan = CandleViewport.minVisibleBars
      let span = minSpan * pow(total / minSpan, t)
      return CandleViewport(barCount: barCount, lower: total - span, upper: total)
    }

    private func beginGestureIfNeeded() {
      guard gestureStart == nil else { return }
      gestureStart = viewport
      meter.begin()
    }

    private func reset() {
      series = SpikeSeries.make(barCount: barCount)
      viewport = .lastBars(Self.defaultSpan, of: barCount)
    }
  }
#endif
