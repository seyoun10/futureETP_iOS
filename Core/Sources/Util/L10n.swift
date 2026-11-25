import Foundation
import Synchronization

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
    // 차트 축 라벨처럼 프레임마다 부르는 곳이 있어, 자리 표시자가 없으면 정규식을 건너뛴다(IOS-008)
    guard template.contains("{{") else { return template }
    return template.replacing(placeholder) { match in
      values[String(match.output.1)] ?? String(match.output.0)
    }
  }

  /// 정규식 리터럴은 평가할 때마다 다시 해석되므로 한 번만 만든다
  nonisolated(unsafe) private static let placeholder = #/\{\{(\w+)\}\}/#

  /// 언어별 `.lproj` 번들. 경로 찾기가 프레임마다 반복되지 않게 번들 경로·언어로 기억한다
  private static let languageBundles = Mutex<[String: Bundle]>([:])

  private static func languageBundle(for locale: Locale, in bundle: Bundle) -> Bundle {
    let language: AppLanguage = locale.language.languageCode == .korean ? .ko : .en
    let key = "\(bundle.bundlePath)|\(language.rawValue)"
    if let cached = languageBundles.withLock({ $0[key] }) { return cached }
    let found =
      bundle.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:))
      ?? bundle
    languageBundles.withLock { $0[key] = found }
    return found
  }
}
