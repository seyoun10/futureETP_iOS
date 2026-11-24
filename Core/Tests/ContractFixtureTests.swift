import Core
import Foundation
import Testing

/// 계약 테스트의 모델 쪽: 저장한 dev 서버 응답(`Fixtures/`)을 `APIClient`로 디코딩한다.
/// 같은 파일이 원본 스키마를 통과하는지는 `scripts/validate-fixtures.mjs`가 본다 (D-142, IOS-007)
struct ContractFixtureTests {
  @Test func health() async throws {
    let health = try await decode("health", as: Health.self)
    #expect(health.status == "ok")
  }

  @Test func commodities() async throws {
    let data = try await decode("commodities", as: Commodities.self)
    #expect(!data.commodities.isEmpty)
    #expect(data.commodities.allSatisfy { !$0.contracts.isEmpty })
  }
}

/// 예시 파일 하나를 실제 디코딩 경로(봉투·`JSONDecoder.api()`)로 읽는다
func decode<Response: Decodable & Sendable>(
  _ fixture: String, as type: Response.Type
) async throws -> Response {
  let url = try #require(Bundle.module.url(forResource: fixture, withExtension: "json"))
  let body = try Data(contentsOf: url)
  let client = APIClient(
    baseURL: URL(string: "http://localhost:3000")!,
    accessToken: { "token" },
    deviceID: { "device" },
    transport: { request in
      let response = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (body, response)
    },
    retryDelay: { _ in .zero }
  )
  return try await client.send(APIRequest("/fixture", as: type))
}
