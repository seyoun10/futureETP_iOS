import CommodityList
import Core
import Foundation
import SwiftUI

@main
struct FutureETPApp: App {
  private let environment = AppEnvironment(infoDictionary: Bundle.main.infoDictionary ?? [:])

  var body: some Scene {
    WindowGroup {
      CommodityListView(
        healthRepository: environment.flatMap { environment in
          guard environment.variant == .development else { return nil }
          // 접근 키·installation ID 저장소는 3단계 다음 항목에서 연결한다. health는 둘 다 쓰지 않는다
          let token = environment.devAPIToken
          let client = APIClient(
            baseURL: environment.apiBaseURL, accessToken: { token }, deviceID: { "" })
          return LiveHealthRepository(client: client)
        }
      )
    }
  }
}
