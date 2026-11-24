import Core
import SwiftUI

/// C 원자재 화면: title-bar `[←] 원자재명 (심볼) 🔔 … [⟲] [⚙]`, 탭 콘텐츠, tab-bar, 기준 시각 줄
/// (screens.md C, RN `CommodityTabsLayout`·`CommodityTitleBar`).
/// - 탭은 처음 열 때 만들고 다른 탭으로 가도 남겨 둔다(차트 보던 범위·조회 상태 유지). 스와이프로 탭을 바꾸지 않는다
/// - 가로 모드는 title-bar와 차트만 남긴다(tab-bar·기준 시각 줄 숨김, D-103). 차트는 좌우 safe area 안쪽 (D-125)
/// - ETP 탭으로 가거나 C를 떠나면(A·B) 세로로 돌아간다 (D-076)
/// - 뒤로 가기는 [←]로만 한다. 쓸어서 뒤로 가지 않는다 (D-105)
public struct CommodityView: View {
  private let code: CommodityCode
  private let settings: SettingsStore
  private let queries: CommodityQueries
  private let isAlert: Bool
  private let alertOff: Bool
  private let onBack: () -> Void
  private let onOpenSettings: () -> Void
  @State private var selection = CommodityTab.initial
  /// 한 번이라도 연 탭. 열린 탭은 숨겨도 남긴다
  @State private var opened: Set<CommodityTab> = [CommodityTab.initial]
  @State private var periods = ChartPeriods()
  @State private var footerTime: FooterTime?
  @State private var backTaps = 0
  @State private var rotateTaps = 0
  @Environment(\.isLandscape) private var isLandscape

  /// - Parameters:
  ///   - isAlert: 이 기기의 알림 대상 원자재다. 제목 뒤에 🔔
  ///   - alertOff: 알림 대상 원자재가 없다. [⚙]에 빨간 점 (D-124)
  public init(
    code: CommodityCode, settings: SettingsStore, queries: CommodityQueries,
    isAlert: Bool, alertOff: Bool,
    onBack: @escaping () -> Void, onOpenSettings: @escaping () -> Void
  ) {
    self.code = code
    self.settings = settings
    self.queries = queries
    self.isAlert = isAlert
    self.alertOff = alertOff
    self.onBack = onBack
    self.onOpenSettings = onOpenSettings
  }

  public var body: some View {
    VStack(spacing: 0) {
      ZStack {
        ForEach(CommodityTab.allCases, id: \.self) { tab in
          if opened.contains(tab) {
            let isSelected = tab == selection
            content(tab)
              .opacity(isSelected ? 1 : 0)
              .allowsHitTesting(isSelected)
              .accessibilityHidden(!isSelected)
              // 숨긴 탭의 기준 시각은 줄에 올리지 않는다
              .transformPreference(TabFooterTimeKey.self) { if !isSelected { $0 = nil } }
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      if !isLandscape {
        CommodityTabBar(current: selection, select: select)
        FreshnessLine(footerTime)
      }
    }
    .onPreferenceChange(TabFooterTimeKey.self) { footerTime = $0 }
    .background(Theme.Colors.background)
    .environment(periods)
    .navigationBarBackButtonHidden()
    .toolbar {
      ToolbarItem(placement: .topBarLeading) { titleBar }
      ToolbarItemGroup(placement: .topBarTrailing) {
        if selection.canRotate { rotateButton }
        SettingsButton(alertOff: alertOff, action: onOpenSettings)
      }
    }
    .sensoryFeedback(.selection, trigger: backTaps)
    .sensoryFeedback(.selection, trigger: rotateTaps)
    .onDisappear { OrientationLock.lockPortrait() }
  }

  @ViewBuilder private func content(_ tab: CommodityTab) -> some View {
    switch tab {
    case .disparity:
      DisparityTabView(code: code, settings: settings, queries: queries)
        .accessibilityIdentifier("commodityTab-\(tab.rawValue)")
    default:
      // 남은 탭 화면은 4단계에서 하나씩 채운다
      Color.clear
        .accessibilityIdentifier("commodityTab-\(tab.rawValue)")
    }
  }

  private func select(_ tab: CommodityTab) {
    guard tab != selection else { return }
    selection = tab
    opened.insert(tab)
    if !tab.canRotate { OrientationLock.lockPortrait() }
  }

  private var nameKey: String { "commodities.\(code.rawValue)" }

  /// [←] 원자재명 (심볼) 🔔. 제목은 [←] 바로 오른쪽에 왼쪽 정렬 (screens.md 공통 title-bar)
  private var titleBar: some View {
    HStack(spacing: Theme.Spacing.sm) {
      Button {
        backTaps += 1
        onBack()
      } label: {
        Image(systemName: "chevron.left")
          .foregroundStyle(Theme.Colors.text)
      }
      .accessibilityLabel(Text("common.back"))
      .accessibilityIdentifier("back")
      HStack(spacing: Theme.Spacing.xs) {
        // 보간한 리터럴은 `%@` 키가 되므로 문자열로 만든 뒤 키로 쓴다
        Text(LocalizedStringKey(nameKey))
        Text(verbatim: "(\(code.rawValue))")
        if isAlert {
          Text(verbatim: "🔔")
            .font(.system(size: Theme.FontSize.caption))
            .accessibilityLabel(Text("commodityList.alert"))
        }
      }
      .font(.system(size: Theme.FontSize.title, weight: .semibold))
      .foregroundStyle(Theme.Colors.text)
      .lineLimit(1)
      .fixedSize()
      .accessibilityAddTraits(.isHeader)
    }
  }

  /// 바뀔 방향의 휴대폰 회전 모양. 차트 [↻] 되돌리기와 구분한다 (screens.md C)
  private var rotateButton: some View {
    Button {
      rotateTaps += 1
      OrientationLock.toggle(isLandscape: isLandscape)
    } label: {
      Image(systemName: isLandscape ? "iphone" : "iphone.landscape")
        .foregroundStyle(Theme.Colors.text)
    }
    .accessibilityLabel(Text("commodity.rotate"))
    .accessibilityIdentifier("rotate")
  }
}

/// 하단 탭 줄. 라벨은 탭 가운데, 선택한 탭은 기간 칩과 같은 둥근 `surfaceSelected` 배경과 흰 굵은 글자.
/// 이미 고른 탭을 다시 누르면 햅틱을 주지 않는다 (D-109)
private struct CommodityTabBar: View {
  let current: CommodityTab
  let select: (CommodityTab) -> Void
  @State private var taps = 0

  var body: some View {
    HStack(spacing: 0) {
      ForEach(CommodityTab.allCases, id: \.self) { tab in
        let isSelected = tab == current
        Button {
          if !isSelected { taps += 1 }
          select(tab)
        } label: {
          Text(tab.titleKey)
            .font(.system(size: Theme.FontSize.body, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Theme.Colors.text : Theme.Colors.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: Theme.Size.touchTarget)
            .background(
              isSelected ? Theme.Colors.surfaceSelected : .clear,
              in: .rect(cornerRadius: Theme.Radius.md)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("tab-\(tab.rawValue)")
      }
    }
    .padding(.horizontal, Theme.Spacing.xs)
    .padding(.vertical, Theme.Spacing.xs)
    .overlay(alignment: .top) {
      Rectangle().fill(Theme.Colors.barSeparator).frame(height: 1)
    }
    .sensoryFeedback(.selection, trigger: taps)
  }
}
