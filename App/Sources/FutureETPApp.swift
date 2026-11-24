import Core
import Foundation
import SwiftUI

@main
struct FutureETPApp: App {
  @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
  private let environment: AppEnvironment
  @State private var keys: AccessKeyStore
  @State private var displaySettings = DisplaySettings()
  private let client: APIClient
  /// 서버 응답 메모리 캐시. 앱 하나에 하나 (D-030)
  private let queryCache: QueryCache
  private let settings: SettingsStore

  init() {
    guard let environment = AppEnvironment(infoDictionary: Bundle.main.infoDictionary ?? [:]) else {
      // 빌드 설정 오류라 시작하지 않는다
      fatalError("Info.plist AppVariant/APIBaseURL is missing or invalid (Config/*.xcconfig)")
    }
    // 저장된 키가 없으면 dev 변형만 DEV_API_TOKEN을 쓴다 (D-044)
    let keys = AccessKeyStore(fallback: environment.devAPIToken)
    let installationID = InstallationID()
    self.environment = environment
    _keys = State(initialValue: keys)
    let client = APIClient(
      baseURL: environment.apiBaseURL,
      accessToken: { await keys.key },
      deviceID: { installationID.value },
      onRejected: { await keys.report(AppError(.unauthorized)) }
    )
    let queryCache = QueryCache()
    self.client = client
    self.queryCache = queryCache
    settings = SettingsStore(repository: LiveSettingsRepository(client: client), cache: queryCache)
  }

  var body: some Scene {
    WindowGroup {
      RootView(
        environment: environment, keys: keys, client: client, queryCache: queryCache,
        settings: settings
      )
      .environment(displaySettings)
      // 가로 레이아웃은 잠금 상태가 아니라 창 모양으로 정한다 (D-076)
      .providesIsLandscape()
      // 앱 안 언어 설정을 화면 문구에 적용한다 (D-033, D-073)
      .environment(\.locale, displaySettings.locale)
      // 다크 전용 테마(D-031)
      .preferredColorScheme(.dark)
      .background(Theme.Colors.background)
    }
  }
}
