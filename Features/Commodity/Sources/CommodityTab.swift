import Core
import SwiftUI

/// C 하단 탭 4개. 순서는 이격도차트 / 월물차트 / 월물커브 / ETP (D-047, D-111)
public enum CommodityTab: String, CaseIterable, Sendable {
  case disparity
  case contracts
  case curve
  case etps

  /// 처음 여는 탭
  public static let initial: CommodityTab = .disparity

  /// [⟲] 가로 전환은 차트 탭(C-a~C-c)에서만 (D-076)
  public var canRotate: Bool { self != .etps }

  // 보간한 리터럴은 `%@` 키가 되므로 문자열로 만든 뒤 키로 쓴다
  var titleKey: LocalizedStringKey {
    let key = "commodity.tabs.\(rawValue)"
    return LocalizedStringKey(key)
  }
}

/// 탭 화면이 기준 시각 줄에 보일 시각. 보이는 탭 것만 tab-bar 아래 줄에 쓴다
struct TabFooterTimeKey: PreferenceKey {
  static let defaultValue: FooterTime? = nil

  static func reduce(value: inout FooterTime?, nextValue: () -> FooterTime?) {
    value = value ?? nextValue()
  }
}

extension View {
  /// C 탭 화면의 기준 시각. 데이터가 없으면 nil(빈 줄로 자리를 지킨다)
  func tabFooterTime(_ time: FooterTime?) -> some View {
    preference(key: TabFooterTimeKey.self, value: time)
  }
}
