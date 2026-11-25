import Core
import Foundation
import Testing
import UserNotifications

@testable import Settings

private let server: [Double] = [1, 2, 4, 8, 16]

// RN `SettingsScreen.test.tsx`의 rare-level 입력 경우
struct RareLevelsDraftTests {
  @Test func showsServerValuesUntilEdited() {
    var draft = RareLevelsDraft()
    #expect(draft.texts(levels: nil) == ["", "", "", "", ""])
    #expect(draft.texts(levels: [0.5, 1, 2.5, 10, 20]) == ["0.5", "1", "2.5", "10", "20"])
    draft.change(0, to: "3", levels: server)
    #expect(draft.texts(levels: server) == ["3", "2", "4", "8", "16"])
  }

  @Test func savesSortedOnCommitAndReturnsToServerValues() throws {
    var draft = RareLevelsDraft()
    draft.change(0, to: "32", levels: server)
    draft.change(0, to: "30,5", levels: server)
    let committed = draft.commit(levels: server)
    let saved = try #require(committed)
    #expect(saved.values == [2, 4, 8, 16, 30.5])
    #expect(draft.problem == nil)
    #expect(draft.texts(levels: saved.values) == ["2", "4", "8", "16", "30.5"])
  }

  @Test func limitsLength() {
    var draft = RareLevelsDraft()
    draft.change(1, to: "12.345", levels: server)
    #expect(draft.texts(levels: server)[1] == "12.3")
  }

  @Test(arguments: ["50", "0", "1.25", "", " ", "1e1", "0x8", "-1", "1 2"])
  func rejectsInvalid(_ text: String) {
    var draft = RareLevelsDraft()
    draft.change(4, to: text, levels: server)
    #expect(draft.commit(levels: server) == nil)
    #expect(draft.problem == .invalid)
    // 고치던 값은 그대로 두고, 다시 고치면 오류를 지운다
    #expect(draft.texts(levels: server)[4] == String(text.prefix(4)))
    draft.change(4, to: "16", levels: server)
    #expect(draft.problem == nil)
  }

  @Test func rejectsDuplicate() {
    var draft = RareLevelsDraft()
    draft.change(4, to: "8.0", levels: server)
    #expect(draft.commit(levels: server) == nil)
    #expect(draft.problem == .duplicate)
  }

  @Test func sameValuesSaveNothing() {
    var draft = RareLevelsDraft()
    draft.change(0, to: "1.0", levels: server)
    #expect(draft.commit(levels: server) == nil)
    #expect(draft.problem == nil)
    #expect(draft.texts(levels: server) == ["1", "2", "4", "8", "16"])
  }

  @Test func nothingToCommitWithoutEditsOrServerValues() {
    var draft = RareLevelsDraft()
    #expect(draft.commit(levels: server) == nil)
    draft.change(0, to: "3", levels: nil)
    #expect(draft.commit(levels: nil) == nil)
  }
}

struct QuietTimeSlotsTests {
  @Test func fortyEightHalfHourSlots() {
    #expect(QuietTimeSlots.minutes.count == 48)
    #expect(QuietTimeSlots.minutes.first == 0 && QuietTimeSlots.minutes.last == 1410)
  }

  @Test func formatsTwentyFourHour() {
    #expect(QuietTimeSlots.text(0) == "00:00")
    #expect(QuietTimeSlots.text(450) == "07:30")
    #expect(QuietTimeSlots.text(1410) == "23:30")
  }

  @Test func nextDayWhenCrossingMidnight() {
    #expect(QuietTimeSlots.endsNextDay(QuietTimeSlots.defaultValue))
    #expect(!QuietTimeSlots.endsNextDay(QuietTime(startMin: 60, endMin: 120)))
  }

  @Test func pickingKeepsStartAndEndDifferent() {
    let value = QuietTime(startMin: 1380, endMin: 420)
    #expect(
      QuietTimeSlots.picking(0, for: .start, in: value) == QuietTime(startMin: 0, endMin: 420))
    #expect(
      QuietTimeSlots.picking(60, for: .end, in: value) == QuietTime(startMin: 1380, endMin: 60))
    #expect(QuietTimeSlots.picking(420, for: .start, in: value) == nil)
    #expect(QuietTimeSlots.picking(1380, for: .end, in: value) == nil)
    #expect(QuietTimeSlots.picking(1380, for: .start, in: value) == nil)
  }
}

struct PushPermissionTests {
  @Test func mapsAuthorizationStatus() {
    #expect(!PushPermission.state(for: .notDetermined).granted)
    #expect(PushPermission.state(for: .notDetermined).canAskAgain)
    #expect(PushPermission.state(for: .denied) == .init(granted: false, canAskAgain: false))
    #expect(PushPermission.state(for: .authorized).granted)
    #expect(PushPermission.state(for: .provisional).granted)
  }
}

