# History

TODO.md에서 끝난 항목을 같은 절 이름 아래로 옮겨 둔다.

## 원본 변경 반영
- [x] 레이어 import 방향 lint 강제(2026-11-19, futureETP D-041 변경): `tuist inspect dependencies --only implicit`를 `scripts/check.sh`에 넣음(2026-11-24, IOS-003 보충)
- [x] API 계약 JSON Schema 생성(2026-11-19, futureETP D-142): `../futureETP/packages/shared/contract/`. 3단계 응답 모델은 이 파일을 기준으로 한다(아래 3단계에 반영됨, 확인 뒤 체크) → 응답·요청 모델 모두 계약 기준으로 작성(2026-11-24)
- [x] rare 레벨 입력 규칙 강화(2026-11-21, futureETP 품질 검증 B2/D1·D3): rare 레벨은 소수 첫째 자리로 반올림한 값으로 중복을 본다(1과 1.00000000001은 중복). C-a `levels` query는 `^d+(.d+)?(,d+(.d+)?)*$`만 받는다(공백·`0x8`·`1e1` 거절, 계약 `disparityQuery`). 앱 입력 검증이 같은 규칙인지, 직렬화가 숫자 기본 문자열(`1`, `2.5`)인지 확인. 모델 `RareLevels`(반올림 뒤 중복·범위·소수 첫째 자리)와 `levels` 직렬화는 반영(2026-11-24), B 설정 rare-level 입력도 이 타입으로 검증·저장(2026-11-24, `RareLevelsDraft`)
- [x] 휴장 달력 화면 A-a(2026-11-21, futureETP D-143): A title-bar [⚙] 왼쪽에 [📅](`calendar-month-outline`) → 이번 달~다다음 달 3개월 세로 달력, 오늘(기기 로컬)·CME/KRX/NYSE 휴장(채운 점)·조기 마감/개장 지연(빈 점)·달별 휴일 이름 목록·미입력 안내. API `GET /v1/calendar?from&to`(계약 `calendar`·`calendarQuery`), 색 `colors.market`·`today`, 문구 `calendar.*`. `../futureETP/docs/wireframes/screens.md` A-a. 캐시: 응답 `missing`이 비어 있으면 12시간, 있으면 5분 stale(화면 재진입·앱 복귀 때 다시 조회, 서버 import 뒤 재시작 없이 반영. futureETP `useMarketCalendar.ts`) → `HolidayCalendar` feature(`CalendarView`·`CalendarScreenModel`·`MonthGrid`·`CalendarText`), A [📅](`CalendarButton`, SF `calendar`), `LiveCalendarRepository`·`QueryCache.marketCalendar`(`StalePolicy.after`로 12시간/5분). 시뮬레이터에서 dev 서버 달력·한국 시간대 로컬 이동 확인(2026-11-24)
- [x] 휴장 달력 일정을 기기 로컬로(2026-11-23, futureETP D-144): 예외 일정을 시장 날짜 대신 기기 로컬 날짜 칸에 둔다. 시각 있는 일정은 `at`(시장 현지)을, CLOSED는 정규 개장 시각(CME 전날 17:00 CT, KRX 09:00 KST, NYSE 09:30 ET)을 로컬로 바꾼 날짜. 목록과 날짜 칸 점은 로컬 시각순(휴장은 정규 개장 시각, 같은 시각은 시장 순). 문구 시각은 로컬 `HH:mm`이고 시간대 표기 없음(`calendar.kinds`의 `{{tz}}`·`calendar.timeZones` 삭제). 조회 범위를 앞뒤 하루씩 넓히고 3개월 밖 연도 `missing`은 숨김. 같은 날 같은 시장 점이 둘일 수 있음. futureETP `features/calendar/localSchedule.ts`, screens.md A-a → `LocalSchedule`(Foundation `Calendar`·`TimeZone`로 시장 벽시계 → 기기 로컬)·`CalendarSchedule`(로컬 날짜 칸·화면 밖 연도 `missing` 숨김), 조회 범위 앞뒤 하루씩(2026-11-24)

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
- [x] installation ID: `Core/Util` `InstallationID`(UUID v4 소문자, 저장값이 형식 밖이면 새로 만듦, 저장 실패해도 이번 실행은 만든 값, RN `deviceId.ts`와 같은 규칙)·Keychain 래퍼 `Keychain`(`SecureStore` protocol, `AfterFirstUnlockThisDeviceOnly`), 앱의 `X-Device-Id`에 연결(2026-11-24, D-120)
- [x] 숫자·날짜 포맷: `Core/Util` `NumberFormat`(가격·변화량·등락률·월물 `DEC26`·`2612`, JS `toFixed`와 같은 반올림)·`AmountFormat`(억·만, T·B·M·K)·`DateTimeFormat`(`MM/DD HH:mm`·거래일 `MM/DD`), RN `lib/format*.test.ts`와 같은 기대값 + 반올림 경계 테스트(2026-11-24)
- [x] 테마 토큰·등락 색 설정 저장: `Core/Theme` `Theme`(RN `tokens.ts` 색·간격·글자·모서리·터치 영역)·`UpDownPalette`(KR·US, 보이는 자릿수로 반올림해 방향 고름), `Core/Settings` `DisplaySettings`(`@Observable` + UserDefaults, 언어·등락 색, 기본값은 기기 언어·지역), 앱은 다크 고정·배경 토큰·환경 주입(2026-11-24, D-031, D-073)
- [x] i18n ko/en, 앱 안 언어 설정을 서버 기기 설정과 맞춤 (D-033, D-073, D-137)
  - 문구 카탈로그는 RN 리소스에서 생성(`scripts/gen-strings.mjs`), `{{name}}` 자리 표시자 helper `L10n`, 앱 언어를 루트 `\.locale`로 주입(`DisplaySettings.locale`, 언어만 바꾸고 기기 지역 유지, 시뮬레이터에서 ko/en 전환 확인) (2026-11-24). B 설정 언어 선택은 4단계 B에서(2026-11-24)
  - 서버 기기 설정과 맞춤은 `DeviceSettingsSync`로 완료(2026-11-24, D-137)
