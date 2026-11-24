import SwiftUI

/// 설정·필터 행: 이름 + `[a|b|c]` 중 하나 고르기 (RN `components/SegmentedControl.tsx`).
/// 고른 값을 다시 누르면 아무것도 하지 않는다
public struct SegmentedRow<Value: Hashable>: View {
  public struct Option {
    public let value: Value
    public let label: String

    public init(_ value: Value, _ label: String) {
      self.value = value
      self.label = label
    }
  }

  private let label: String
  private let options: [Option]
  private let value: Value?
  private let stacked: Bool
  private let description: String?
  private let onChange: (Value) -> Void
  @State private var taps = 0

  /// - Parameters:
  ///   - value: 아직 값을 모르면(설정 조회 중) nil로 아무것도 고르지 않는다
  ///   - stacked: 선택지가 많으면 이름을 위에 두고 선택지가 전체 폭을 나눠 쓴다
  ///   - description: 행 아래 한 줄 설명
  public init(
    _ label: String, options: [Option], value: Value?, stacked: Bool = false,
    description: String? = nil, onChange: @escaping (Value) -> Void
  ) {
    self.label = label
    self.options = options
    self.value = value
    self.stacked = stacked
    self.description = description
    self.onChange = onChange
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if stacked {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
          title
          group
        }
        .modifier(RowPadding())
      } else {
        HStack(spacing: Theme.Spacing.sm) {
          title.frame(maxWidth: .infinity, alignment: .leading)
          group
        }
        .modifier(RowPadding())
      }
      if let description {
        Text(verbatim: description)
          .font(.system(size: Theme.FontSize.caption))
          .foregroundStyle(Theme.Colors.textSecondary)
          .padding(.horizontal, Theme.Spacing.lg)
          .padding(.top, -Theme.Spacing.xs)
      }
    }
    .padding(.bottom, Theme.Spacing.xs)
    .sensoryFeedback(.selection, trigger: taps)
  }

  private var title: some View {
    Text(verbatim: label)
      .font(.system(size: Theme.FontSize.body))
      .foregroundStyle(Theme.Colors.text)
  }

  private var group: some View {
    HStack(spacing: 0) {
      ForEach(options.indices, id: \.self) { index in
        let option = options[index]
        let selected = option.value == value
        Button {
          guard !selected else { return }
          taps += 1
          onChange(option.value)
        } label: {
          Text(verbatim: option.label)
            .font(.system(size: Theme.FontSize.body))
            .foregroundStyle(Theme.Colors.text)
            .multilineTextAlignment(.center)
            // 한 줄로 둔 선택지는 줄바꿈하지 않고 이름 쪽이 줄어든다
            .lineLimit(stacked ? nil : 1)
            .fixedSize(horizontal: !stacked, vertical: false)
            .padding(.horizontal, stacked ? Theme.Spacing.xs : Theme.Spacing.md)
            .frame(minWidth: Theme.Size.touchTarget, maxWidth: stacked ? .infinity : nil)
            .frame(minHeight: 36)
            .background(selected ? Theme.Colors.surfaceSelected : .clear)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
      }
    }
    .background(Theme.Colors.surface)
    .clipShape(.rect(cornerRadius: Theme.Spacing.sm))
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(verbatim: label))
  }
}

private struct RowPadding: ViewModifier {
  func body(content: Content) -> some View {
    content
      .frame(minHeight: Theme.Size.touchTarget)
      .padding(.horizontal, Theme.Spacing.lg)
      .padding(.vertical, Theme.Spacing.sm)
  }
}