/// PATCH를 손으로 끝내는 repository. 받은 본문을 기록한다
private actor ManualRepository: SettingsRepository {
  private(set) var patches: [SettingsPatch] = []
  private var updates: [CheckedContinuation<AppSettings, any Error>] = []

  func fetch() async throws -> AppSettings { Self.settings }

  func update(_ patch: SettingsPatch) async throws -> AppSettings {
    patches.append(patch)
    return try await withCheckedThrowingContinuation { updates.append($0) }
  }

  var waiting: Int { updates.count }

  func finish(_ result: Result<AppSettings, any Error>) {
    updates.removeFirst().resume(with: result)
  }

  static let settings = AppSettings(
    locale: .ko, timezone: "Asia/Seoul", basis: .kr, maPeriod: .days50, window: .years5,
    rareLevels: [1, 2.5, 5, 10, 20], alertCommodity: .gc, quietTime: nil)
}

@MainActor
private func waitUntil(_ condition: () async -> Bool) async {
  for _ in 0..<1000 {
    if await condition() { return }
    await Task.yield()
  }
}

@MainActor
@Suite struct SettingsScreenModelTests {
  private let repository = ManualRepository()

  @Test func showsOnlyTheLatestSaveError() async {
    let model = SettingsScreenModel(
      store: SettingsStore(repository: repository, cache: QueryCache()))
    let first = model.save(SettingsPatch(basis: .us))
    await waitUntil { await repository.waiting == 1 }
    await repository.finish(.failure(AppError(.network)))
    await first.value
    #expect((model.saveError as? AppError)?.code == .network)

    // 새 변경을 보내면 지우고, 앞 변경이 늦게 실패해도 띄우지 않는다
    let second = model.save(SettingsPatch(maPeriod: .days20))
    #expect(model.saveError == nil)
    let third = model.save(SettingsPatch(window: .all))
    await waitUntil { await repository.waiting == 1 }
    await repository.finish(.failure(AppError(.timeout)))
    await second.value
    #expect(model.saveError == nil)
    await waitUntil { await repository.waiting == 1 }
    await repository.finish(.success(ManualRepository.settings))
    await third.value
    #expect(model.saveError == nil)
  }

  @Test func resetKeepsAlertsAndSendsDeviceLanguage() async throws {
    let suite = "SettingsScreenModelTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    let display = DisplaySettings(defaults: defaults, locale: Locale(identifier: "en_US"))
    display.language = .ko
    display.upDownStyle = .kr
    let model = SettingsScreenModel(
      store: SettingsStore(repository: repository, cache: QueryCache()))
    let reset = model.reset(display: display)
    #expect(display.language == .en && display.upDownStyle == .us)
    await waitUntil { await repository.waiting == 1 }
    await repository.finish(.success(ManualRepository.settings))
    await reset.value
    var expected = SettingsPatch.disparityDefaults
    expected.locale = .en
    #expect(await repository.patches == [expected])
    defaults.removePersistentDomain(forName: suite)
  }
}

// RN `SettingsScreen.test.tsx` "B 앱 번들 정보", Flutter `Flutter prod: 1.0.0 (빌드 1)`
struct AppBundleTextTests {
  private let template = "iOS {{variant}}: {{version}} (빌드 {{build}})"

  @Test func showsVariantVersionAndBuild() {
    let info: [String: Any] = ["CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "1"]
    #expect(
      L10n.fill(template, AppBundleText.values(variant: .production, info: info))
        == "iOS prod: 1.0.0 (빌드 1)")
    #expect(
      L10n.fill(template, AppBundleText.values(variant: .development, info: info))
        == "iOS dev: 1.0.0 (빌드 1)")
  }

  @Test func showsDashWithoutVersion() {
    #expect(
      L10n.fill(template, AppBundleText.values(variant: .production, info: [:]))
        == "iOS prod: - (빌드 -)")
  }
}

// RN `useKeepFocusedInputVisible.test`의 `overlapToScroll`
struct KeyboardAvoidanceTests {
  @Test func scrollsByHiddenAmountIncludingGap() {
    #expect(KeyboardAvoidance.overlap(inputBottom: 500, visibleBottom: 520) == 28)
  }

  @Test func staysWhenVisible() {
    #expect(KeyboardAvoidance.overlap(inputBottom: 400, visibleBottom: 520) == 0)
    #expect(KeyboardAvoidance.overlap(inputBottom: 472, visibleBottom: 520) == 0)
  }
}
