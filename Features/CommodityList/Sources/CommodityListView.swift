import Core
import SwiftUI

/// A 원자재 목록. 4단계에서 구현한다
public struct CommodityListView: View {
  @State private var connection: ServerConnectionModel?

  /// `healthRepository`가 있으면 서버 연결 상태 줄을 보인다(dev 변형만, 2단계 확인용)
  public init(healthRepository: (any HealthRepository)? = nil) {
    _connection = State(initialValue: healthRepository.map(ServerConnectionModel.init))
  }

  public var body: some View {
    VStack(spacing: 12) {
      Text(verbatim: "futureETP")
      if let connection {
        // dev 진단 줄이라 i18n 리소스에 넣지 않는다. 4단계 A 화면 구현 때 지운다
        Text(verbatim: connection.state.label)
          .font(.footnote.monospaced())
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("serverConnection")
          .task { await connection.check() }
      }
    }
  }
}

/// 서버 `/v1/health` 연결 확인 (2단계 임시)
@Observable
final class ServerConnectionModel {
  enum State: Equatable {
    case checking
    case connected(commit: String?)
    case failed(String)

    var label: String {
      switch self {
      case .checking: "server: checking…"
      case .connected(let commit): "server: ok (\(commit ?? "no commit"))"
      case .failed(let reason): "server: failed (\(reason))"
      }
    }
  }

  private(set) var state: State = .checking
  private let repository: any HealthRepository

  init(repository: any HealthRepository) {
    self.repository = repository
  }

  func check() async {
    state = .checking
    do {
      state = .connected(commit: try await repository.fetch().commit)
    } catch {
      state = .failed(String(describing: error))
    }
  }
}
