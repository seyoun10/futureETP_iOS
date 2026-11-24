import Core
import Foundation
import SwiftUI

@main
struct FutureETPApp: App {
  private let environment: AppEnvironment
  @State private var keys: AccessKeyStore
  private let client: APIClient

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
    client = APIClient(
      baseURL: environment.apiBaseURL,
      accessToken: { await keys.key },
      deviceID: { installationID.value },
      onRejected: { await keys.report(AppError(.unauthorized)) }
    )
  }

  var body: some Scene {
    WindowGroup {
      RootView(environment: environment, keys: keys, client: client)
    }
  }
}
