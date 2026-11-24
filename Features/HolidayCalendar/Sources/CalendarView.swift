import Core
import SwiftUI

/// A-a 휴장 달력(A title-bar [📅], screens.md A-a, D-143, D-144). 이번 달~다다음 달을 세로로 놓고
/// CME·KRX·NYSE 예외 일정을 기기 로컬 날짜 칸에 시장별 색 점으로 함께 표시한다
public struct CalendarView: View {
  @State private var model: CalendarScreenModel
  @Environment(\.locale) private var locale

  public init(model: @autoclosure () -> CalendarScreenModel) {
    _model = State(wrappedValue: model())
  }

  public var body: some View {
    QueryStateView(model.query.state, retry: { Task { await model.query.refetch() } }) { data in
      content(model.schedule(data))
    }
    .queryLifecycle(model.query)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.Colors.background)
    .backTitleBar(Text("calendar.title"))
    .accessibilityIdentifier("calendar")
  }

  private func content(_ schedule: CalendarSchedule) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Legend(t: t)
        ForEach(schedule.missing, id: \.self) { missing in
          Text(verbatim: CalendarText.missing(missing, t: t))
            .font(.system(size: Theme.FontSize.caption))
            .foregroundStyle(Theme.Colors.error)
            .padding(.bottom, Theme.Spacing.xs)
        }
        ForEach(model.months, id: \.self) { month in
          MonthSection(month: month, schedule: schedule, today: model.today, t: t)
        }
      }
      .padding(.horizontal, Theme.Spacing.lg)
      .padding(.bottom, Theme.Spacing.xl)
    }
  }

  private func t(_ key: String, _ values: [String: String]) -> String {
    L10n.string(key, values, locale: locale)
  }
}

private enum Metrics {
  static let dot: CGFloat = 6
  static let daySize: CGFloat = 30
  static let cellHeight: CGFloat = 48
  /// 영어 `11/26 (Thu)`가 한 줄에 들어가는 폭(RN은 64라 영어에서 줄이 꺾인다)
  static let lineDateWidth: CGFloat = 76
  static let marketTagWidth: CGFloat = 40
}

/// 시장 색, 채운 점(휴장), 빈 점(조기 마감·개장 지연), 오늘 테두리
private struct Legend: View {
  let t: CalendarText.Translate

  var body: some View {
    FlowLayout(spacing: Theme.Spacing.md, lineSpacing: Theme.Spacing.xs) {
      ForEach(CalendarMarket.allCases, id: \.self) { market in
        item(
          Dot(color: Theme.Colors.market(market), filled: true), CalendarText.market(market, t: t))
      }
      item(Dot(color: Theme.Colors.textSecondary, filled: true), t("calendar.legendClosed", [:]))
      item(
        Dot(color: Theme.Colors.textSecondary, filled: false), t("calendar.legendShortened", [:]))
      item(
        Circle().stroke(Theme.Colors.today, lineWidth: 1).frame(width: 12, height: 12),
        t("calendar.legendToday", [:]))
    }
    .padding(.vertical, Theme.Spacing.md)
  }

  private func item(_ mark: some View, _ label: String) -> some View {
    HStack(spacing: Theme.Spacing.xs) {
      mark
      Text(verbatim: label)
        .font(.system(size: Theme.FontSize.caption))
        .foregroundStyle(Theme.Colors.textSecondary)
    }
  }
}

private struct Dot: View {
  let color: Color
  let filled: Bool

  var body: some View {
    Group {
      if filled {
        Circle().fill(color)
      } else {
        Circle().strokeBorder(color, lineWidth: 1)
      }
    }
    .frame(width: Metrics.dot, height: Metrics.dot)
  }
}

private struct MonthSection: View {
  let month: CalendarMonth
  let schedule: CalendarSchedule
  let today: LocalDate
  let t: CalendarText.Translate

