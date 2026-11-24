import Foundation

/// 차트 터치 상태(C-a·C-c, screens.md C-a 길게 누르기, D-056). 보이는 범위와 십자선 봉을 함께 바꾼다.
/// 제스처 인식은 `ChartGestureSurface`가 하고, 여기는 그 결과로 상태만 고친다 (RN `charts/useChartViewport.ts`)
struct ChartInteraction: Equatable {
  var viewport: CandleViewport
  /// 십자선이 붙은 봉. 손을 떼도 남고, 차트를 한 번 더 누르면 사라진다
  private(set) var crosshairIndex: Int?
  /// 이번 터치에서 핀치가 시작됐는지. 핀치하다 멈춰도 십자선을 띄우지 않는다(손을 모두 떼고 다시 눌러야 한다)
  private var pinchedInTouch = false
  /// 진행 중인 핀치의 시작 범위
  private var pinchStart: CandleViewport?

  init(viewport: CandleViewport) {
    self.viewport = viewport
  }

  var isPinching: Bool { pinchStart != nil }

  /// 손가락이 하나도 없던 차트에 새 터치가 시작됐다
  mutating func touchSequenceBegan() {
    pinchedInTouch = false
  }

  /// 짧게 눌렀다 뗐다
  mutating func tapped() {
    crosshairIndex = nil
  }

  /// 길게 누른 채 있거나 끈다. 손가락 아래 봉에 십자선을 붙인다
  mutating func pressed(atX x: Double, width: Double) {
    guard !pinchedInTouch, let index = viewport.barIndex(atX: x, width: width) else { return }
    crosshairIndex = index
  }

  /// 한 손가락 끌기. `deltaX`는 직전 호출 뒤 이동량이다. 십자선이 있으면 범위 대신 십자선을 옮긴다
  mutating func dragged(byX deltaX: Double, atX x: Double, width: Double) {
    if crosshairIndex != nil {
      pressed(atX: x, width: width)
      return
    }
    // 핀치 중에는 핀치가 이동까지 맡는다
    guard !isPinching, width > 0 else { return }
    viewport = viewport.panned(byBars: -deltaX / width * viewport.span)
  }

  /// 핀치. 시작 때 손가락 가운데(`startFocalX`)에 있던 지점이 지금 손가락 가운데(`focalX`)를 따라간다(두 손가락 이동 포함)
  mutating func pinched(scale: Double, startFocalX: Double, focalX: Double, width: Double) {
    guard width > 0 else { return }
    pinchedInTouch = true
    let start = pinchStart ?? viewport
    pinchStart = start
    viewport = start.zoomed(scale: scale, startAnchor: startFocalX / width, anchor: focalX / width)
  }

  mutating func pinchEnded() {
    pinchStart = nil
  }

  /// 차트 데이터가 바뀌었다(앞에 과거 봉 `prepended`개가 붙음·새로고침). 보던 날짜 범위는 그대로 두고,
  /// 봉 순번이 바뀌므로 십자선을 지운다. 핀치 중이면 시작 범위도 같이 옮겨 화면이 튀지 않게 한다 (D-104)
  mutating func dataChanged(barCount: Int, prepended: Int) {
    viewport = viewport.rebased(barCount: barCount, prepended: prepended)
    pinchStart = pinchStart?.rebased(barCount: barCount, prepended: prepended)
    crosshairIndex = nil
  }

  /// 다른 데이터로 바꾸고 범위를 새로 맞춘다(기간 버튼·원자재 전환)
  mutating func reset(viewport: CandleViewport) {
    self.viewport = viewport
    crosshairIndex = nil
    pinchStart = nil
  }
}
