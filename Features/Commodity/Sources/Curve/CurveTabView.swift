import Core
import SwiftUI

/// C-b 월물커브 탭(screens.md C-b, D-090). 조회 상태(첫 로딩은 차트 모양 스켈레톤, 오류는 재시도)와 커브
/// (RN `CurveScreen`)
struct CurveTabView: View {
  @State private var model: CurveScreenModel

  init(code: CommodityCode, queries: CommodityQueries) {
    _model = State(initialValue: CurveScreenModel(code: code, queries: queries))
  }

  var body: some View {
    QueryStateView(
      model.state, retry: { Task { await model.query.refetch() } },
      skeleton: { ChartSkeleton() }
    ) { curve in
      CurveContentView(model: model, curve: curve)
    }
    // 기준일마다 조회가 달라 그 조회를 관찰한다(떠난 기준일 조회는 놓는다)
    .background {
      Color.clear.queryLifecycle(model.query).id(model.baseDate)
    }
    .tabFooterTime(model.state.data.map { .market($0.freshness) })
  }
}

/// 커브(범례·롤 수익률 줄, 되돌리기)와 기준일 버튼 줄. 가로 모드는 버튼 줄을 숨긴다 (D-103)
private struct CurveContentView: View {
  let model: CurveScreenModel
  let curve: Curve
  @Environment(DisplaySettings.self) private var display
  @Environment(\.isLandscape) private var isLandscape
  @Environment(\.locale) private var locale

  var body: some View {
    VStack(spacing: 0) {
      Group {
        if curve.points.isEmpty {
          ChartTabMessage(key: "curve.noData")
        } else {
          CurveChart(
            points: curve.points.map(CurveChartLayout.Point.init),
            priceDecimals: curve.priceDecimals,
            palette: display.palette,
            detailRows: { CurveDetail.rows(curve, index: $0, t: translate) },
            // 기준일을 과거로 옮겼을 때만 C-a·C-c 같은 되돌리기 버튼 (D-115)
            onReset: curve.baseDate == curve.maxBaseDate ? nil : { model.changeBaseDate(nil) },
            resetLabel: "curve.reset",
            overlayTop: { CurveLegend(curve: curve, translate: translate) },
            floating: { MovedNotice(curve: curve, movedTo: model.movedTo) })
        }
      }
      .padding(.horizontal, Theme.Spacing.sm)
      if !isLandscape {
        CurveStepBar(curve: curve, model: model)
      }
    }
    .background(Theme.Colors.background)
    // 휴장일 안내는 3초 뒤 지운다
    .task(id: model.movedTo) {
      guard model.movedTo != nil else { return }
      try? await Task.sleep(for: CurveScreenModel.movedNoticeDuration)
      guard !Task.isCancelled else { return }
      model.clearMoved()
    }
  }

  private func translate(_ key: String, _ values: [String: String]) -> String {
    L10n.string(key, values, locale: locale)
  }
}

/// 범례(기준일 실선, 비교일 점선)와 롤 수익률을 한 줄에 둔다. 넘치면 줄바꿈
private struct CurveLegend: View {
  let curve: Curve
  let translate: DisparityInfo.Translate

  var body: some View {
    let current = curve.freshness.tradeDate
    CenteredFlowLayout(spacing: Theme.Spacing.lg) {
      HStack(spacing: Theme.Spacing.lg) {
        item(
          CurveFormat.legendDate(curve.baseDate, current: current),
          color: Theme.ChartColors.curveBase, dash: [])
        item(
          CurveFormat.legendDate(curve.compareDate, current: current),
          color: Theme.ChartColors.curveCurrent,
          dash: CurveChartLayout.curveDash.map { CGFloat($0) })
      }
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("curveLegend")
      Text(verbatim: CurveFormat.rollLine(curve, t: translate))
        .lineLimit(1)
        .accessibilityIdentifier("curveRollYield")
    }
    .font(.system(size: Theme.FontSize.caption).monospacedDigit())
    .foregroundStyle(Theme.Colors.text)
    .padding(.horizontal, Theme.Spacing.lg)
  }

