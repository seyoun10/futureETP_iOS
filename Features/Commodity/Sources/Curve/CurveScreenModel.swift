import Core
import Observation

/// C-b 화면 Model: 기준일과 그 기준일의 커브 조회 (RN `CurveScreen` `CurveContent`·`useCurve`).
/// - 기준일 nil은 서버 기본값(D-1)이다. D-1을 고르면 기본값과 같은 조회 key를 쓴다. 화면을 떠나면 잊는다(기기 설정이 아님)
/// - 기준일을 옮기는 동안 이전 커브를 계속 보인다(버튼을 연달아 눌러도 화면이 비지 않게, RN `keepPreviousData`)
/// - 시트에서 고른 날짜와 응답 기준일이 다르면(휴장일) 옮긴 날짜를 잠깐 안내한다
@MainActor
@Observable
final class CurveScreenModel {
  /// 휴장일 안내를 보이는 시간
  static let movedNoticeDuration: Duration = .seconds(3)

  private(set) var baseDate: LocalDate?
  private(set) var query: Query<Curve>
  /// 시트에서 고른 날짜. 안내가 끝나면 지운다
  private(set) var picked: LocalDate?
  /// 기준일을 옮기기 전에 보이던 커브. 새 기준일 값이 올 때까지 대신 보인다
  private var previous: Curve?
  @ObservationIgnored private let curve: @MainActor (LocalDate?) -> Query<Curve>

  init(code: CommodityCode, queries: CommodityQueries) {
    let curve = queries.curve
    self.curve = { curve(code, $0) }
    query = curve(code, nil)
  }

  /// 화면에 그릴 조회 상태. 새 기준일 값이 아직 없고 실패하지도 않았으면 이전 커브를 넣는다
  var state: QueryState<Curve> {
    var state = query.state
    if state.data == nil, state.error == nil, let previous { state.data = previous }
    return state
  }

  /// 이전 커브를 대신 보이는 중이다
  var isPlaceholder: Bool { query.state.data == nil && state.data != nil }

  /// 휴장일을 골라 서버가 옮긴 기준일
  var movedTo: LocalDate? {
    guard let picked, !isPlaceholder, let resolved = query.state.data?.baseDate,
      resolved != picked
    else { return nil }
    return resolved
  }

  /// 이전·다음 버튼과 되돌리기. nil이면 기본값(D-1)
  func changeBaseDate(_ next: LocalDate?) {
    picked = nil
    move(to: next)
  }

  /// 시트에서 날짜를 골랐다
  func pickBaseDate(_ date: LocalDate, maxBaseDate: LocalDate) {
    picked = date
    // D-1이면 기본값과 같은 조회 key를 쓴다
    move(to: date == maxBaseDate ? nil : date)
  }

  /// 다음 거래일. D-1로 오면 기본값과 같은 조회 key를 쓴다
  static func next(of curve: Curve) -> LocalDate?? {
    curve.nextBaseDate.map { $0 == curve.maxBaseDate ? nil : $0 }
  }

  /// 휴장일 안내가 끝났다
  func clearMoved() {
    picked = nil
  }

  private func move(to next: LocalDate?) {
    guard next != baseDate else { return }
    previous = state.data
    baseDate = next
    query = curve(next)
  }
}
