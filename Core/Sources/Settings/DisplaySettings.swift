import Foundation
import Observation

/// 기기별 UI 설정(언어·등락 색). 서버 데이터는 두지 않는다(D-047). RN `stores/displaySettings.ts`와 같은 규칙:
/// 저장값이 없으면 언어는 기기 언어, 등락 색은 기기 지역을 따른다(D-033). 한국어가 아니면 영어, 한국이 아니면 미국식.
/// UserDefaults는 동기로 읽어 앱 시작 때 색이 바뀌며 깜빡이지 않는다(D-030, D-073)
@MainActor
@Observable
public final class DisplaySettings {
  static let languageKey = "display-settings.language"
  static let upDownStyleKey = "display-settings.upDownStyle"

  public var language: AppLanguage {
    didSet { defaults.set(language.rawValue, forKey: Self.languageKey) }
  }

  public var upDownStyle: UpDownStyle {
    didSet { defaults.set(upDownStyle.rawValue, forKey: Self.upDownStyleKey) }
  }

  /// 지금 등락 색 스타일의 팔레트
  public var palette: UpDownPalette { UpDownPalette(upDownStyle) }

  /// 화면 문구용 locale. 루트에서 `\.locale`로 넣어 `Text`·`L10n`이 앱 언어로 문구를 찾는다(D-033).
  /// 언어만 앱 설정으로 바꾸고 지역·달력 등은 기기 값을 둔다
  public var locale: Locale { language.locale(base: baseLocale) }

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let baseLocale: Locale

  public init(defaults: UserDefaults = .standard, locale: Locale = .current) {
    self.defaults = defaults
    baseLocale = locale
    let fallback = Self.defaults(for: locale)
    language =
      defaults.string(forKey: Self.languageKey).flatMap(AppLanguage.init(rawValue:))
      ?? fallback.language
    upDownStyle =
      defaults.string(forKey: Self.upDownStyleKey).flatMap(UpDownStyle.init(rawValue:))
      ?? fallback.upDownStyle
  }

  /// 저장값이 없을 때 기기 언어·지역으로 정하는 기본값
  nonisolated static func defaults(for locale: Locale) -> (
    language: AppLanguage, upDownStyle: UpDownStyle
  ) {
    (
      language: locale.language.languageCode == .korean ? .ko : .en,
      upDownStyle: locale.region == .southKorea ? .kr : .us
    )
  }
}

extension AppLanguage {
  /// `base`에서 언어만 이 값으로 바꾼 locale
  public func locale(base: Locale) -> Locale {
    var components = Locale.Components(locale: base)
    components.languageComponents = Locale.Language.Components(
      languageCode: self == .ko ? .korean : .english, region: base.region)
    return Locale(components: components)
  }
}
