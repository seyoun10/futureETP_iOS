import Foundation

/// 자리 표시자가 있는 문구. 카탈로그 값은 RN 그대로 `{{name}}`이라(scripts/gen-strings.mjs) 이름으로 바꿔 넣는다.
/// 자리 표시자가 없는 문구는 `Text("a.b")`로 그대로 쓴다
public enum L10n {
  /// `key`의 문구를 `locale` 언어(한국어가 아니면 영어, D-033)로 찾아 `values`를 넣는다
  public static func string(
    _ key: String, _ values: [String: String] = [:], locale: Locale = .current,
    bundle: Bundle = .main
  ) -> String {
    let template = languageBundle(for: locale, in: bundle)
      .localizedString(forKey: key, value: nil, table: nil)
    return fill(template, values)
  }

  /// `{{name}}`을 `values[name]`으로 바꾼다. 없는 이름은 그대로 둔다
  public static func fill(_ template: String, _ values: [String: String]) -> String {
    template.replacing(#/\{\{(\w+)\}\}/#) { match in
      values[String(match.output.1)] ?? String(match.output.0)
    }
  }

  private static func languageBundle(for locale: Locale, in bundle: Bundle) -> Bundle {
    let language: AppLanguage = locale.language.languageCode == .korean ? .ko : .en
    return bundle.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:))
      ?? bundle
  }
}
