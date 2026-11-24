import Core
import Foundation
import Testing

struct AccessKeyVerifierTests {
  @Test func sendsTheNewKeyInsteadOfTheStoredOne() async throws {
    let url = try #require(Bundle.module.url(forResource: "settings", withExtension: "json"))
    let body = try Data(contentsOf: url)
    let client = APIClient(
      baseURL: URL(string: "http://localhost:3000")!,
      accessToken: { "stored" },
      deviceID: { "device" },
      transport: { request in
        #expect(request.url?.absoluteString == "http://localhost:3000/v1/settings")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer new")
        let response = HTTPURLResponse(
          url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, response)
      },
      retryDelay: { _ in .zero }
    )
    try await LiveAccessKeyVerifier(client: client).verify("new")
  }

  @Test func rejectionIsUnauthorized() async {
    let client = APIClient(
      baseURL: URL(string: "http://localhost:3000")!,
      accessToken: { nil },
      deviceID: { "device" },
      transport: { request in
        let response = HTTPURLResponse(
          url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
        let body = #"{"success":false,"error":{"code":"UNAUTHORIZED","message":"bad key"}}"#
        return (Data(body.utf8), response)
      },
      retryDelay: { _ in .zero }
    )
    await #expect(throws: AppError(.unauthorized, status: 401, message: "bad key")) {
      try await LiveAccessKeyVerifier(client: client).verify("wrong")
    }
  }
}
