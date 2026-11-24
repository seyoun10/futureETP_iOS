import Core
import SwiftUI

/// B와 하위 화면의 묶음 제목. 화면 폭 전체의 `surface` 띠에 가운데 정렬한 굵은 본문 글자 (RN `SectionHeader`)
struct SectionHeader: View {
  let title: String

  var body: some View {
    Text(verbatim: title)
      .font(.system(size: Theme.FontSize.body, weight: .semibold))
      .foregroundStyle(Theme.Colors.text)
      .multilineTextAlignment(.center)
      .padding(.horizontal, Theme.Spacing.lg)
      .padding(.vertical, Theme.Spacing.sm)
      .frame(maxWidth: .infinity)
      .background(Theme.Colors.surface)
      .accessibilityAddTraits(.isHeader)
  }
}

/// 이름 + 값 + › 행. 설명은 이름·값 아래 한 줄이다. 누르면 선택 햅틱을 준다(하위 설정 진입, D-109)
struct LinkRow: View {
  let label: String
  var value: String?
  var description: String?
  var identifier: String?
  let action: () -> Void
  @State private var taps = 0

  var body: some View {
    Button {
      taps += 1
      action()
    } label: {
      HStack(spacing: Theme.Spacing.sm) {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
          HStack(spacing: Theme.Spacing.sm) {
            Text(verbatim: label)
              .foregroundStyle(Theme.Colors.text)
              .frame(maxWidth: .infinity, alignment: .leading)
            if let value {
              Text(verbatim: value)
                .foregroundStyle(Theme.Colors.textSecondary)
            }
          }
          .font(.system(size: Theme.FontSize.body))
          if let description {
            Text(verbatim: description)
              .font(.system(size: Theme.FontSize.caption))
              .foregroundStyle(Theme.Colors.textSecondary)
              .multilineTextAlignment(.leading)
          }
        }
        Image(systemName: "chevron.right")
          .foregroundStyle(Theme.Colors.textSecondary)
      }
      .frame(minHeight: Theme.Size.touchTarget)
      .padding(.horizontal, Theme.Spacing.lg)
      .padding(.vertical, Theme.Spacing.md)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .overlay(alignment: .bottom) {
      Rectangle().fill(Theme.Colors.separator).frame(height: 1)
    }
    .sensoryFeedback(.selection, trigger: taps)
    .accessibilityIdentifier(identifier ?? "")
  }
}

/// B·B-a 저장 실패 줄. 가운데 정렬한 빨간 캡션 (screens.md 공통 오류 줄)
struct SaveErrorLine: View {
  let error: any Error
  @Environment(\.locale) private var locale

  var body: some View {
    let reason = L10n.string(AppError.textKey(for: error), locale: locale)
    Text(verbatim: L10n.string("settings.saveFailed", ["reason": reason], locale: locale))
      .font(.system(size: Theme.FontSize.caption))
      .foregroundStyle(Theme.Colors.error)
      .multilineTextAlignment(.center)
      .padding(.horizontal, Theme.Spacing.lg)
      .padding(.vertical, Theme.Spacing.sm)
      .frame(maxWidth: .infinity)
      .background(Theme.Colors.surface)
      .accessibilityIdentifier("saveFailed")
  }
}
