import Core
import SwiftUI

/// 기준일 선택 시트(screens.md C-b 기준일 선택 시트, RN `curve/BaseDatePicker.tsx` `BaseDateSheet`).
/// 바텀 시트 안 OS 휠 피커이고, 확인을 눌러야 바뀐다. 범위 밖 날짜는 피커가 막고, 휴장일은 서버가 옮긴다 (D-090)
struct BaseDateSheet: View {
  let curve: Curve
  let onConfirm: (LocalDate) -> Void
  @State private var date: Date
  @Environment(\.dismiss) private var dismiss
  @Environment(\.locale) private var locale

  init(curve: Curve, onConfirm: @escaping (LocalDate) -> Void) {
    self.curve = curve
    self.onConfirm = onConfirm
    _date = State(initialValue: Self.pickerDate(curve.baseDate))
  }

  var body: some View {
    VStack(spacing: Theme.Spacing.sm) {
      Text("curve.pickTitle")
        .font(.system(size: Theme.FontSize.title))
        .foregroundStyle(Theme.Colors.text)
      DatePicker(
        selection: $date,
        in: Self.pickerDate(curve.minBaseDate)...Self.pickerDate(curve.maxBaseDate),
        displayedComponents: .date
      ) {
        Text("curve.pickTitle")
      }
      .datePickerStyle(.wheel)
      .labelsHidden()
      .environment(\.locale, locale)
      .accessibilityIdentifier("baseDatePicker")
      Text(
        verbatim: L10n.string(
          "curve.pickRange",
          [
            "min": CurveFormat.fullDate(curve.minBaseDate),
            "max": CurveFormat.fullDate(curve.maxBaseDate),
          ], locale: locale)
      )
      .font(.system(size: Theme.FontSize.caption).monospacedDigit())
      .foregroundStyle(Theme.Colors.textSecondary)
      HStack {
        sheetButton("common.cancel", id: "baseDateCancel") { dismiss() }
        Spacer()
        sheetButton("common.confirm", id: "baseDateConfirm") {
          onConfirm(Self.localDate(date))
        }
      }
      .padding(.horizontal, Theme.Spacing.xl)
    }
    .padding(Theme.Spacing.lg)
    .presentationDetents([.height(360)])
    .presentationBackground(Theme.Colors.surface)
    .presentationCornerRadius(Theme.Spacing.md)
  }

  private func sheetButton(
    _ key: LocalizedStringKey, id: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Text(key)
        .font(.system(size: Theme.FontSize.body))
        .foregroundStyle(Theme.Colors.text)
        .frame(minWidth: 96, minHeight: Theme.Size.touchTarget)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(id)
  }

  /// OS 날짜 피커는 기기 시간대 `Date`를 쓴다. 날짜만 오가므로 기기 시간대 자정으로 바꾼다
  static func pickerDate(_ date: LocalDate, calendar: Calendar = .current) -> Date {
    calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day))!
  }

  static func localDate(_ date: Date, calendar: Calendar = .current) -> LocalDate {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return LocalDate(year: parts.year!, month: parts.month!, day: parts.day!)!
  }
}
