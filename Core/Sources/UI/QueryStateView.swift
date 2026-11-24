import SwiftUI

/// 조회 화면 상태 분기 (architecture.md 화면 표시, RN `components/QueryStateView.tsx`).
/// 데이터가 있으면 내용, 처음 로딩 실패만 오류 화면, 그 밖에는 스켈레톤이다
public struct QueryStateView<Value: Sendable, Skeleton: View, Content: View>: View {
  private let state: QueryState<Value>
  private let retry: () -> Void
  private let skeleton: Skeleton
  private let content: (Value) -> Content

  /// - Parameter skeleton: 화면 모양에 맞춘 스켈레톤
  public init(
    _ state: QueryState<Value>, retry: @escaping () -> Void,
    @ViewBuilder skeleton: () -> Skeleton, @ViewBuilder content: @escaping (Value) -> Content
  ) {
    self.state = state
    self.retry = retry
    self.skeleton = skeleton()
    self.content = content
  }

  public var body: some View {
    switch state.phase {
    case .content(let data): content(data)
    case .failed(let error): ErrorView(error, retry: retry)
    case .loading: skeleton
    }
  }
}

extension QueryStateView where Skeleton == LoadingView {
  /// 공용 막대 스켈레톤을 쓴다
  public init(
    _ state: QueryState<Value>, retry: @escaping () -> Void,
    @ViewBuilder content: @escaping (Value) -> Content
  ) {
    self.init(state, retry: retry, skeleton: { LoadingView() }, content: content)
  }
}

/// 공용 막대 스켈레톤 + 가운데 큰 스피너 (screens.md 공통 로딩)
public struct LoadingView: View {
  public init() {}

  public var body: some View {
    VStack(spacing: Theme.Spacing.md) {
      ForEach([0.9, 0.6, 0.75], id: \.self) { fraction in
        GeometryReader { geometry in
          RoundedRectangle(cornerRadius: Theme.Radius.sm)
            .fill(Theme.Colors.surface)
            .frame(width: geometry.size.width * fraction)
        }
        .frame(height: Theme.Spacing.xl)
      }
    }
    .padding(Theme.Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .overlay { CenterSpinner() }
    .background(Theme.Colors.background)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("common.loading"))
    .accessibilityAddTraits(.updatesFrequently)
  }
}

/// 첫 조회 중 스켈레톤 위 가운데에 겹치는 스피너. 응답이 늦어도 불러오는 중임이 보이게 한다.
/// 접근성 라벨은 감싸는 스켈레톤이 갖고, 터치는 막지 않는다
public struct CenterSpinner: View {
  public init() {}

  public var body: some View {
    ProgressView()
      .controlSize(.large)
      .tint(Theme.Colors.textSecondary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .allowsHitTesting(false)
      .accessibilityHidden(true)
  }
}

/// 안내 문구 + [다시 시도]. 문구는 에러 code로 고른다 (D-042)
public struct ErrorView: View {
  private let error: any Error
  private let retry: () -> Void

  public init(_ error: any Error, retry: @escaping () -> Void) {
    self.error = error
    self.retry = retry
  }

  public var body: some View {
    VStack(spacing: Theme.Spacing.md) {
      Text(LocalizedStringKey(AppError.textKey(for: error)))
        .font(.system(size: Theme.FontSize.body))
        .foregroundStyle(Theme.Colors.text)
        .multilineTextAlignment(.center)
      Button(action: retry) {
        Text("common.retry")
          .font(.system(size: Theme.FontSize.body))
          .foregroundStyle(Theme.Colors.text)
          .frame(minHeight: Theme.Size.touchTarget)
          .padding(.horizontal, Theme.Spacing.xl)
          .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Radius.sm))
      }
      .buttonStyle(.plain)
    }
    .padding(Theme.Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.Colors.background)
  }
}