  private func item(_ label: String, color: Color, dash: [CGFloat]) -> some View {
    HStack(spacing: Theme.Spacing.xs) {
      LegendLine(color: color, dash: dash, lineWidth: CurveChartLayout.seriesStroke)
      Text(verbatim: label)
    }
  }
}

/// `[<] 2026/11/20 [>]`: 기준일을 1 거래일씩 옮기고, 가운데를 누르면 기준일 선택 시트.
/// C-a·C-c 기간 칩 줄과 같은 높이다(차트·되돌리기 버튼 위치를 세 탭이 맞춘다, D-117)
private struct CurveStepBar: View {
  let curve: Curve
  let model: CurveScreenModel
  @State private var sheetOpen = false

  var body: some View {
    HStack(spacing: Theme.Spacing.sm) {
      StepButton(
        systemImage: "chevron.left", label: "curve.prev", id: "curvePrev",
        action: curve.prevBaseDate.map { date in { model.changeBaseDate(date) } })
      Button {
        sheetOpen = true
      } label: {
        Text(verbatim: CurveFormat.fullDate(curve.baseDate))
          .font(.system(size: Theme.FontSize.body).monospacedDigit())
          .foregroundStyle(Theme.Colors.text)
          .padding(.horizontal, Theme.Spacing.sm)
          .frame(minWidth: Theme.Size.touchTarget, minHeight: Theme.Size.touchTarget)
          .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Spacing.sm))
      }
      .buttonStyle(.plain)
      .accessibilityHint(Text("curve.pickTitle"))
      .accessibilityIdentifier("curveBaseDate")
      StepButton(
        systemImage: "chevron.right", label: "curve.next", id: "curveNext",
        action: CurveScreenModel.next(of: curve).map { date in { model.changeBaseDate(date) } })
    }
    .frame(maxWidth: .infinity)
    .frame(height: ChartLayout.footerHeight)
    .padding(.horizontal, Theme.Spacing.lg)
    .sheet(isPresented: $sheetOpen) {
      BaseDateSheet(curve: curve) { date in
        sheetOpen = false
        model.pickBaseDate(date, maxBaseDate: curve.maxBaseDate)
      }
    }
  }
}

/// 휴장일을 골라 서버가 옮긴 기준일 안내(`휴장일이라 10/16(금)로 옮겼습니다`). x축 라벨 바로 위에 띄운다
private struct MovedNotice: View {
  let curve: Curve
  let movedTo: LocalDate?
  @Environment(\.locale) private var locale

  var body: some View {
    if let movedTo {
      Text(
        verbatim: L10n.string(
          "curve.moved",
          [
            "date": CurveFormat.legendDate(movedTo, current: curve.freshness.tradeDate),
            "weekday": CurveFormat.weekday(movedTo, locale: locale),
          ], locale: locale)
      )
      .font(.system(size: Theme.FontSize.caption))
      .foregroundStyle(Theme.Colors.text)
      .padding(.horizontal, Theme.Spacing.md)
      .padding(.vertical, Theme.Spacing.xs)
      .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Spacing.xs))
      .allowsHitTesting(false)
      .accessibilityIdentifier("curveMoved")
    }
  }
}

/// 이전·다음 버튼. `action`이 nil이면 범위 끝이라 비활성
private struct StepButton: View {
  let systemImage: String
  let label: LocalizedStringKey
  let id: String
  let action: (() -> Void)?

  var body: some View {
    Button {
      action?()
    } label: {
      Image(systemName: systemImage)
        .foregroundStyle(action == nil ? Theme.Colors.textSecondary : Theme.Colors.text)
        .frame(width: Theme.Size.touchTarget, height: Theme.Size.touchTarget)
        .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Spacing.sm))
        .opacity(action == nil ? 0.4 : 1)
    }
    .buttonStyle(.plain)
    .disabled(action == nil)
    .accessibilityLabel(Text(label))
    .accessibilityIdentifier(id)
  }
}
