import Core
import Foundation
import Testing

struct HealthRepositoryTests {
  private func repository(body: String) -> LiveHealthRepository {
    let client = APIClient(
      baseURL: URL(string: "http://localhost:3000")!,
      accessToken: { nil },
      deviceID: { "" },
      transport: { request in
        #expect(request.url?.absoluteString == "http://localhost:3000/v1/health")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        let response = HTTPURLResponse(
          url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
      },
      retryDelay: { _ in .zero }
    )
    return LiveHealthRepository(client: client)
  }

  @Test func decodesOKWithoutAuth() async throws {
    let health = try await repository(
      body: #"{"success":true,"data":{"status":"ok","commit":"abc123"}}"#
    ).fetch()
    #expect(health == Health(status: "ok", commit: "abc123"))
  }

  @Test func nullCommitIsAllowed() async throws {
    let health = try await repository(
      body: #"{"success":true,"data":{"status":"ok","commit":null}}"#
    ).fetch()
    #expect(health.commit == nil)
  }

  @Test func statusOtherThanOKIsSchemaMismatch() async {
    await #expect(throws: AppError(.schemaMismatch, message: "health.status is down")) {
      try await repository(
        body: #"{"success":true,"data":{"status":"down","commit":null}}"#
      ).fetch()
    }
  }
}
