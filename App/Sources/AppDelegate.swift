import Core
import UIKit

/// 허용 방향을 `OrientationLock`이 정한다. 시작은 세로 (D-076)
final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    OrientationLock.mask
  }
}
