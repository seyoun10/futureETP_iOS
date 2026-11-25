import CoreGraphics

/// 키패드가 입력칸을 가리는지 (RN `useKeepFocusedInputVisible`의 `overlapToScroll`)
enum KeyboardAvoidance {
  /// 입력칸 아래로 남길 여백. 칸 아래 안내 줄까지 보이게 한다
  static let gap: CGFloat = 48

  /// 입력칸 아래 + 여백이 보이는 영역 아래보다 내려간 만큼 더 끌어올릴 거리. 안 가려지면 0
  static func overlap(inputBottom: CGFloat, visibleBottom: CGFloat, gap: CGFloat = gap) -> CGFloat {
    max(0, inputBottom + gap - visibleBottom)
  }
}
