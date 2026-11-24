import Core
import Foundation

/// 알림 거부 시간 선택지와 표기 (RN `QuietTimeSection`, D-007, D-026)
enum QuietTimeSlots {
  /// 켤 때 처음 값(screens.md B-a 예시 23:00~07:00)
  static let defaultValue = QuietTime(startMin: 23 * 60, endMin: 7 * 60)

  /// 30분 단위 48칸(00:00~23:30)
  static let minutes = Array(
    stride(from: 0, through: QuietTime.maxMinute, by: QuietTime.stepMinutes))

  /// 기기 현지 자정 기준 분 → 24시간제 `HH:mm`
  static func text(_ minute: Int) -> String {
    let hours = minute / 60
    let minutes = minute % 60
    return (hours < 10 ? "0" : "") + "\(hours):" + (minutes < 10 ? "0" : "") + "\(minutes)"
  }

  /// 자정을 넘기면 종료 시각에 `다음 날`을 붙인다
  static func endsNextDay(_ value: QuietTime) -> Bool { value.startMin > value.endMin }

  enum Edge: Hashable, Identifiable {
    case start, end
    var id: Self { self }
  }

  static func minute(_ value: QuietTime, _ edge: Edge) -> Int {
    edge == .start ? value.startMin : value.endMin
  }

  /// `edge` 쪽 시각을 `minute`으로 바꾼 값. 같은 값이거나 반대쪽 시각(시작≠종료)이면 nil
  static func picking(_ minute: Int, for edge: Edge, in value: QuietTime) -> QuietTime? {
    switch edge {
    case .start:
      guard minute != value.startMin, minute != value.endMin else { return nil }
      return QuietTime(startMin: minute, endMin: value.endMin)
    case .end:
      guard minute != value.endMin, minute != value.startMin else { return nil }
      return QuietTime(startMin: value.startMin, endMin: minute)
    }
  }
}
