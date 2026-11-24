import Core
import SwiftUI
import UIKit

/// B 설정 (screens.md B, RN `SettingsScreen`). 표시 설정은 기기에, 이격도차트·알림 설정은 서버에 기기별로 저장한다
/// (D-047, D-120). 바꾼 값은 바로 낙관적으로 저장한다 (D-082)
public struct SettingsView: View {
  @State private var model: SettingsScreenModel
  private let hasKey: Bool
  private let onOpenAlerts: () -> Void
  private let onOpenAccessKey: () -> Void
  private let onOpenDataSources: () -> Void
  @State private var confirmsReset = false
  @State private var resetTaps = 0
  @State private var keyboardShown = false
  @Environment(DisplaySettings.self) private var display
  @Environment(\.locale) private var locale

  public init(
    store: SettingsStore, hasKey: Bool, onOpenAlerts: @escaping () -> Void,
    onOpenAccessKey: @escaping () -> Void, onOpenDataSources: @escaping () -> Void
  ) {
    _model = State(initialValue: SettingsScreenModel(store: store))
    self.hasKey = hasKey
    self.onOpenAlerts = onOpenAlerts
    self.onOpenAccessKey = onOpenAccessKey
    self.onOpenDataSources = onOpenDataSources
  }

  public var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        if let error = model.saveError { SaveErrorLine(error: error) }
        generalSection
        SectionHeader(title: t("settings.sectionDisparity"))
        disparitySection
        SectionHeader(title: t("settings.sectionOther"))
        LinkRow(
          label: t("settings.accessKey"), value: hasKey ? t("accessKey.saved") : nil,
          description: t("settings.accessKeyDesc"), identifier: "openAccessKey",
          action: onOpenAccessKey)
        LinkRow(
          label: t("settings.dataSources"), description: t("settings.dataSourcesDesc"),
          identifier: "openDataSources", action: onOpenDataSources)
      }
    }
    .scrollDismissesKeyboard(.interactively)
    // 앱 번들 줄은 키패드가 덮는다. 화면이 키패드만큼 줄어(rare-level 칸이 가려지지 않게) 줄이 키패드 위로
    // 따라 올라오므로, 키패드가 보이는 동안은 빼서 덮인 것처럼 둔다
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if !keyboardShown { FooterLine(AppBundleText.text(locale: locale)) }
    }
    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification))
    {
      _ in keyboardShown = true
    }
    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification))
    {
      _ in keyboardShown = false
    }
    .queryLifecycle(model.store.query)
    .background(Theme.Colors.background)
    .backTitleBar(Text("settings.title")) {
      Button {
        resetTaps += 1
        confirmsReset = true
      } label: {
        Image(systemName: "arrow.counterclockwise")
          .foregroundStyle(Theme.Colors.text)
      }
      .accessibilityLabel(Text("settings.reset"))
      .accessibilityIdentifier("resetSettings")
    }
    .sensoryFeedback(.selection, trigger: resetTaps)
    .alert(Text("settings.resetTitle"), isPresented: $confirmsReset) {
      Button("common.cancel", role: .cancel) {}
      Button("settings.reset", role: .destructive) { model.reset(display: display) }
    } message: {
      Text("settings.resetMessage")
    }
    .accessibilityIdentifier("settings")
  }

  // 언어·등락 색은 기기 설정이다. 언어는 푸시 문구에 쓰므로 서버에도 보낸다(마지막으로 바꾼 기기의 값)
  @ViewBuilder private var generalSection: some View {
    @Bindable var display = display
    SectionHeader(title: t("settings.sectionGeneral"))
    SegmentedRow(
      t("settings.language"),
      options: AppLanguage.allCases.map {
        .init($0, t($0 == .ko ? "settings.languageKo" : "settings.languageEn"))
      },
      value: display.language, description: t("settings.languageDesc")
    ) { language in
      display.language = language
      model.save(SettingsPatch(locale: language))
    }
    SegmentedRow(
      t("settings.upDownStyle"),
      options: UpDownStyle.allCases.map {
        .init($0, t("settings.upDownStyle\($0.rawValue.uppercased())"))
      },
      value: display.upDownStyle, description: t("settings.upDownStyleDesc")
    ) { display.upDownStyle = $0 }
  }

  // 조회 중에는 아무것도 고르지 않은 채로 보여 준다. 알림 행은 B-a로 간다
  @ViewBuilder private var disparitySection: some View {
    let settings = model.store.data
    if let error = model.store.query.state.error, settings == nil {
      ErrorView(error) { Task { await model.store.query.refetch() } }
    } else {
      SegmentedRow(
        t("settings.basis"),
        options: Basis.allCases.map { .init($0, t("settings.basis\($0.rawValue)")) },
        value: settings?.basis, description: t("settings.basisDesc")
      ) { model.save(SettingsPatch(basis: $0)) }
      SegmentedRow(
        t("settings.maPeriod"),
        options: MAPeriod.allCases.map { .init($0, "\($0.rawValue)") },
        value: settings?.maPeriod, description: t("settings.maPeriodDesc")
      ) { model.save(SettingsPatch(maPeriod: $0)) }
      SegmentedRow(
        t("settings.window"),
        options: DistributionWindow.allCases.map {
          .init($0, $0 == .all ? t("settings.windowALL") : String($0.rawValue.dropFirst()))
        },
        value: settings?.window, description: t("settings.windowDesc")
      ) { model.save(SettingsPatch(window: $0)) }
      RareLevelsInput(levels: settings?.rareLevels) {
        model.save(SettingsPatch(rareLevels: $0))
      }
      LinkRow(
        label: t("settings.alerts"),
        value: settings.map {
          $0.alertCommodity.map { t("commodities.\($0.rawValue)") } ?? t("settings.alertOff")
        },
        description: t("settings.alertsDesc"), identifier: "openAlerts", action: onOpenAlerts)
    }
  }

  private func t(_ key: String, _ values: [String: String] = [:]) -> String {
    L10n.string(key, values, locale: locale)
  }
}

/// B 맨 아래 앱 번들 줄. iOS는 OTA가 없어(재설치) 늘 빌드에 내장이고, 런타임 자리에 앱 버전(빌드 번호)을 쓴다
enum AppBundleText {
  static func text(locale: Locale, info: [String: Any] = Bundle.main.infoDictionary ?? [:])
    -> String
  {
    let version = info["CFBundleShortVersionString"] as? String ?? "-"
    let build = info["CFBundleVersion"] as? String ?? "-"
    return L10n.string(
      "settings.bundleEmbedded", ["runtime": "\(version) (\(build))"], locale: locale)
  }
}
