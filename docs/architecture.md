# Architecture

> Swift/SwiftUI 앱의 구조. API 규약·화면 동작은 원본(`../futureETP/docs/architecture.md`·`wireframes/screens.md`)을 따르고, 여기에는 이 앱의 구조와 대응만 적는다.
> 디렉터리는 2단계 스캐폴딩으로 만든 골격이다. 아직 없는 폴더는 해당 단계에서 만든다.

## 디렉터리 구조

```
Project.swift / Tuist.swift     Tuist 프로젝트 정의(타깃·configuration·scheme·의존성, IOS-003). 생성물은 커밋 안 함
mise.toml                       Tuist 버전 고정
Config/                         Base·Debug-Dev·Release.xcconfig, Secrets.example(→ Secrets.xcconfig, 커밋 안 함)
App/Sources, App/Resources      타깃 FutureETP: @main, 루트 내비게이션, 환경(설정·Locale) 주입, Assets(AppIcon·LaunchBackground). features·Core에 의존
Features/                       feature마다 framework 타깃 하나. Core에만 의존
├─ CommodityList/               A
├─ HolidayCalendar/             A-a 휴장 달력(일정을 기기 로컬 날짜로 옮김, D-144). `Foundation.Calendar`와 겹치지 않게 이름을 바꿈
├─ Settings/                    B, B-a, B-b, 데이터 출처
└─ Commodity/                   C: DisparityChart(C-a)·ContractChart(C-c)·Curve(C-b)·ETP(C-d, C-d-a)
   └─ Sources/Chart/            C-a·C-c 공용 캔들 차트(Canvas)·뷰포트(IOS-008). Spike/는 dev 전용 측정 화면
Core/                           framework 타깃 Core. 다른 타깃에 의존하지 않음
├─ AppEnvironment.swift         변형·서버 주소·dev 토큰(Info.plist ← xcconfig)
├─ API/                         APIClient, AppError, 엔드포인트, 조회 캐시
│  └─ Models/                   계약 스키마별 Codable 모델, 도메인 enum, LocalDate·ContractMonth, JSONDecoder.api() (IOS-007)
├─ UI/                          공용 View(ScreenHeader, FreshnessLine, QueryStateView, SegmentedControl)
├─ Settings/                    기기 UI 설정(언어·등락 색)
├─ Theme/                       테마 토큰(다크 전용)
├─ Push/                        APNs 등록, 알림 탭 이동
├─ Util/                        숫자·날짜 포맷, Keychain, 햅틱
└─ Resources/                   Assets
*/Tests/                        타깃별 Swift Testing 테스트 타깃. Core/Tests/Fixtures는 계약 예시(dev 서버 응답, IOS-007)
FutureETPUITests/               XCUITest
docs/                           tech-stack, architecture, decisions
```

규칙
- 화면 → `@Observable` 모델(화면별 Model) → repository → API client 한 방향. 화면은 HTTP·저장소를 직접 부르지 않는다.
- 화면 전용 코드는 해당 feature 안에, 두 곳 이상에서 쓰면 공용 계층(`core`)으로 옮긴다.
- import 방향(RN D-041, 2026-11-19 lint로 강제): feature끼리 import하지 않는다(컴포넌트·헬퍼·조회도 다른 feature가 쓰면 `Core`로 옮긴다). `Core`는 features·`App`을 import하지 않고, features는 `App`(라우트)을 import하지 않는다. Tuist 타깃 의존성(App → features → Core)만 선언하고, 선언 밖 import는 `tuist inspect dependencies --only implicit`가 실패로 잡는다(컴파일러는 같은 빌드 폴더의 framework를 막지 못한다, IOS-003).
- RN에서 공용으로 옮긴 것: `SectionHeader`·`SettingsHeaderButton`(공용 UI), 에러 code → 사용자 문구 함수 `errorText`(API의 `AppError` 옆), ETP 정렬 기준 `ETP_SORTS`(util).
- 문구는 RN과 같은 점 경로 키(`accessKey.guide`)로 `Text("…")`에 넘긴다. 카탈로그는 앱 번들(main)에 있어 features의 기본 조회가 그대로 찾는다. 직접 고치지 않고 RN 리소스를 바꾼 뒤 `node scripts/gen-strings.mjs`로 다시 만든다(`check.sh`가 최신 여부와 Swift가 쓰는 키가 있는지 본다). 값의 자리 표시자는 RN 그대로 `{{name}}`이라 이름으로 바꿔 넣는다.
- 월물 심볼은 서버 표준형(`CLZ26`)만 쓴다. 표시 표기(`DEC26`)는 포맷 함수가 만든다.

