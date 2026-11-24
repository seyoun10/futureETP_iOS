import CommodityList
import Core
import Settings
import SwiftUI

/// 스택에 올리는 화면
enum Route: Hashable {
  case accessKey
}

/// 접근 키가 없으면 A 대신 B-b만 띄운다. 저장하면 스택으로 바뀐다 (screens.md B-b, D-044).
/// 저장된 키를 서버가 거절하면 어느 화면에서든 B-b로 보낸다 (D-079)
struct RootView: View {
  let environment: AppEnvironment
  let keys: AccessKeyStore
  let client: APIClient
  @State private var path: [Route] = []

  var body: some View {
    if keys.hasKey {
      NavigationStack(path: $path) {
        CommodityListView(
          // 서버 연결 줄은 dev 변형만 (2단계 확인용)
          healthRepository: environment.variant == .development
            ? LiveHealthRepository(client: client) : nil
        )
        .navigationDestination(for: Route.self) { route in
          switch route {
          case .accessKey: accessKey
          }
        }
      }
      .onChange(of: keys.isRejected) { _, rejected in
        if rejected, path.last != .accessKey { path.append(.accessKey) }
      }
    } else {
      NavigationStack { accessKey }
    }
  }

  // 저장 뒤 옛 키로 실패한 조회 다시 불러오기는 repository 캐시가 생기면 onSaved로 넣는다
  private var accessKey: some View {
    AccessKeyView(store: keys, verifier: LiveAccessKeyVerifier(client: client))
  }
}
