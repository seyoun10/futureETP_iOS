import Core
import SwiftUI

/// 알림 거부 시간 (screens.md B-a, D-007, D-026). 끄면 nil로 저장한다. 시작·종료는 30분 단위이고 서로 달라야 해
/// 시각 선택 시트에서 반대쪽 시각은 고를 수 없다. 자정을 넘기면 종료 시각에 `다음 날`을 붙인다
struct QuietTimeSection: View {
  let value: QuietTime?
  let onChange: (QuietTime?) -> Void
  @State private var editing: QuietTimeSlots.Edge?
  @Environment(\.locale) private var locale

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Toggle(
        isOn: Binding(
          get: { value != nil },
          set: { onChange($0 ? QuietTimeSlots.defaultValue : nil) })
      ) {
        Text("alertSettings.quietTime")
          .font(.system(size: Theme.FontSize.body))
          .foregroundStyle(Theme.Colors.text)
      }
      .tint(Theme.Colors.surfaceSelected)
      .frame(minHeight: Theme.Size.touchTarget)
      .padding(.horizontal, Theme.Spacing.lg)
      .padding(.top, Theme.Spacing.lg)
      .accessibilityIdentifier("quietTimeToggle")
      if let value {
        HStack(spacing: Theme.Spacing.sm) {
          timeButton(
            .start, label: t("alertSettings.quietStart"), time: QuietTimeSlots.text(value.startMin))
          Text(verbatim: "~")
            .font(.system(size: Theme.FontSize.body))
            .foregroundStyle(Theme.Colors.textSecondary)
          timeButton(
            .end, label: t("alertSettings.quietEnd"),
            time: QuietTimeSlots.endsNextDay(value)
              ? t("alertSettings.quietNextDay", ["time": QuietTimeSlots.text(value.endMin)])
              : QuietTimeSlots.text(value.endMin))
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.xs)
      }
      Text("alertSettings.quietNote")
        .font(.system(size: Theme.FontSize.caption))
        .foregroundStyle(Theme.Colors.textSecondary)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.xs)
    }
    .sheet(item: $editing) { edge in
      if let value {
        TimeSlotSheet(
          title: t(edge == .start ? "alertSettings.quietStart" : "alertSettings.quietEnd"),
          selected: QuietTimeSlots.minute(value, edge),
          blocked: QuietTimeSlots.minute(value, edge == .start ? .end : .start)
        ) { minute in
          editing = nil
          if let next = QuietTimeSlots.picking(minute, for: edge, in: value) { onChange(next) }
        }
      }
    }
  }

  private func timeButton(_ edge: QuietTimeSlots.Edge, label: String, time: String) -> some View {
    Button {
      editing = edge
    } label: {
      Text(verbatim: time)
        .font(.system(size: Theme.FontSize.body).monospacedDigit())
        .foregroundStyle(Theme.Colors.text)
        .padding(.horizontal, Theme.Spacing.md)
        .frame(minHeight: Theme.Size.touchTarget)
        .background(Theme.Colors.surface)
        .clipShape(.rect(cornerRadius: Theme.Spacing.sm))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(verbatim: "\(label) \(time)"))
    .accessibilityIdentifier(edge == .start ? "quietStart" : "quietEnd")
  }

  private func t(_ key: String, _ values: [String: String] = [:]) -> String {
    L10n.string(key, values, locale: locale)
  }
}

/// 30분 단위 48칸 중 하나를 누르면 바로 고르고 닫는다. `blocked`는 반대쪽 시각(시작≠종료)이다.
/// 시트를 끌어 내리거나 바깥을 누르면 고르지 않고 닫는다
private struct TimeSlotSheet: View {
  let title: String
  let selected: Int
  let blocked: Int
  let onPick: (Int) -> Void

  private let columns = Array(
    repeating: GridItem(.flexible(), spacing: Theme.Spacing.sm), count: 4)

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
      Text(verbatim: title)
        .font(.system(size: Theme.FontSize.title))
        .foregroundStyle(Theme.Colors.text)
        .accessibilityAddTraits(.isHeader)
      ScrollViewReader { proxy in
        ScrollView {
          LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
            ForEach(QuietTimeSlots.minutes, id: \.self) { minute in
              let isSelected = minute == selected
              Button {
                onPick(minute)
              } label: {
                Text(verbatim: QuietTimeSlots.text(minute))
                  .font(.system(size: Theme.FontSize.body).monospacedDigit())
                  .foregroundStyle(Theme.Colors.text)
                  .frame(maxWidth: .infinity, minHeight: Theme.Size.touchTarget)
                  .background(isSelected ? Theme.Colors.surfaceSelected : Theme.Colors.background)
                  .clipShape(.rect(cornerRadius: Theme.Spacing.sm))
                  .opacity(minute == blocked ? 0.3 : 1)
              }
              .buttonStyle(.plain)
              .disabled(minute == blocked)
              .accessibilityAddTraits(isSelected ? [.isSelected] : [])
              .accessibilityIdentifier("slot\(minute)")
              .id(minute)
            }
          }
        }
        // 고른 시각(예: 23:00)이 아래쪽 칸이라도 보이게 연다
        .onAppear { proxy.scrollTo(selected, anchor: .center) }
      }
    }
    .padding(Theme.Spacing.lg)
    .presentationDetents([.fraction(0.6)])
    .presentationBackground(Theme.Colors.surface)
    .presentationCornerRadius(Theme.Spacing.md)
  }
}
