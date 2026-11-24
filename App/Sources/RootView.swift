import Commodity
import CommodityList
import Core
import Settings
import SwiftUI

/// 스택에 올리는 화면
enum Route: Hashable {
  case accessKey
  #if DEBUG
    /// C-a 차트 스파이크(dev 전용, TODO 4단계)
    case chartSpike
  #endif
}

/// 접근 키가 없으면 A 대신 B-b만 띄운다. 저장하면 스택으로 바뀐다 (screens.md B-b, D-044).
/// 저장된 키를 서버가 거절하면 어느 화면에서든 B-b로 보낸다 (D-079)
struct RootView: View {
  let environment: AppEnvironment
  let keys: AccessKeyStore
  let client: APIClient
  let queryCache: QueryCache
  let settings: SettingsStore
  @State private var path: [Route] = []

  var body: some View {
    #if DEBUG
      // dev 빌드는 실행 인자 `-chartSpike`로 키 확인 없이 스파이크 화면만 연다(서버를 쓰지 않는다)
      if ProcessInfo.processInfo.arguments.contains("-chartSpike") {
        NavigationStack { ChartSpikeView() }
      } else {
        content
      }
    #else
      content
    #endif
  }

  @ViewBuilder private var content: some View {
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
          #if DEBUG
            case .chartSpike: ChartSpikeView()
          #endif
          }
        }
        #if DEBUG
          .toolbar {
            NavigationLink(value: Route.chartSpike) {
              Image(systemName: "waveform")
            }
            .accessibilityIdentifier("openChartSpike")
          }
        #endif
      }
      // 기기 시간대·앱 언어를 서버 설정에 맞춘다. 키가 있을 때만 (D-084, D-137)
      .deviceSettingsSync(settings)
      .onChange(of: keys.isRejected) { _, rejected in
        if rejected, path.last != .accessKey { path.append(.accessKey) }
      }
    } else {
      NavigationStack { accessKey }
    }
  }

  // 저장 뒤 옛 키로 실패한 조회를 다시 불러온다. 보이는 화면만 바로, 나머지는 다음 진입 때 (D-044)
  private var accessKey: some View {
    AccessKeyView(
      store: keys, verifier: LiveAccessKeyVerifier(client: client),
      onSaved: { queryCache.invalidate() })
  }
}
