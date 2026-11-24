import Core
import Foundation
import Testing

struct AppEnvironmentTests {
    @Test func readsDevelopmentValues() throws {
        let env = try #require(
            AppEnvironment(infoDictionary: [
                "AppVariant": "development",
                "APIBaseURL": "http://localhost:3000",
                "DevAPIToken": "secret",
            ]))
        #expect(env.variant == .development)
        #expect(env.apiBaseURL.absoluteString == "http://localhost:3000")
        #expect(env.devAPIToken == "secret")
    }

    @Test func ignoresTokenInProduction() throws {
        let env = try #require(
            AppEnvironment(infoDictionary: [
                "AppVariant": "production",
                "APIBaseURL": "https://futureetp-api.duckdns.org",
                "DevAPIToken": "secret",
            ]))
        #expect(env.devAPIToken == nil)
    }

    @Test func emptyTokenIsNil() throws {
        let env = try #require(
            AppEnvironment(infoDictionary: [
                "AppVariant": "development", "APIBaseURL": "http://localhost:3000", "DevAPIToken": "",
            ]))
        #expect(env.devAPIToken == nil)
    }

    @Test(arguments: [
        [:],
        ["AppVariant": "staging", "APIBaseURL": "http://localhost:3000"],
        ["AppVariant": "development", "APIBaseURL": "localhost"],
    ])
    func rejectsInvalidValues(_ info: [String: String]) {
        #expect(AppEnvironment(infoDictionary: info) == nil)
    }
}
