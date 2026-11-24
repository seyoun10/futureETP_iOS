import Core
import Foundation

/// rare-level 5칸 입력 상태 (RN `features/settings/RareLevelsInput.tsx`, screens.md B).
/// 칸 사이를 옮기는 동안은 저장하지 않고, 키패드가 닫힐 때 5개 모두 맞으면 정렬해 저장한다.
/// 칸을 벗어날 때마다 저장하면 순서대로 입력하는 중에 정렬된 값으로 칸이 바뀐다
struct RareLevelsDraft: Equatable {
  enum Problem: Equatable {
    /// 범위 밖·소수 둘째 자리·숫자가 아님
    case invalid
    /// 소수 첫째 자리로 반올림해 같은 값이 있다
    case duplicate
  }

  static let maxLength = 4

  /// 고치는 중인 값. nil이면 서버 값을 보여 준다(저장 뒤 정렬된 값으로 돌아간다)
  private(set) var texts: [String]?
  private(set) var problem: Problem?

  /// 칸에 보일 글자. 서버 값을 아직 모르면 빈 칸
  func texts(levels: [Double]?) -> [String] {
    texts ?? levels?.map(RareLevels.text) ?? Array(repeating: "", count: RareLevels.count)
  }

  mutating func change(_ index: Int, to text: String, levels: [Double]?) {
    var current = texts(levels: levels)
    current[index] = String(text.prefix(Self.maxLength))
    texts = current
    problem = nil
  }

  /// 키패드가 닫혔다. 저장할 값이 있으면 돌려준다. 규칙 밖이면 `problem`을 두고 저장하지 않는다.
  /// 서버 값과 같으면 고치던 값만 지운다
  mutating func commit(levels: [Double]?) -> RareLevels? {
    guard let texts, let levels else { return nil }
    let values = texts.map(Self.parse)
    guard values.allSatisfy(RareLevels.isValid) else {
      problem = .invalid
      return nil
    }
    guard let parsed = RareLevels(values) else {
      problem = .duplicate
      return nil
    }
    self.texts = nil
    return parsed.values == levels ? nil : parsed
  }

  /// 기기에 따라 소수점이 쉼표로 들어온다. 숫자·소수점 밖 글자(공백 안쪽·부호·지수)는 거절한다
  static func parse(_ text: String) -> Double {
    let normalized = text.trimmingCharacters(in: .whitespaces).replacing(",", with: ".")
    guard normalized.wholeMatch(of: /\d+(\.\d+)?/) != nil else { return .nan }
    return Double(normalized) ?? .nan
  }
}
