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
          let size = geometry.size
          chart
            .overlay {
              ChartGestureSurface { model.handle($0, width: size.width) }
                .accessibilityIdentifier("spikeChart")
            }
            .overlay(alignment: .topLeading) { detail(size: size) }
        }
        .background(Theme.Colors.background)
        .sensoryFeedback(.selection, trigger: model.interaction.crosshairIndex) { _, new in
          new != nil
        }
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
        CanvasCandleChart(
          series: model.series, viewport: model.viewport, palette: model.palette,
          crosshairIndex: model.interaction.crosshairIndex)
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

    /// 상세 박스. 처음 잰 크기로 귀퉁이를 고르고, 재기 전에는 감춘다(RN `useDetailPlacement`)
    @ViewBuilder private func detail(size: CGSize) -> some View {
      if let index = model.interaction.crosshairIndex,
        let scale = PriceScale(series: model.series, indices: model.viewport.visibleIndices)
      {
        let box = DetailBoxContent(rows: model.detailRows(at: index))
          .onGeometryChange(for: CGSize.self, of: \.size) { model.detailSize = $0 }
        if let boxSize = model.detailSize {
          let area = CGRect(origin: .zero, size: size).insetBy(
            dx: Theme.Spacing.sm, dy: Theme.Spacing.sm)
          let corner = DetailCorner.leastCovered(
            area: area, box: boxSize,
            crosshairX: model.viewport.centerX(ofBar: index, width: size.width)
          ) { x0, x1 in
            model.series.markSpans(
              x0: x0, x1: x1, viewport: model.viewport, scale: scale, size: size)
          }
          let rect = corner.rect(in: area, box: boxSize)
          box.offset(x: rect.minX, y: rect.minY)
        } else {
          box.hidden()
        }
      }
    }
  }

  /// 상세 박스(RN `DetailBox`). 이름은 왼쪽, 값은 오른쪽
  private struct DetailBoxContent: View {
    let rows: [(String, String)]

    var body: some View {
      Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.md, verticalSpacing: 2) {
        ForEach(rows.indices, id: \.self) { i in
          GridRow {
            Text(verbatim: rows[i].0)
            Text(verbatim: rows[i].1).gridColumnAlignment(.trailing)
          }
        }
      }
      .font(.caption.monospacedDigit())
      .padding(Theme.Spacing.sm)
      .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Spacing.xs))
      .fixedSize()
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
    /// 가장 과거 봉이 보이면 한 번에 앞에 붙이는 봉(이전 3년)과 그 응답 대기 흉내
    static let olderBars = 756
    static let olderDelay = Duration.milliseconds(500)
    private static let all = SpikeSeries.make(barCount: barCounts.last ?? 756)
    /// 기본 기간(1년)
    static let defaultSpan = 252

    var renderer: Renderer = .canvas
    var barCount = 756 {
      didSet { reset() }
    }
    private(set) var series = all.suffix(756)
    private(set) var interaction = ChartInteraction(
      viewport: .lastBars(defaultSpan, of: 756))
    var detailSize: CGSize?
    private(set) var results: [Result] = []
    private(set) var isBenchmarking = false
    private var olderTask: Task<Void, Never>?
    let meter = FrameRateMeter()
    let palette = UpDownPalette(.kr)

    var viewport: CandleViewport { interaction.viewport }

    var viewportLabel: String {
      String(
        format: "view %.1f–%.1f (%.0f of %d bars)", viewport.lower, viewport.upper,
        viewport.span, viewport.barCount) + (olderTask == nil ? "" : " loading older…")
    }

    static func describe(_ report: FrameRateMeter.Report) -> String {
      String(
        format: "%.1f fps / %.0f Hz, worst %.1f ms, hitches %d (%d frames)", report.fps,
        report.targetFps, report.worstMs, report.hitches, report.frames)
    }

    func handle(_ event: ChartGestureSurface.Event, width: Double) {
      guard !isBenchmarking else { return }
      switch event {
      case .touchSequenceBegan: interaction.touchSequenceBegan()
      case .tapped: interaction.tapped()
      case .pressed(let x): interaction.pressed(atX: x, width: width)
      case .dragged(let deltaX, let x): interaction.dragged(byX: deltaX, atX: x, width: width)
      case .pinched(let scale, let startFocalX, let focalX):
        interaction.pinched(scale: scale, startFocalX: startFocalX, focalX: focalX, width: width)
      case .pinchEnded: interaction.pinchEnded()
      case .activeChanged(let active):
        if active { meter.begin() } else { meter.end() }
      }
      loadOlderIfNeeded()
    }

    /// 가장 과거 봉이 보이면 이전 3년을 앞에 붙인다. 보던 날짜 범위는 그대로 둔다 (D-104)
    private func loadOlderIfNeeded() {
      let count = series.bars.count
      guard olderTask == nil, viewport.showsFirstBar, count < Self.all.bars.count else { return }
      olderTask = Task { @MainActor [weak self] in
        try? await Task.sleep(for: Self.olderDelay)
        guard let self, !Task.isCancelled else { return }
        let added = min(Self.olderBars, Self.all.bars.count - count)
        series = Self.all.suffix(count + added)
        interaction.dataChanged(barCount: count + added, prepended: added)
        olderTask = nil
      }
    }

    func detailRows(at index: Int) -> [(String, String)] {
      let bar = series.bars[index]
      var rows = [
        ("#", "\(index)"), ("O", Self.price(bar.open)), ("H", Self.price(bar.high)),
        ("L", Self.price(bar.low)), ("C", Self.price(bar.close)),
      ]
      for line in series.lines {
        if let value = line.values[index] { rows.append((line.id, Self.price(value))) }
      }
      return rows
    }

    private static func price(_ value: Double) -> String { String(format: "%.2f", value) }

    /// 4초 동안 1년 범위로 끝에서 처음까지 옮긴 뒤, 최대 확대에서 전체까지 축소한다
    func runBenchmark(then next: (() -> Void)? = nil) {
      let count = barCount
      let renderer = renderer
      isBenchmarking = true
      meter.begin(duration: 4) { [weak self] progress in
        guard let self else { return }
        interaction.viewport = Self.scripted(progress: progress, barCount: count)
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

    private func reset() {
      olderTask?.cancel()
      olderTask = nil
      series = Self.all.suffix(barCount)
      interaction.reset(viewport: .lastBars(Self.defaultSpan, of: barCount))
    }
  }
#endif