  var body: some View {
    let cells = MonthGrid.cells(month)
    let items = schedule.items(in: month)
    VStack(alignment: .leading, spacing: 0) {
      Text(verbatim: CalendarText.monthTitle(month, t: t))
        .font(.system(size: Theme.FontSize.title, weight: .semibold))
        .foregroundStyle(Theme.Colors.text)
        .padding(.bottom, Theme.Spacing.sm)
        .accessibilityAddTraits(.isHeader)
      HStack(spacing: 0) {
        ForEach(0..<7, id: \.self) { weekday in
          Text(verbatim: CalendarText.weekday(weekday, t: t))
            .font(.system(size: Theme.FontSize.caption))
            .foregroundStyle(
              MonthGrid.isWeekend(weekday) ? Theme.Colors.textSecondary : Theme.Colors.text
            )
            .frame(maxWidth: .infinity)
        }
      }
      .padding(.bottom, Theme.Spacing.xs)
      ForEach(0..<(cells.count / 7), id: \.self) { week in
        HStack(spacing: 0) {
          ForEach(week * 7..<week * 7 + 7, id: \.self) { index in
            if let date = cells[index] {
              DayCell(
                date: date, exceptions: schedule.byDate[date] ?? [], isToday: date == today, t: t)
            } else {
              Color.clear.frame(maxWidth: .infinity, minHeight: Metrics.cellHeight)
            }
          }
        }
      }
      VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
        if items.isEmpty {
          Text("calendar.none")
            .font(.system(size: Theme.FontSize.caption))
            .foregroundStyle(Theme.Colors.textSecondary)
        } else {
          ForEach(items) { ExceptionLine(exception: $0, t: t) }
        }
      }
      .padding(.top, Theme.Spacing.sm)
    }
    .padding(.top, Theme.Spacing.lg)
    .overlay(alignment: .top) {
      Rectangle().fill(Theme.Colors.separator).frame(height: 1)
    }
    .padding(.top, Theme.Spacing.sm)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("calendar-month-\(month.year)-\(month.month)")
  }
}

private struct DayCell: View {
  let date: LocalDate
  let exceptions: [LocalCalendarException]
  let isToday: Bool
  let t: CalendarText.Translate

  var body: some View {
    VStack(spacing: 2) {
      Text(verbatim: String(date.day))
        .font(.system(size: Theme.FontSize.body).monospacedDigit())
        .foregroundStyle(
          MonthGrid.isWeekend(MonthGrid.weekday(date))
            ? Theme.Colors.textSecondary : Theme.Colors.text
        )
        .frame(width: Metrics.daySize, height: Metrics.daySize)
        .overlay {
          if isToday { Circle().strokeBorder(Theme.Colors.today, lineWidth: 1.5) }
        }
      // 아래 목록과 같은 순서(로컬 시각순)
      HStack(spacing: 2) {
        ForEach(exceptions) { exception in
          Dot(color: Theme.Colors.market(exception.market), filled: exception.isClosed)
        }
      }
      .frame(height: Metrics.dot + 2)
    }
    .padding(.vertical, Theme.Spacing.xs)
    .frame(maxWidth: .infinity, minHeight: Metrics.cellHeight, alignment: .top)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      Text(verbatim: CalendarText.cellLabel(date, isToday: isToday, exceptions: exceptions, t: t))
    )
    .accessibilityIdentifier("calendar-day-\(date)")
  }
}

/// `MM/DD (요일) [시장] 종류 · 휴일 이름`
private struct ExceptionLine: View {
  let exception: LocalCalendarException
  let t: CalendarText.Translate

  var body: some View {
    let color = Theme.Colors.market(exception.market)
    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
      Text(verbatim: CalendarText.listDate(exception.localDate, t: t))
        .font(.system(size: Theme.FontSize.caption).monospacedDigit())
        .foregroundStyle(Theme.Colors.text)
        .lineLimit(1)
        .frame(width: Metrics.lineDateWidth, alignment: .leading)
      Text(verbatim: CalendarText.market(exception.market, t: t))
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(color)
        .frame(width: Metrics.marketTagWidth)
        .overlay {
          RoundedRectangle(cornerRadius: Theme.Radius.sm).strokeBorder(color, lineWidth: 1)
        }
      Text(description)
        .font(.system(size: Theme.FontSize.caption))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .combine)
  }

  /// 종류는 본문 색, 휴일 이름(입력 원문)은 흐리게
  private var description: AttributedString {
    var kind = AttributedString(CalendarText.kind(exception, t: t))
    kind.foregroundColor = Theme.Colors.text
    var note = AttributedString(" · \(exception.exception.note)")
    note.foregroundColor = Theme.Colors.textSecondary
    return kind + note
  }
}

/// 폭이 넘치면 다음 줄로 넘기는 가로 배치(범례)
private struct FlowLayout: Layout {
  let spacing: CGFloat
  let lineSpacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let frames = layout(subviews, width: proposal.width ?? .infinity)
    let width = frames.map(\.maxX).max() ?? 0
    let height = frames.map(\.maxY).max() ?? 0
    return CGSize(width: proposal.width ?? width, height: height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    for (subview, frame) in zip(subviews, layout(subviews, width: bounds.width)) {
      subview.place(
        at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
        proposal: ProposedViewSize(frame.size))
    }
  }

  private func layout(_ subviews: Subviews, width: CGFloat) -> [CGRect] {
    var frames: [CGRect] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var lineHeight: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x > 0, x + size.width > width {
        x = 0
        y += lineHeight + lineSpacing
        lineHeight = 0
      }
      frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
      x += size.width + spacing
      lineHeight = max(lineHeight, size.height)
    }
    return frames
  }
}
