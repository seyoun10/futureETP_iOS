import Foundation

/// 드래그(이동)는 보이는 봉 수가 그대로라 기간 선택 표시를 남기고, 핀치(확대·축소)는 지운다 (screens.md C-a)
enum ChartGesture: Equatable, Sendable {
  case pan
  case zoom
}

/// C-a·C-c 기간 선택과 제스처 상태(screens.md C-a 기간과 제스처, D-107).
/// 기간 버튼 범위(최근 `period.bars`개 봉, "홈")에서 제스처로 벗어나면 [↻]를 띄우고, 핀치였으면 선택 표시 대신
/// 가장 가까운 기간에 테두리를 둔다. 범위가 그대로인 제스처(최근 끝에서 더 밀기 등)는 벗어난 것으로 보지 않는다
/// (RN `useChartPeriodView`·`viewportChange.ts` `nextAway`)
struct ChartViewState: Equatable {
  /// 범위가 같다고 볼 봉 수 차이
  static let tolerance = 1e-3

  private(set) var interaction: ChartInteraction
  private(set) var period: ChartPeriod
  /// 홈에서 벗어나게 한 제스처. nil이면 홈이다
  private(set) var away: ChartGesture?
  /// 보이는 범위를 알린 횟수. 보이는 봉 범위가 바뀌거나, 범위가 그대로여도 드래그·핀치가 끝나면 늘어난다
  /// (가장 과거 끝에서 다시 끌면 이전 3년을 다시 시도, D-139, RN `useChartViewport` `reportRange`)
  private(set) var rangeReports = 0
  /// 이번 터치에서 드래그·핀치로 범위를 움직였는지
  private var movedInGesture = false

  init(period: ChartPeriod, barCount: Int) {
    self.period = period
    interaction = ChartInteraction(viewport: Self.home(period, barCount: barCount))
  }

  var viewport: CandleViewport { interaction.viewport }
  var crosshairIndex: Int? { interaction.crosshairIndex }

  /// 선택 표시할 기간. 핀치로 범위를 바꿨으면 nil
  var selectedPeriod: ChartPeriod? { away == .zoom ? nil : period }

  /// 핀치로 범위를 바꿨을 때 보이는 봉 수와 가장 가까운 기간(테두리 표시)
  var nearestPeriod: ChartPeriod? {
    away == .zoom
      ? .nearest(visibleBars: viewport.span, totalBars: viewport.barCount) : nil
  }

  /// [↻] 되돌리기 버튼을 띄운다
  var showsReset: Bool { away != nil }

  /// 기간의 최근 위치(마지막 `period.bars`개 봉)
  static func home(_ period: ChartPeriod, barCount: Int) -> CandleViewport {
    .lastBars(min(period.bars, barCount), of: barCount)
  }

  /// 차트 터치. 십자선이 있을 때의 끌기는 십자선만 옮겨 범위를 바꾸지 않는다.
  /// `locked`(이전 3년을 받는 중, D-108)면 탭·길게 누르기·드래그·핀치를 무시한다
  mutating func handle(_ event: ChartGestureSurface.Event, width: Double, locked: Bool = false) {
    let before = viewport.visibleIndices
    switch event {
    case .touchSequenceBegan: interaction.touchSequenceBegan()
    case .pinchEnded: interaction.pinchEnded()
    case .activeChanged(let active):
      if !active, movedInGesture {
        movedInGesture = false
        rangeReports += 1
      }
    case _ where locked: break
    case .tapped: interaction.tapped()
    case .pressed(let x): interaction.pressed(atX: x, width: width)
    case .dragged(let deltaX, let x):
      let moves = interaction.crosshairIndex == nil && !interaction.isPinching
      interaction.dragged(byX: deltaX, atX: x, width: width)
      if moves {
        movedInGesture = true
        updateAway(.pan)
      }
    case .pinched(let scale, let startFocalX, let focalX):
      interaction.pinched(scale: scale, startFocalX: startFocalX, focalX: focalX, width: width)
      movedInGesture = true
      updateAway(.zoom)
    }
    reportIfChanged(from: before)
  }

  /// 기간 칩을 눌렀다. 그 기간의 최근 위치로 맞추고 십자선을 지운다
  mutating func select(_ period: ChartPeriod) {
    self.period = period
    resetView()
  }

  /// [↻]: 고른 기간의 최근 위치로 돌아가고 십자선을 지운다
  mutating func resetView() {
    let before = viewport.visibleIndices
    away = nil
    interaction.reset(viewport: Self.home(period, barCount: viewport.barCount))
    reportIfChanged(from: before)
  }

  /// 차트 데이터가 바뀌었다(앞에 과거 봉 `prepended`개가 붙음·새로고침). 십자선은 지운다.
  /// 홈이면 같은 기간의 최근 위치로 다시 맞추고, 아니면 보던 날짜 범위를 그대로 둔다 (D-104)
  mutating func dataChanged(barCount: Int, prepended: Int) {
    let before = viewport.visibleIndices
    if away == nil {
      interaction.reset(viewport: Self.home(period, barCount: barCount))
    } else {
      interaction.dataChanged(barCount: barCount, prepended: prepended)
      updateAway(nil)
    }
    reportIfChanged(from: before)
  }

  private mutating func reportIfChanged(from before: ClosedRange<Int>?) {
    if viewport.visibleIndices != before { rangeReports += 1 }
  }

  /// 홈으로 돌아왔으면 nil, 처음 벗어났으면 그 제스처. 한 번 핀치하면 홈에 돌아올 때까지 핀치로 둔다
  private mutating func updateAway(_ gesture: ChartGesture?) {
    let home = Self.home(period, barCount: viewport.barCount)
    let sameSpan = abs(viewport.span - home.span) < Self.tolerance
    if sameSpan && abs(viewport.lower - home.lower) < Self.tolerance {
      away = nil
    } else if let gesture, away == nil {
      away = gesture
    } else if gesture == .zoom, away == .pan, !sameSpan {
      // 드래그로 벗어난 뒤 핀치로 배율까지 바꿨다
      away = .zoom
    }
  }
}
