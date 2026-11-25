import Core
import SwiftUI
import UIKit

/// rare-level 5칸 (screens.md B). 숫자 키패드는 키패드 위 [완료]로만 닫고, 닫힐 때 검증·저장한다 (D-083).
/// 키패드가 열린 채 다른 칸을 눌러도 저장하지 않는다
struct RareLevelsInput: View {
  /// 조회 중이면 nil(입력 막음)
  let levels: [Double]?
  /// 칸 줄 아래 끝(전역 좌표). 키패드에 가리는지 볼 때 쓴다
  let onFieldsBottom: (CGFloat) -> Void
  let onSave: (RareLevels) -> Void
  @State private var draft = RareLevelsDraft()
  @FocusState private var focused: Int?
  @Environment(\.locale) private var locale

  var body: some View {
    let texts = draft.texts(levels: levels)
    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
      HStack(spacing: Theme.Spacing.xs) {
        Text("settings.rareLevels")
          .font(.system(size: Theme.FontSize.body))
          .foregroundStyle(Theme.Colors.text)
          .frame(maxWidth: .infinity, alignment: .leading)
        ForEach(0..<RareLevels.count, id: \.self) { index in
          TextField(
            "",
            text: Binding(
              get: { texts[index] },
              set: { draft.change(index, to: $0, levels: levels) })
          )
          .keyboardType(.decimalPad)
          .focused($focused, equals: index)
          .multilineTextAlignment(.center)
          .font(.system(size: Theme.FontSize.body))
          .foregroundStyle(Theme.Colors.text)
          .padding(.horizontal, Theme.Spacing.xs)
          .frame(width: 48, height: 36)
          .background(Theme.Colors.surface)
          .clipShape(.rect(cornerRadius: Theme.Spacing.sm))
          .disabled(levels == nil)
          .accessibilityLabel(
            Text(verbatim: t("settings.rareLevelField", ["index": "\(index + 1)"]))
          )
          .accessibilityIdentifier("rareLevel\(index)")
        }
      }
      .onGeometryChange(for: CGFloat.self) {
        $0.frame(in: .global).maxY
      } action: {
        onFieldsBottom($0)
      }
      Text(verbatim: hint)
        .font(.system(size: Theme.FontSize.caption))
        .foregroundStyle(draft.problem == nil ? Theme.Colors.textSecondary : Theme.Colors.error)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .multilineTextAlignment(.trailing)
      Text("settings.rareLevelsDesc")
        .font(.system(size: Theme.FontSize.caption))
        .foregroundStyle(Theme.Colors.textSecondary)
    }
    .padding(.horizontal, Theme.Spacing.lg)
    .padding(.vertical, Theme.Spacing.sm)
    // 칸을 누르면 글자를 모두 골라 바로 덮어 쓰게 한다(RN `selectTextOnFocus`)
    .onReceive(
      NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)
    ) { notification in
      guard let field = notification.object as? UITextField else { return }
      DispatchQueue.main.async { field.selectAll(nil) }
    }
    .onChange(of: focused) { _, now in
      guard now == nil, let levels = draft.commit(levels: levels) else { return }
      onSave(levels)
    }
    .toolbar {
      // 숫자 키패드에는 닫는 키가 없어 키패드 위에 [완료]를 둔다
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("common.done") { focused = nil }
          .foregroundStyle(Theme.Colors.text)
        Spacer()
      }
    }
  }

  private var hint: String {
    let range = [
      "min": RareLevels.text(RareLevels.range.lowerBound),
      "max": RareLevels.text(RareLevels.range.upperBound),
      "count": "\(RareLevels.count)",
    ]
    return switch draft.problem {
    case .invalid: t("settings.rareLevelInvalid", range)
    case .duplicate: t("settings.rareLevelDuplicate", range)
    case nil: t("settings.rareLevelHint", range)
    }
  }

  private func t(_ key: String, _ values: [String: String] = [:]) -> String {
    L10n.string(key, values, locale: locale)
  }
}
