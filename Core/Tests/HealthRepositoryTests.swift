import Core
import Foundation
import Testing

struct HealthRepositoryTests {
  private func repository(
    body: String, seen: (@Sendable (URLRequest) -> Void)? = nil
  ) -> LiveHealthRepository {
    LiveHealthRepository(baseURL: URL(string: "http://localhost:3000")!) { request in
      seen?(request)
      return (Data(body.utf8), URLResponse())
    }
  }

  @Test func decodesOK() async throws {
    let health = try await repository(
      body: #"{"success":true,"data":{"status":"ok","commit":"abc123"}}"#
    ).fetch()
    #expect(health == Health(status: "ok", commit: "abc123"))
  }

  @Test func callsHealthPathWithoutAuth() async throws {
    _ = try await repository(
      body: #"{"success":true,"data":{"status":"ok","commit":null}}"#,
      seen: { request in
        #expect(request.url?.absoluteString == "http://localhost:3000/v1/health")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
      }
    ).fetch()
  }

  @Test func failsOnErrorEnvelope() async {
    await #expect(throws: HealthError.notOK) {
      try await repository(
        body: #"{"success":false,"error":{"code":"INTERNAL","message":"x"}}"#
      ).fetch()
    }
  }
}