## 레이어

MVVM + repository (IOS-005). Clean Architecture의 UseCase·Entity 계층은 두지 않는다.

| 계층 | 맡는 것 | 하지 않는 것 |
|---|---|---|
| 화면(SwiftUI View) | 그리기, 사용자 입력, 상태 구독 | HTTP, 저장소, 계산 |
| 상태(`@Observable` 화면 Model = ViewModel, `<Screen>Model`) | 화면 상태(로딩·데이터·오류), 사용자 동작 처리, 자동 새로고침 타이머 | HTTP 세부 |
| repository | 조회 캐시(staleTime·gcTime), 무한 조회(`before`·`hasMore`), 낙관적 PATCH | 화면 문구 |
| API client | 헤더, 타임아웃, 봉투 디코딩, `AppError`, 재시도 | 캐시 |

- 캐시 규칙은 RN과 같다: C 차트 조회는 `staleTime`을 `nextUpdateAt`까지, `gcTime` 1시간. 휴장 달력은 `missing`이 비면 12시간, 있으면 5분(`StalePolicy.after`). C-a·C-c는 3년(756거래일) 단위로 받고 가장 과거 봉이 보이면 이전 3년을 더 받는다(D-104). 커브는 캐시하지 않는다(D-046).
- 구현: `Core/API/QueryCache`가 키(`[String]`)마다 `Query`를 하나 둔다. repository가 `cache.query(key, stalePolicy:, fetch:)`로 `Query`를 내주고, 화면 Model은 `query.state`(`QueryState`)를 읽고, 화면은 `.queryLifecycle(query)`로 진입·앱 복귀 재조회와 자동 새로고침을 건다. 재시도·`UNAUTHORIZED` 처리는 `APIClient` 몫이다

## RN 구조 대응

| RN(`../futureETP/apps/mobile/src`) | 이 앱 |
|---|---|
| `src/app/`(Expo Router) | `App/` + `NavigationStack`·`TabView` |
| `src/features/*` | `Features/*` |
| `src/api`(fetch 래퍼·AppError·TanStack Query) | `Core/API`(APIClient + 조회 캐시) |
| `src/charts`(Victory + Skia) | `Features/Commodity/Sources/Chart`(Canvas, 차트는 C 화면만 쓴다) |
| `src/stores`(Zustand persist) | `Core/Settings`(`@Observable` + UserDefaults) |
| `src/theme` | `Core/Theme` |
| `src/i18n` | `App/Resources/Localizable.xcstrings`(RN `locales/{ko,en}.ts`에서 `scripts/gen-strings.mjs`로 생성)·`InfoPlist.xcstrings` |
| `src/push` | `Core/Push` |
| `src/lib` | `Core/Util` |

## D-번호 적용

공통 결정은 `../futureETP/docs/decisions.md`. 이 앱에 어떻게 적용하는지만 나눈다.

- 그대로 적용: 제품·화면·API·UX 결정. 예) D-001~D-026(제품), D-036·D-042·D-044·D-048·D-072(API·에러·접근 키·자동 새로고침), D-075~D-086, D-090~D-093, D-102~D-125, D-137~D-139(화면 동작)
- 플랫폼 수단으로 바꿔 적용: D-030(상태·패칭), D-031(스타일·테마), D-033(i18n), D-041(레이어), D-043·D-052(변형), D-073(표시 설정 저장), D-087(차트 부품), D-128(deprecated API 금지 → 이 언어의 deprecated 경고를 오류로)
- 적용 안 함(RN·Expo 전용): D-027·D-029·D-032·D-050(Expo·Router·Victory·스캐폴딩), D-039의 EAS Update, D-054·D-140(jest-expo·Jest 캐시)
- 판단이 애매하면 해당 D 항목을 읽고 `decisions.md`에 IOS-xxx로 적용 방식을 적는다.
