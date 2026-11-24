import Foundation
import Observation

/// 쿼리 키. RN `api/queryKeys.ts`와 같은 모양으로, 앞부분으로 무효화한다
public enum QueryKeys {
  public static let settings = ["settings"]
  public static let commodities = ["commodities"]
  public static let commodityList = commodities + ["list"]

  /// 원자재 단위로 무효화할 수 있게 `["commodities", code, …]`로 시작한다
  public static func commodity(_ code: CommodityCode) -> [String] { commodities + [code.rawValue] }

  public static func disparity(_ code: CommodityCode, query: DisparityQuery) -> [String] {
    commodity(code) + [
      "disparity", query.basis.rawValue, String(query.maPeriod.rawValue), query.window.rawValue,
      query.levels.queryValue,
    ]
  }

  public static func contracts(_ code: CommodityCode) -> [String] {
    commodity(code) + ["contracts"]
  }

  /// 기준일이 nil(서버가 고른 최근 기준일)이면 `"latest"`
  public static func curve(_ code: CommodityCode, baseDate: LocalDate?) -> [String] {
    commodity(code) + ["curve", baseDate?.description ?? "latest"]
  }

  public static func etps(_ code: CommodityCode) -> [String] {
    commodity(code) + ["etps"]
  }

  /// ETP 상세는 원자재와 상관없이 id 하나다 (RN `queryKeys.etps.detail`)
  public static func etp(_ id: UUID) -> [String] { ["etps", id.uuidString.lowercased()] }

  /// 휴장 달력은 조회 범위마다 하나다 (RN `queryKeys.calendar`)
  public static func calendar(_ query: CalendarQuery) -> [String] {
    ["calendar", query.from.description, query.to.description]
  }
}

/// 서버 설정 조회와 낙관적 변경 (RN `api/useSettings.ts`, D-082).
/// 캐시에는 서버가 확인한 값만 두고, 아직 끝나지 않은 변경을 보낸 순서대로 얹어 `data`로 보인다.
/// 연달아 바꾸다 일부가 실패해도 되돌릴 값을 따로 기억하지 않는다
@MainActor
@Observable
public final class SettingsStore {
  public let query: Query<AppSettings>

  @ObservationIgnored private let repository: any SettingsRepository
  @ObservationIgnored private let cache: QueryCache
  /// 보낸 순서대로. 진행 중과 앞 변경을 기다리는 것 모두
  private var pending: [(id: Int, patch: SettingsPatch)] = []
  @ObservationIgnored private var nextID = 0
  /// 마지막으로 줄 세운 변경. 다음 변경은 이것이 끝난 뒤 보낸다(RN mutation `scope`)
  @ObservationIgnored private var tail: Task<(any Error)?, Never>?

  public init(repository: any SettingsRepository, cache: QueryCache) {
    self.repository = repository
    self.cache = cache
    query = cache.query(QueryKeys.settings) { try await repository.fetch() }
  }

  /// 서버 값에 진행 중인 변경을 얹은 값. 아직 받지 못했으면 nil
  public var data: AppSettings? {
    guard let settings = query.state.data else { return nil }
    return pending.reduce(settings) { $0.applying($1.patch) }
  }

  /// 변경을 줄 세워 보낸다. 반환된 Task는 그 변경이 끝나면 실패 원인(성공이면 nil)으로 끝난다.
  /// 실패하면 서버 값을 다시 조회해 맞춘다. 오류 줄은 부른 화면이 정한다(B는 띄우고 시간대·언어 맞춤은 띄우지 않는다)
  @discardableResult
  public func update(_ patch: SettingsPatch) -> Task<(any Error)?, Never> {
    let id = nextID
    nextID += 1
    pending.append((id, patch))
    let previous = tail
    let task = Task { () -> (any Error)? in
      _ = await previous?.value
      let error = await send(patch)
      pending.removeAll { $0.id == id }
      return error
    }
    tail = task
    return task
  }

  private func send(_ patch: SettingsPatch) async -> (any Error)? {
    // 진행 중인 조회가 PATCH보다 늦게 끝나 옛 값으로 덮지 않게 끊는다
    query.cancel()
    do {
      let settings = try await repository.update(patch)
      // 그사이 시작된 조회는 PATCH 반영 전 값을 읽었을 수 있어 끊고 응답 값을 넣는다
      query.setData(settings)
      // 알림 대상이 바뀌면 A 목록의 🔔도 바뀐다 (D-124)
      if patch.alertCommodity != nil { cache.invalidate(prefix: QueryKeys.commodityList) }
      return nil
    } catch {
      // 응답을 못 받았을 뿐 서버에 반영됐을 수 있어 서버 값을 다시 맞춘다. 기다리지 않는다
      query.invalidate()
      return error
    }
  }
}
