# History

TODO.md에서 끝난 항목을 같은 절 이름 아래로 옮겨 둔다.

## 원본 변경 반영
- [x] 레이어 import 방향 lint 강제(2026-11-19, futureETP D-041 변경): `tuist inspect dependencies --only implicit`를 `scripts/check.sh`에 넣음(2026-11-24, IOS-003 보충)
- [x] API 계약 JSON Schema 생성(2026-11-19, futureETP D-142): `../futureETP/packages/shared/contract/`. 3단계 응답 모델은 이 파일을 기준으로 한다(아래 3단계에 반영됨, 확인 뒤 체크) → 응답·요청 모델 모두 계약 기준으로 작성(2026-11-24)

## 0. 환경
- [x] Xcode 27.2(27B52) · Swift 6.4.4 · 시뮬레이터 런타임 iOS 27.2 확인(2026-11-24)
- [x] 프로젝트 파일 관리: Tuist 4.218.4 + mise 고정 (IOS-003)

## 1. 스택 확정
- [x] `docs/tech-stack.md`의 후보를 하나씩 정한다. 각 패키지·도구의 최신 안정 버전을 웹 검색으로 확인하고 출처 날짜를 적는다. 결정과 근거는 `docs/decisions.md`(IOS-003부터)

## 2. 스캐폴딩
- [x] `brew install mise` → `mise install`(Tuist), `Project.swift`로 프로젝트 생성, 앱 ID `io.github.seyoon.futureetp`·dev `.dev` 두 변형(scheme `FutureETP-Dev`·`FutureETP`), 앱 이름(`futureETP`·`futureETP Dev`)·아이콘(RN `icon.png`를 검정 배경으로 알파 제거)(2026-11-24)
- [x] lint·format·test 설정과 검사 명령 `scripts/check.sh`(lint → generate → `tuist inspect dependencies --only implicit` → Release 빌드 → Debug-Dev 테스트), `.swift-format` 기본값·2칸, CLAUDE.md Commands 갱신(2026-11-24)
- [x] dev 변형이 로컬 dev 서버 `GET /v1/health`를 부르는 최소 화면으로 연결 확인: Core `HealthRepository`, A 자리에 dev 전용 `server: ok` 줄(4단계 A 구현 때 지운다), 시뮬레이터에서 확인(2026-11-24)


## 3. 공통 기반
- [x] API client: `Core/API` `APIClient`(Bearer·`X-Device-Id`, 키 없으면 요청 없이 `UNAUTHORIZED`, 전체 15초 타임아웃, 봉투 디코딩·봉투 아닌 5xx는 `INTERNAL`·모르는 코드는 `SCHEMA_MISMATCH`, GET만 `NETWORK`·`TIMEOUT`·`INTERNAL` 최대 2회 재시도 1초·2초, 호출자 취소는 `CancellationError`)·`AppError`, `HealthRepository`를 그 위로 옮김(2026-11-24, D-042, D-072)
- [x] 응답 모델: `../futureETP/packages/shared/contract/schemas/*.json`과 맞춘 모델(손으로 쓴 Codable, IOS-007) + 계약 테스트(실제 dev 서버 응답을 저장한 예시를 모델로 디코딩하고, 같은 예시가 JSON Schema를 통과하는지) (D-142)
  - [x] 장치: 도메인 enum·`Freshness`·`LocalDate`·`ContractMonth`·`JSONDecoder.api()`, 예시 저장 `scripts/capture-fixtures.sh`·zod 검증 `scripts/validate-fixtures.mjs`(check.sh)·`ContractFixtureTests`, `health`·`commodities`(2026-11-24)
  - [x] `disparityChart`·`contractsChart`·`curve`(`before`·`baseDate` 변형 예시 포함, 2026-11-24)
  - [x] `etpList`·`etpDetail`(KRX ETN·US ETF 예시, 2026-11-24)
  - [x] `calendar`·`settings`·`device`(missing 빈·찬 달력, 2026-11-24)
  - [x] 요청 본문·query(`settingsPatch`·`deviceRegistration`·`*Query`) 인코딩: `SettingsPatch`(끄기는 `null`)·`DeviceRegistration`(`ios-<버전>`)·`RareLevels`(검증·`levels` 직렬화)·`*Query`, 예시 `Fixtures/Requests/`를 Swift 인코딩과 zod 양쪽으로 검증(2026-11-24)
