import Foundation
import SwiftUI
import Testing

@testable import Core

struct UpDownPaletteTests {
  @Test func koreanIsRedUpBlueDownAndAmericanIsGreenUpRedDown() {
    let kr = UpDownPalette(.kr)
    let us = UpDownPalette(.us)
    #expect(kr.up == Color(hex: 0xef5350))
    #expect(kr.down == Color(hex: 0x42a5f5))
    #expect(us.up == Color(hex: 0x26a69a))
    #expect(kr.up == us.down)
    #expect(kr.flat == Theme.Colors.neutral)
  }

  @Test func picksBySign() {
    let palette = UpDownPalette(.us)
    #expect(palette.color(for: 0.5) == palette.up)
    #expect(palette.color(for: -0.01) == palette.down)
  }

  @Test func zeroAndNaNAreFlat() {
    let palette = UpDownPalette(.us)
    #expect(palette.color(for: 0) == palette.flat)
    #expect(palette.color(for: -0.0) == palette.flat)
    #expect(palette.color(for: .nan) == palette.flat)
  }

  @Test func roundsToShownDecimals() {
    let palette = UpDownPalette(.us)
    #expect(palette.color(for: -0.04, decimals: 1) == palette.flat)
    #expect(palette.color(for: 0.04, decimals: 1) == palette.flat)
    #expect(palette.color(for: -0.05, decimals: 1) == palette.down)
    #expect(palette.color(for: 0.06, decimals: 1) == palette.up)
  }

  @Test func pairIsFlatWhenBothRoundToZero() {
    let palette = UpDownPalette(.kr)
    #expect(palette.color(change: 0.0004, changePct: 0.004, decimals: 3) == palette.flat)
    #expect(palette.color(change: -0.04, changePct: -0.001, decimals: 1) == palette.flat)
  }

  @Test func pairFollowsTheNonZeroSide() {
    let palette = UpDownPalette(.kr)
    #expect(palette.color(change: 0.0004, changePct: 0.014, decimals: 3) == palette.up)
    #expect(palette.color(change: -0.1, changePct: -0.002, decimals: 1) == palette.down)
  }
}

@MainActor
struct DisplaySettingsTests {
  private func makeDefaults() -> UserDefaults {
    let suite = "DisplaySettingsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
  }

  @Test func koreanLanguageAndKoreaRegionDefaults() {
    let settings = DisplaySettings(defaults: makeDefaults(), locale: Locale(identifier: "ko_KR"))
    #expect(settings.language == .ko)
    #expect(settings.upDownStyle == .kr)
  }

  @Test func languageAndRegionAreSeparate() {
    let enKR = DisplaySettings.defaults(for: Locale(identifier: "en_KR"))
    #expect(enKR.language == .en && enKR.upDownStyle == .kr)
    let koUS = DisplaySettings.defaults(for: Locale(identifier: "ko_US"))
    #expect(koUS.language == .ko && koUS.upDownStyle == .us)
  }

  @Test func otherLocalesFallBackToEnglishAndAmerican() {
    let jaJP = DisplaySettings.defaults(for: Locale(identifier: "ja_JP"))
    #expect(jaJP.language == .en && jaJP.upDownStyle == .us)
    let none = DisplaySettings.defaults(for: Locale(identifier: ""))
    #expect(none.language == .en && none.upDownStyle == .us)
  }

  @Test func savesAndRestores() {
    let defaults = makeDefaults()
    let settings = DisplaySettings(defaults: defaults, locale: Locale(identifier: "ko_KR"))
    settings.language = .en
    settings.upDownStyle = .us
    #expect(settings.palette == UpDownPalette(.us))

    let restored = DisplaySettings(defaults: defaults, locale: Locale(identifier: "ko_KR"))
    #expect(restored.language == .en)
    #expect(restored.upDownStyle == .us)
  }

  @Test func ignoresUnknownStoredValues() {
    let defaults = makeDefaults()
    defaults.set("JP", forKey: DisplaySettings.upDownStyleKey)
    defaults.set("ja", forKey: DisplaySettings.languageKey)
    let settings = DisplaySettings(defaults: defaults, locale: Locale(identifier: "ko_KR"))
    #expect(settings.language == .ko)
    #expect(settings.upDownStyle == .kr)
  }
}
