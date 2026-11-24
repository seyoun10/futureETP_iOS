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
        healthRepository: environment.flatMap {
          $0.variant == .development ? LiveHealthRepository(baseURL: $0.apiBaseURL) : nil
        }
      )
    }
  }
}
