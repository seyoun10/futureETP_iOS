import Core
import SwiftUI

/// 차트 탭 공용 치수 (RN `charts/chartLayout.ts`)
enum ChartLayout {
  /// 차트 아래 x축 라벨 자리
  static let xLabelHeight: CGFloat = 20
  /// 기간 칩·기준일 버튼 줄 높이(세 차트 탭이 같다, D-117)
  static let footerHeight = Theme.Size.touchTarget
}

/// C-a·C-c 기간 칩 한 줄(screens.md C-a 기간과 제스처, D-102). 칩이 줄 너비를 똑같이 나눠 스크롤 없이 다 보인다.
/// 핀치로 범위를 바꿨으면 선택 표시 대신 가장 가까운 기간에 테두리를 둔다 (RN `charts/PeriodChips.tsx`)
struct PeriodChips: View {
  let selected: ChartPeriod?
  let nearest: ChartPeriod?
  let select: (ChartPeriod) -> Void
  @State private var taps = 0

  var body: some View {
    HStack(spacing: 0) {
      ForEach(ChartPeriod.allCases, id: \.self) { period in
        let isSelected = period == selected
        let isNearest = !isSelected && period == nearest
        Button {
          // 이미 고른 칩은 햅틱 없이 범위만 맞춘다 (D-109)
          if !isSelected { taps += 1 }
          select(period)
        } label: {
          Text(period.titleKey)
            .font(.system(size: Theme.FontSize.body, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Theme.Colors.text : Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity, minHeight: ChartLayout.footerHeight)
            .background(
              isSelected ? Theme.Colors.surfaceSelected : .clear,
              in: .rect(cornerRadius: Theme.Radius.md)
            )
            .overlay {
              if isNearest {
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                  .strokeBorder(Theme.Colors.surfaceSelected, lineWidth: 1)
              }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("period-\(period.rawValue)")
      }
    }
    .frame(height: ChartLayout.footerHeight)
    .padding(.horizontal, Theme.Spacing.xs)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text("chart.periodsLabel"))
    .sensoryFeedback(.selection, trigger: taps)
  }
}

/// 차트 하단 가운데 [↻] 되돌리기(restore 모양, 새로고침과 구분). 드래그·핀치로 바꾼 범위를 고른 기간의 최근 위치로
/// 되돌린다 (screens.md C-a 기간과 제스처, RN `charts/ChartResetButton.tsx`)
struct ChartResetButton: View {
  let action: () -> Void
  @State private var taps = 0

  private static let size: CGFloat = 40

  var body: some View {
    Button {
      taps += 1
      action()
    } label: {
      Image(systemName: "clock.arrow.circlepath")
        .foregroundStyle(Theme.Colors.text)
        .frame(width: Self.size, height: Self.size)
        .background(Theme.Colors.surface, in: .circle)
        .overlay(Circle().strokeBorder(Theme.Colors.separator, lineWidth: 1))
        .contentShape(.circle.inset(by: -Theme.Spacing.sm))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text("chart.resetView"))
    .accessibilityIdentifier("chartReset")
    .sensoryFeedback(.selection, trigger: taps)
  }
}

/// 차트 탭 첫 조회 중 화면. 공용 막대 대신 차트 격자와 아래 줄(기간 칩) 자리를 그려 차트가 들어설 모양을 맞추고,
/// 차트 자리 가운데에 스피너를 겹친다. 가로 모드는 아래 줄을 숨긴다 (D-103, RN `charts/ChartSkeleton.tsx`)
struct ChartSkeleton: View {
  @Environment(\.isLandscape) private var isLandscape

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 0) {
        ForEach(0..<5, id: \.self) { _ in
          Spacer(minLength: 0)
          Rectangle().fill(Theme.ChartColors.grid).frame(height: 1)
        }
        Spacer(minLength: 0)
      }
      .overlay { CenterSpinner() }
      if !isLandscape {
        HStack(spacing: Theme.Spacing.sm) {
          ForEach(0..<6, id: \.self) { _ in
            RoundedRectangle(cornerRadius: Theme.Spacing.xs)
              .fill(Theme.Colors.surface)
              .frame(width: 40, height: 24)
          }
        }
        .frame(maxWidth: .infinity, minHeight: ChartLayout.footerHeight)
      }
    }
    .background(Theme.Colors.background)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("common.loading"))
    .accessibilityAddTraits(.updatesFrequently)
  }
}

/// 탭 가운데 안내 문구(값 없음 등)
struct ChartTabMessage: View {
  let key: LocalizedStringKey

  var body: some View {
    Text(key)
      .font(.system(size: Theme.FontSize.body))
      .foregroundStyle(Theme.Colors.text)
      .multilineTextAlignment(.center)
      .padding(Theme.Spacing.lg)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
