import Core
import SwiftUI

/// B-a 알림 설정 (screens.md B-a, RN `AlertSettingsScreen`). 바꾼 값은 바로 서버에 저장한다.
/// 적용 기준은 B 이격도차트 설정을 그대로 쓰므로 여기서는 요약만 보인다
public struct AlertSettingsView: View {
  @State private var model: SettingsScreenModel
  @State private var permission = PushPermission()
  @Environment(\.locale) private var locale
  @Environment(\.scenePhase) private var scenePhase

  public init(store: SettingsStore) {
    _model = State(initialValue: SettingsScreenModel(store: store))
  }

  public var body: some View {
    let settings = model.store.data
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        PermissionBanner(permission: permission)
        if let error = model.saveError { SaveErrorLine(error: error) }
        if let error = model.store.query.state.error, settings == nil {
          ErrorView(error) { Task { await model.store.query.refetch() } }
        } else {
          SegmentedRow(
            t("alertSettings.commodity"),
            options: [.init(nil, t("alertSettings.commodityNone"))]
              + CommodityCode.allCases.map { .init($0, t("commodities.\($0.rawValue)")) },
            // 조회 중에는 아무것도 고르지 않는다. 바깥 nil = 모름, 안쪽 nil = 없음
            value: settings.map(\.alertCommodity), stacked: true
          ) { model.save(SettingsPatch(alertCommodity: .some($0))) }
          if let settings {
            criteria(settings)
            QuietTimeSection(value: settings.quietTime) {
              model.save(SettingsPatch(quietTime: .some($0)))
            }
          }
        }
        Text("alertSettings.guide")
          .font(.system(size: Theme.FontSize.caption))
          .foregroundStyle(Theme.Colors.textSecondary)
          .padding(Theme.Spacing.lg)
      }
    }
    .queryLifecycle(model.store.query)
    .background(Theme.Colors.background)
    .backTitleBar(Text("alertSettings.title"))
    .task(id: scenePhase) {
      // OS 설정에서 바꾸고 돌아올 수 있어 다시 활성화될 때마다 읽는다
      if scenePhase == .active { await permission.refresh() }
    }
    .accessibilityIdentifier("alertSettings")
  }

  @ViewBuilder private func criteria(_ settings: AppSettings) -> some View {
    let window =
      settings.window == .all
      ? t("settings.windowALL")
      : t(
        "alertSettings.criteriaWindowYears", ["years": String(settings.window.rawValue.dropFirst())]
      )
    SectionHeader(title: t("alertSettings.criteria"))
    Group {
      Text(
        verbatim: t(
          "alertSettings.criteriaChart",
          [
            "basis": t("settings.basis\(settings.basis.rawValue)"),
            "maPeriod": "\(settings.maPeriod.rawValue)", "window": window,
          ]))
      Text(
        verbatim: t(
          "alertSettings.criteriaLevels",
          ["levels": settings.rareLevels.map(RareLevels.text).joined(separator: "/")]))
    }
    .font(.system(size: Theme.FontSize.body))
    .foregroundStyle(Theme.Colors.text)
    .padding(.horizontal, Theme.Spacing.lg)
    .padding(.vertical, Theme.Spacing.xs)
  }

  private func t(_ key: String, _ values: [String: String] = [:]) -> String {
    L10n.string(key, values, locale: locale)
  }
}

/// 권한이 꺼져 있을 때만 보인다. 확인 전에는 숨긴다
private struct PermissionBanner: View {
  let permission: PushPermission

  var body: some View {
    if let state = permission.state, !state.granted {
      HStack(spacing: Theme.Spacing.md) {
        Text("alertSettings.permissionOff")
          .font(.system(size: Theme.FontSize.body))
          .foregroundStyle(Theme.Colors.text)
          .frame(maxWidth: .infinity, alignment: .leading)
        Button {
          Task { await permission.request() }
        } label: {
          Text(state.canAskAgain ? "alertSettings.allow" : "alertSettings.openSettings")
            .font(.system(size: Theme.FontSize.body))
            .foregroundStyle(Theme.Colors.text)
            .padding(.horizontal, Theme.Spacing.md)
            .frame(minHeight: Theme.Size.touchTarget)
            .background(Theme.Colors.surfaceSelected)
            .clipShape(.rect(cornerRadius: Theme.Spacing.xs))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("permissionButton")
      }
      .padding(.horizontal, Theme.Spacing.lg)
      .padding(.vertical, Theme.Spacing.md)
      .background(Theme.Colors.surface)
    }
  }
}
