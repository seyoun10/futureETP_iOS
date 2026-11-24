import CommodityList
import Core
import Foundation
import SwiftUI

@main
struct FutureETPApp: App {
  private let environment = AppEnvironment(infoDictionary: Bundle.main.infoDictionary ?? [:])
  private let installationID = InstallationID()

  var body: some Scene {
    WindowGroup {
      CommodityListView(
        healthRepository: environment.flatMap { environment in
          guard environment.variant == .development else { return nil }
          // 접근 키 저장소는 B-b 항목에서 연결한다. health는 인증 헤더를 쓰지 않는다
          let token = environment.devAPIToken
          let installationID = installationID
          let client = APIClient(
            baseURL: environment.apiBaseURL, accessToken: { token },
            deviceID: { installationID.value })
          return LiveHealthRepository(client: client)
        }
      )
    }
  }
}
