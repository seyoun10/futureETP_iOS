import Foundation

/// 빌드 변형(D-043)과 서버 주소. 값은 xcconfig → Info.plist에서 읽는다
public struct AppEnvironment: Sendable, Equatable {
    public enum Variant: String, Sendable {
        case development
        case production
    }

    public let variant: Variant
    public let apiBaseURL: URL
    /// dev 변형에서만 값이 있다 (D-044)
    public let devAPIToken: String?

    public init(variant: Variant, apiBaseURL: URL, devAPIToken: String?) {
        self.variant = variant
        self.apiBaseURL = apiBaseURL
        self.devAPIToken = devAPIToken
    }

    /// Info.plist 값으로 만든다. 키가 없거나 주소가 잘못되면 nil
    public init?(infoDictionary: [String: Any]) {
        guard
            let variant = (infoDictionary["AppVariant"] as? String).flatMap(Variant.init(rawValue:)),
            let urlString = infoDictionary["APIBaseURL"] as? String,
            let url = URL(string: urlString), url.scheme != nil, url.host() != nil
        else { return nil }
        let token = (infoDictionary["DevAPIToken"] as? String) ?? ""
        self.init(
            variant: variant,
            apiBaseURL: url,
            devAPIToken: variant == .development && !token.isEmpty ? token : nil
        )
    }
}
