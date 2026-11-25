import CoreGraphics
import Testing

@testable import Core

@Suite struct FooterLineTests {
  @Test func overlapsWholeLineWhenInsetIsTaller() {
    // 여백 34pt, 줄 16pt면 줄 전체가 여백 위쪽에 들어가고 아래 18pt가 남는다 (RN FooterLine)
    #expect(FooterLine.overlap(inset: 34, lineHeight: 16) == 16)
  }

  @Test func overlapsOnlyInsetWhenInsetIsShorter() {
    #expect(FooterLine.overlap(inset: 10, lineHeight: 16) == 10)
    #expect(FooterLine.overlap(inset: 0, lineHeight: 16) == 0)
  }
}
