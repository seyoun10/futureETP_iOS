# History

TODO.md에서 끝난 항목을 같은 절 이름 아래로 옮겨 둔다.

## 원본 변경 반영
- [x] 레이어 import 방향 lint 강제(2026-11-19, futureETP D-041 변경): `tuist inspect dependencies --only implicit`를 `scripts/check.sh`에 넣음(2026-11-24, IOS-003 보충)
- [x] API 계약 JSON Schema 생성(2026-11-19, futureETP D-142): `../futureETP_ReactNative/packages/shared/contract/`. 3단계 응답 모델은 이 파일을 기준으로 한다(아래 3단계에 반영됨, 확인 뒤 체크) → 응답·요청 모델 모두 계약 기준으로 작성(2026-11-24)
- [x] rare 레벨 입력 규칙 강화(2026-11-21, futureETP 품질 검증 B2/D1·D3): rare 레벨은 소수 첫째 자리로 반올림한 값으로 중복을 본다(1과 1.00000000001은 중복). C-a `levels` query는 `^d+(.d+)?(,d+(.d+)?)*$`만 받는다(공백·`0x8`·`1e1` 거절, 계약 `disparityQuery`). 앱 입력 검증이 같은 규칙인지, 직렬화가 숫자 기본 문자열(`1`, `2.5`)인지 확인. 모델 `RareLevels`(반올림 뒤 중복·범위·소수 첫째 자리)와 `levels` 직렬화는 반영(2026-11-24), B 설정 rare-level 입력도 이 타입으로 검증·저장(2026-11-24, `RareLevelsDraft`)
- [x] 휴장 달력 화면 A-a(2026-11-21, futureETP D-143): A title-bar [⚙] 왼쪽에 [📅](`calendar-month-outline`) → 이번 달~다다음 달 3개월 세로 달력, 오늘(기기 로컬)·CME/KRX/NYSE 휴장(채운 점)·조기 마감/개장 지연(빈 점)·달별 휴일 이름 목록·미입력 안내. API `GET /v1/calendar?from&to`(계약 `calendar`·`calendarQuery`), 색 `colors.market`·`today`, 문구 `calendar.*`. `../futureETP_ReactNative/docs/wireframes/screens.md` A-a. 캐시: 응답 `missing`이 비어 있으면 12시간, 있으면 5분 stale(화면 재진입·앱 복귀 때 다시 조회, 서버 import 뒤 재시작 없이 반영. futureETP `useMarketCalendar.ts`) → `HolidayCalendar` feature(`CalendarView`·`CalendarScreenModel`·`MonthGrid`·`CalendarText`), A [📅](`CalendarButton`, SF `calendar`), `LiveCalendarRepository`·`QueryCache.marketCalendar`(`StalePolicy.after`로 12시간/5분). 시뮬레이터에서 dev 서버 달력·한국 시간대 로컬 이동 확인(2026-11-24)
- [x] 휴장 달력 일정을 기기 로컬로(2026-11-23, futureETP D-144): 예외 일정을 시장 날짜 대신 기기 로컬 날짜 칸에 둔다. 시각 있는 일정은 `at`(시장 현지)을, CLOSED는 정규 개장 시각(CME 전날 17:00 CT, KRX 09:00 KST, NYSE 09:30 ET)을 로컬로 바꾼 날짜. 목록과 날짜 칸 점은 로컬 시각순(휴장은 정규 개장 시각, 같은 시각은 시장 순). 문구 시각은 로컬 `HH:mm`이고 시간대 표기 없음(`calendar.kinds`의 `{{tz}}`·`calendar.timeZones` 삭제). 조회 범위를 앞뒤 하루씩 넓히고 3개월 밖 연도 `missing`은 숨김. 같은 날 같은 시장 점이 둘일 수 있음. futureETP `features/calendar/localSchedule.ts`, screens.md A-a → `LocalSchedule`(Foundation `Calendar`·`TimeZone`로 시장 벽시계 → 기기 로컬)·`CalendarSchedule`(로컬 날짜 칸·화면 밖 연도 `missing` 숨김), 조회 범위 앞뒤 하루씩(2026-11-24)
- [x] 첫 로딩 가운데 스피너(2026-11-19, futureETP 527a3b2·e94b2c2): 첫 조회 중 스켈레톤(공용 막대·차트 격자) 위 가운데에 큰 스피너, 차트 탭은 차트 자리 가운데이고 데이터가 온 뒤 첫 기간 맞춤 전에도 띄운다 → 공용 막대 `LoadingView`, 차트 탭 `ChartSkeleton`(`CenterSpinner` 겹침). C-a·C-c는 기간 맞춤 전(`model.view == nil`)에도 `ChartSkeleton`, C-b는 RN도 기간 맞춤이 없다(2026-11-24 대조)
- [x] 차트 데이터가 바뀌면 십자선·상세 박스 지우기(2026-11-21, futureETP E1 수정): C-a·C-c에서 이전 3년을 앞에 붙이거나 자동 새로고침으로 데이터 배열이 바뀌면 십자선과 상세 박스를 지운다(옛 순번으로 다른 봉을 가리키지 않게). `../futureETP_ReactNative/docs/wireframes/screens.md` C-a 길게 누르기 → `ChartInteraction.dataChanged`·`ChartViewState.dataChanged`가 앞에 붙이기·새로고침 모두 십자선을 지움(같은 값이면 건드리지 않음), 테스트로 확인(2026-11-25)

## 0. 환경
- [x] Xcode 27.2(27B52) · Swift 6.4.4 · 시뮬레이터 런타임 iOS 27.2 확인(2026-11-24)
- [x] 프로젝트 파일 관리: Tuist 4.218.4 + mise 고정 (IOS-003)

## 1. 스택 확정
- [x] `docs/tech-stack.md`의 후보를 하나씩 정한다. 각 패키지·도구의 최신 안정 버전을 웹 검색으로 확인하고 출처 날짜를 적는다. 결정과 근거는 `docs/decisions.md`(IOS-003부터)

## 2. 스캐폴딩
- [x] `brew install mise` → `mise install`(Tuist), `Project.swift`로 프로젝트 생성, 앱 ID `io.github.seyoon.futureetp`·dev `.dev` 두 변형(scheme `FutureETP-Dev`·`FutureETP`), 앱 이름(`futureETP`·`futureETP Dev`)·아이콘(RN `icon.png`를 검정 배경으로 알파 제거)(2026-11-24)
- [x] lint·format·test 설정과 검사 명령 `scripts/check.sh`(lint → generate → `tuist inspect dependencies --only implicit` → Release 빌드 → Debug-Dev 테스트), `.swift-format` 기본값·2칸, CLAUDE.md Commands 갱신(2026-11-24)
- [x] dev 변형이 로컬 dev 서버 `GET /v1/health`를 부르는 최소 화면으로 연결 확인: Core `HealthRepository`, A 자리에 dev 전용 `server: ok` 줄(4단계 A 구현 때 지운다), 시뮬레이터에서 확인(2026-11-24)
- [x] (선택) 원격 저장소·CI(GitHub Actions에서 check): `.github/workflows/check.yml`(러너 `xcode-27`, Xcode 27.2, futureETP main을 함께 받아 `FUTUREETP_DIR`로 넘김) 작성(2026-11-24). PR #1에서 첫 실행 통과(check 7분 28초, 2026-11-25)


## 3. 공통 기반
- [x] API client: `Core/API` `APIClient`(Bearer·`X-Device-Id`, 키 없으면 요청 없이 `UNAUTHORIZED`, 전체 15초 타임아웃, 봉투 디코딩·봉투 아닌 5xx는 `INTERNAL`·모르는 코드는 `SCHEMA_MISMATCH`, GET만 `NETWORK`·`TIMEOUT`·`INTERNAL` 최대 2회 재시도 1초·2초, 호출자 취소는 `CancellationError`)·`AppError`, `HealthRepository`를 그 위로 옮김(2026-11-24, D-042, D-072)
- [x] 응답 모델: `../futureETP_ReactNative/packages/shared/contract/schemas/*.json`과 맞춘 모델(손으로 쓴 Codable, IOS-007) + 계약 테스트(실제 dev 서버 응답을 저장한 예시를 모델로 디코딩하고, 같은 예시가 JSON Schema를 통과하는지) (D-142)
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
- [x] import redundant 검사 켜기(2026-11-25): `scripts/check.sh`에서 `--only implicit`을 지우고, Core를 import하지 않는 `CommodityListTests`는 Core 의존을 빼서 redundant 검사 통과 (IOS-003 보충)
- [x] 공용 조회 UI: 기준 시각 줄(freshness)·로딩/오류/빈 상태 분기·`nextUpdateAt` + 1분 자동 새로고침·앱 복귀 재조회·접근 키 저장 뒤 전체 재조회(`AccessKeyView` `onSaved`, 기다리지 않음) (D-048, D-075, D-044)
  - View 완료(2026-11-24): `FooterLine`·`FreshnessLine`(`FooterTime`)·`QueryStateView`(`QueryState.phase`)·`LoadingView`·`CenterSpinner`·`ErrorView`
  - 조회 캐시 완료(2026-11-24): `QueryCache`(키 접두사 무효화·`keepFor` 5분/차트 1시간)·`Query`(진행 중 조회 합류·`StalePolicy.untilNextUpdate`)·`.queryLifecycle`(진입·앱 복귀 재조회·`nextUpdateAt` + 1분 자동 새로고침)·키 저장 뒤 전체 무효화. 무한 조회는 `ChartPages`·`PagedQuery`(`QueryCache.pagedQuery`, 받은 페이지 수만큼 다시 조회·`fetchOlder` 실패는 Alert용으로 돌려줌·늦은 응답도 붙음, 2026-11-24)
  - 최하단 줄 배치 완료(2026-11-25): `FooterLine`이 홈 인디케이터 여백 위쪽에 겹친다(루트 `providesHomeIndicatorInset`, 겹친 만큼 음수 아래 패딩, RN `FooterLine`). 줄 자리에서 여백을 읽으면 C에서 레이아웃이 끝없이 되풀이돼 루트에서 읽는다. 시뮬레이터에서 A·B·C 줄 위치(840~856pt)·C tab-bar가 여백 바로 위로 내려옴 확인
- [x] 접근 키 B-b: 붙여넣기·QR(`futureetp-key:v1:` 접두사), `GET /v1/settings`로 확인 뒤 저장, 키 없으면 첫 화면이 B-b, `UNAUTHORIZED`면 어느 화면에서든 B-b + 거절 줄 (D-044, D-077~D-079)
  - 코드 완료(a4da4d4~ba01dfd). 시뮬레이터에서 dev 서버 키 붙여넣기·Keychain 저장·재실행 유지 확인(2026-11-24). 14P prod에서 RN 앱을 덮어쓴 뒤 첫 화면 B-b·키 재입력 뒤 A 표시 확인(2026-11-25, iPhone 미러링 창에서 ⌘V 붙여넣기는 안 됨). 시뮬레이터에서 dev 서버 `API_TOKEN`을 바꿔 띄운 뒤 A·C 요청 거절 → B-b(거절 줄), 재실행 때도 B-b, 새 키 붙여넣기 → A, 원래 키로 되돌리기 확인(2026-11-25). 이때 형식 오류 줄이 `accessKey.badFormat` 키 이름으로 보이던 것과, A에서 바로 B-b로 올 때 큰 제목 모드를 이어받아 카드가 구분선에 붙던 것(`.inline`으로 고정)을 고침. 14P prod에서 [QR 읽기] → 카메라 화면, 키가 아닌 QR → `notKeyQr` 줄, 카메라 권한 끔 → `cameraUnavailable` 줄 확인(2026-11-25, 깔린 빌드가 b3c1c24 전이라 줄이 키 이름으로 보임. 시뮬레이터 최신 빌드에서 문구로 보임). 이때 가운데 정렬 [QR 읽기]·[취소] 아래 구분선이 글자 앞에서 시작해 짧던 것을 고침. 14P prod 빌드 93(88d5e15)에서 오류 줄 문구·[QR 읽기]·[취소] 구분선, 키 QR 스캔 → 저장 → A 확인(2026-11-25)
- [x] 앱 실행 때 시간대 PATCH (D-084), 세로 잠금·[⟲] 가로 전환 (D-076)
  - 시간대·언어 PATCH 코드 완료(2026-11-24): `SettingsStore`(설정 조회·낙관적 PATCH 줄 세우기)·`.deviceSettingsSync`(루트, 키 있을 때). dev 서버 확인 완료(2026-11-25): `TZ=America/Chicago`·영어로 실행하면 `device` 행이 `en`·`America/Chicago`로, 서울로 다시 실행하면 시간대가 되돌아감. 언어는 앱 설정 저장값이 기기 언어보다 앞서므로(D-033) B에서 [한국어]를 누를 때 `ko`로 PATCH됨
  - 세로 잠금 기반 완료(2026-11-24): `OrientationLock`(시작 세로, `lockPortrait`·`lockLandscape`·[⟲]용 `toggle(isLandscape:)`, `AppDelegate`가 허용 방향 반환)·`\.isLandscape`(창 모양, 루트 `providesIsLandscape`)
  - C [⟲] 완료(2026-11-24): ETP 탭 밖에서만 보임, ETP 탭 진입·C를 떠날 때 `lockPortrait`, 가로에서 tab-bar·기준 시각 줄 숨김. 시뮬레이터에서 가로 전환·가로에서 [←]로 A 세로 복귀 확인. 14P 미러링에서 [⟲] 가로 전환·세로 복귀 확인(2026-11-25). 14P에서 기기를 직접 돌릴 때 동작 확인(2026-11-25)

## 4. 화면 수직 슬라이스 (RN 순서)
- [x] A 원자재 목록: `GET /v1/commodities`, 대표월물 ●·알림 🔔·거래 없음, 당겨서 새로고침(햅틱·터치 차단·5초 시간 초과 Alert, D-138), C-a 이동·미리 조회 (D-085)
  - 완료(2026-11-24): `CommoditiesRepository`·`QueryCache.commodityList`, `CommodityListView`(행·등락 색·●·🔔·거래 없음·기준 시각 줄·[⚙] 알림 꺼짐 점), `PullRefresh`(5초 시간 초과·실패 Alert, 늦은 조회는 그대로 반영, 새로고침 중 `.blocksTouches`·루트 `.touchBlocker()`로 title-bar까지 터치 차단. 서버를 끈 시뮬레이터에서 [⚙] 차단·실패 Alert 확인), C·B 이동. 시뮬레이터에서 dev 서버 목록 표시 확인
  - 행 누를 때 C-a 미리 조회 완료(2026-11-25): `CommodityQueries.prefetchDisparity`를 RootView `onSelect`에서 기다리지 않고 시작
- [x] 화면별 세부 동작은 `../futureETP_ReactNative/docs/wireframes/screens.md`와 하나씩 대조
  - 완료(2026-11-25, RN `271b148` 기준): 공통 규칙·A·A-a·B·B-b·B-a·C·C-a(십자선·가로)·C-b·C-c·C-d·C-d-a 항목을 구현과 맞춰 봄. 문구는 RN `locales/ko.ts`·`en.ts`와 String Catalog를 스크립트로 비교해 키 243개·값 모두 같음. 자동 새로고침은 A·C-a~C-c만(ETP 응답에는 `freshness`가 없어 걸리지 않음)
  - 고친 것: B [초기화] 아이콘을 RN처럼 차트 [↻]와 같은 되돌리기 아이콘(`clock.arrow.circlepath`)으로. SF Symbols 대응표를 `docs/tech-stack.md`에 적음
  - X 푸시는 5단계, 실기기에서만 볼 수 있는 동작(120Hz·권한 배너·회전·QR)은 각 항목에 남음
- [x] C 화면 뼈대 (screens.md C, D-047, D-107, D-111)
  - 완료(2026-11-24): `CommodityView`(title-bar [←]·`원자재명 (심볼)`·🔔·[⟲]·[⚙], 시스템 뒤로 버튼 숨김으로 쓸어서 뒤로 가기 막음 D-105, 탭 4개는 처음 열 때 만들고 숨겨도 유지, 탭 화면이 `tabFooterTime`으로 보이는 탭의 기준 시각 줄을 올림), `ChartPeriods`(C-a·C-c 기간, C에 들어올 때마다 6M)·`ChartPeriod.nearest`, [⚙]는 A와 공용 `SettingsButton`. 시뮬레이터에서 탭 전환·문구 확인
  - title-bar 아래 1pt `barSeparator` 완료(2026-11-25): Core `titleBarSeparator()`를 `backTitleBar`·A·B-b·C·C-d-a에 붙임. 시뮬레이터에서 A·B·C·C-d-a 확인
  - ETP 상세 기간 유지 확인(2026-11-25): C-d-a는 C 위에 쌓이므로 C의 `ChartPeriods`가 그대로 남는다. 시뮬레이터에서 12M → C-d-a → 뒤로 12M 유지, A로 나갔다 다시 들어오면 6M 확인(D-107). 코드 변경 없음
  - title-bar 합치기 완료(2026-11-25): Core `backTitleBar`가 조각 제목·[←] 동작(`onBack`)·제목 최대 폭·오른쪽 버튼 여러 개를 받아 C·C-d-a도 같은 title-bar를 쓴다. 시뮬레이터에서 C·C-d-a 긴 이름·B·[←] 복귀 확인
  - C 탭 화면 채우기 완료(2026-11-25): 아래 C-a·C-c·C-b·C-d. 14P prod에서 GC 네 탭 표시 확인
- [x] C-a 이격도차트: `GET /v1/commodities/:code/disparity`, 기간 버튼 6개(D-102), 롤 음영, 십자선 상세, 가로 모드, 이전 3년 받기 중 화면 터치 차단·5초 시간 초과·실패 Alert (D-086, D-103, D-108, D-139)
  - 1단계 조회 완료(2026-11-24): `DisparityRepository`·`QueryCache.disparityChart`(키 `QueryKeys.disparity`, 설정 값별)
  - 2단계 계열 모델 완료(2026-11-24): `DisparityChartModel`(산출 불가일 제외·rare-level 밴드 순위 색·이평선 위·롤 음영/전환일·보이는 구간 최고·최저와 LC·HC·y축 특수 라벨·월물 구성·꼬리 백분위 표기)
  - 3단계 화면 뼈대 완료(2026-11-24): `DisparityTabView`(설정 → 조회, 설정 오류·스켈레톤)·`DisparityScreenModel`(같은 데이터면 그대로, 과거 봉이 앞에 붙으면 범위 유지)·`ChartViewState`(기간 홈·드래그/핀치로 벗어남·[↻]·가까운 기간 테두리)·`PeriodChips`·`ChartResetButton`·`ChartSkeleton`. 시뮬레이터에서 dev 서버 차트·드래그·[↻]·칩 확인
  - 4단계 정보 줄 완료(2026-11-24): `DisparityInfo`(기준값 이름·대체·롤 중·OHLC·안내·이격도 꼬리·LC·HC), 차트 위 반투명 두 줄과 기준값 안내 상자, 봉·선은 정보 줄 높이만큼 비켜 그림(`CanvasCandleChart.insetTop`). 시뮬레이터 확인
  - 5단계 축 완료(2026-11-24): `CandleAxes`(우측 y축 log 눈금 d3 `ticks(6)` 규칙·특수 라벨 밀기·눈금 글자 숨김, 현재가·마지막 종가 점선, x축 월 눈금, 십자선 가격·날짜 라벨과 겹치는 글자 숨김), `ChartAxes.swift`(`AxisTicks`·`PriceLabelLayout`·`MonthTicks`·`ChartText`). 제스처는 y축 자리를 뺀 폭으로 봉을 센다. 시뮬레이터 확인
  - 6단계 꼬리표·롤 표시 완료(2026-11-24): `ExtremeTagLayout`(가운데가 화면 안인 봉의 최고·최저 꼬리표, 회색 점선 비켜 가기·차트 끝에서 화살표 반대쪽), `CandleViewport.centerIndices`, `ChartRollMarks` 음영·전환일 점선(봉 뒤). 시뮬레이터에서 대표월물 전환일·꼬리표 확인(한국형·미국형 음영은 화면 확인 전)
  - 7단계 십자선 상세 완료(2026-11-24): `DisparityDetail`(날짜·월물 구성·전환일 `→ 새 월물`·시고저종·전일 대비·이격도 등락 색·선 값 가격순), 공용 `DetailBox`·`PlacedDetailBox`(정보 줄 아래 귀퉁이). 시뮬레이터 확인
  - 8단계 이전 3년 받기 완료(2026-11-24): `OlderPages`(첫 봉이 보이면 받기·햅틱·5초 시간 초과·실패 Alert·늦은 응답은 데이터만), `ChartViewState.rangeReports`(범위가 바뀌거나 드래그·핀치가 끝날 때 알림)·`locked`(받는 중 차트 제스처 무시), `OlderDataIndicator`, 받는 동안 `.blocksTouches`. 시뮬레이터에서 과거 봉 붙이기·범위 유지·서버를 끈 실패 Alert 확인
  - 9단계 A 행 누를 때 미리 조회 완료(2026-11-25): `CommodityQueries.prefetchDisparity`(캐시 설정을 그대로 쓰고 없을 때만 받음, 실패 무시, RN `prefetchDisparityChart`), RootView `onSelect`에서 기다리지 않고 시작
- [x] C-c 월물차트: `GET /v1/commodities/:code/contracts`, log y축, 끝값 라벨 (D-092, D-093, D-113, D-118)
  - 1단계 조회 완료(2026-11-24): `ContractsRepository`·`QueryCache.contractsChart`(키 `QueryKeys.contracts`)·`ChartPages.merged`(이전 페이지에 없는 월물은 nil로 채움, RN `mergeContractPages`)·`CommodityQueries.contracts`
  - 2단계 계열 모델 완료(2026-11-24): `ContractChartModel`(만기순 선 색·날짜별 위·아래 끝·너비용 라벨·범례 ●·보이는 범위 끝값 라벨 D-093·양끝 월물 연환산 롤 수익률), `LocalDate.days(to:)`
  - 3단계 선 차트·탭 화면 완료(2026-11-24): `CandleSeries(lines:high:low:)`(봉 없는 선 계열, 십자선 가격은 그날 값이 있는 첫 선)·`PriceScale` 선형 축(0 이하 값, D-113)을 `CanvasCandleChart`로 그림, `ContractTabView`·`ContractScreenModel`(기간 C-a와 따로·이전 3년 받기·과거 날짜가 앞에 붙으면 범위 유지), 범례 오버레이(`LegendLine`·`CenteredFlowLayout`, 대표월물 ● 회색), y축 끝값 라벨(보이는 범위 끝값, 선 색). 시뮬레이터에서 NG 선·범례·끝값·십자선 확인
  - 4단계 십자선 상세 박스 완료(2026-11-24): `ContractDetail`(날짜·마지막 날 잠정·값이 있는 월물별 가격 선 색·대표월물 ●·양끝 롤 수익률 `/년`), `DetailRow.Cell.mark`(이름 뒤 회색 표식), `PlacedDetailBox`로 범례 아래 덜 가리는 귀퉁이. 시뮬레이터에서 NG 상세 박스 확인
  - 선형 축 화면 확인 완료(2026-11-24): C-c는 지금 월물 5개만 그려 CLK20 음수(2020-04)는 나오지 않는다. 대신 CLH27·CLJ27·CLK27의 2018-11-05 정산가 0이 든 페이지를 받으면 받은 전체 값 기준으로 선형 축(0~60)이 된다(RN `LinesChart`와 같다). 같이 고침: 상세 박스를 범례·정보 줄·최신 버튼 위에 그린다(C-a·C-c, RN 순서)
- [x] C-b 월물커브: `GET /v1/commodities/:code/curve?baseDate`, 기준일 OS 날짜 피커, 이전·다음 기준일, 변화율 라벨 배치, 롤 수익률 (D-090, D-091, D-114~D-123)
  - 1단계 조회 완료(2026-11-24): `CurveRepository`·`QueryCache.curve`(키 `QueryKeys.curve`, 기준일마다, nil은 `"latest"`, 차트 캐시 1시간·`nextUpdateAt`까지 새것)·`CommodityQueries.curve`. 기준일을 옮기는 동안 이전 커브 유지(RN `keepPreviousData`)는 화면 모델에서
  - 2단계 좌표·표기 완료(2026-11-24): `CurveLayout`(월물 라벨 간격·가까운 칸·변화율 라벨 겹침 없이 배치·선 피하기, RN `curveLayout.ts`)·`CurveFormat`(기준일 `YYYY/MM/DD`·범례 날짜·요일·변화율 소수 첫째 자리·롤 수익률 줄). 눈금은 `AxisTicks.linear`(RN `niceTicks`와 같은 값)
  - 3단계 차트·탭 화면 완료(2026-11-24): `CurveChartLayout`(log·0 이하면 선형 y축, 8% 여백, 눈금 5개, 정보 줄 아래 선·점, 변화율 라벨 위·아래, 상세 박스 귀퉁이용 표시 구간)·`CurveChart`(Canvas, 기준일 실선+빈 점·비교일 점선+찬 점, 길게 눌러 월물에 붙는 십자선·햅틱·탭으로 지움, 덜 가리는 귀퉁이 상세 박스)·`CurveDetail`·`CurveScreenModel`(기준일, 이전 커브 유지, D-1은 기본 key, 휴장일 안내 3초)·`CurveTabView`(범례+롤 수익률 한 줄, 과거 기준일이면 되돌리기 D-115, `[<] 기준일 [>]` 줄은 가로 모드에서 숨김)·`BaseDateSheet`(휠 피커 시트, 확인을 눌러야 바뀜). 시뮬레이터에서 CL 2025/11/22(토) 선택→11/21로 옮김 안내·차트·십자선 상세 박스·되돌리기 확인. dev 서버 최근 기준일(11/19~20)은 월물이 없어 "표시할 월물이 없습니다"
- [x] C-d ETP 목록(필터·정렬은 앱에서)·C-d-a 상세 (D-017)
  - 완료(2026-11-24): `ETPRepository`·`QueryCache.etpList`·`etpDetail`(키 `QueryKeys.etps`·`etp`), `ETPListModel`(필터 4개·기본/순자산/거래대금 정렬·있는 배수만 선택지), 공용 `SegmentedRow`(Core, B 설정에서도 쓴다), `ETPListTabView`(행 둘째 줄 정렬 값·수집 시각은 기준 시각 줄), `ETPDetailView`(Route `.etp`, [←]만, 시리즈 줄·운용사 페이지는 http(s)만). 시뮬레이터에서 GC 목록·정렬·상세·복귀 확인

- [x] B 끝까지 스크롤하면 마지막 [데이터 출처] 행이 앱 번들 줄·홈 인디케이터 여백에 가려졌다(14P prod 미러링에서 휠 스크롤, 2026-11-25). 시뮬레이터(iPhone 18 Pro, iOS 27.2, 14P와 같은 27.2)에서 손가락 끌기로 끝까지 내리면 행 전체가 줄 위에 보여 재현 안 됨. 14P에서 손가락으로 끝까지 내리면 정상(2026-11-25). 미러링 휠 스크롤에서만 생김, 코드 변경 없음
  - 같이 본 것: 미러링(Mac 키보드)에서 rare-level을 누르면 [완료] 막대가 뜨고 앱 번들 줄이 남아 접근 키 행에 겹친다. 시뮬레이터 하드웨어 키보드에서는 막대가 뜨지 않아 재현 안 됨. 기기 키패드에서는 줄을 뺀다(`keyboardWillShow`)
- [x] B 설정·B-a 알림 설정: 낙관적 PATCH, rare-level 입력 검증, 알림 대상 없음 빨간 점 (D-081~D-083, D-124)
  - 완료(2026-11-24): `SettingsView`(일반·이격도차트·기타 묶음, `SegmentedRow`, rare-level 5칸 `RareLevelsInput`·`RareLevelsDraft`는 키패드가 닫힐 때 `RareLevels`로 검증·정렬 저장, [초기화] 확인 뒤 표시 설정·`SettingsPatch.disparityDefaults`+언어 PATCH, 저장 실패 줄은 이 화면의 마지막 변경만, 앱 번들 줄 IOS-009·키패드가 보이면 뺌), `AlertSettingsView`(권한 배너 `PushPermission`·대상 원자재·현재 적용 기준·`QuietTimeSection` 30분 48칸 시트), `DataSourcesView`, 공용 `backTitleBar`. `SegmentedRow`는 한 줄에 안 들어가면 쌓는다. 시뮬레이터에서 dev 서버로 언어 전환·rare-level 중복 오류·저장·초기화·알림 대상·알림 거부 시간·데이터 출처 확인
  - 14P prod 미러링 확인(2026-11-25): 권한 배너 [허용] → iOS 알림 권한 창, [허용 안 함] 뒤 배너가 [설정 열기]로 바뀌고 누르면 iOS 설정의 futureETP 알림 화면이 열림, 돌아오면 배너 유지. 14P는 알림 거부 상태로 둠(Apple 가입 뒤 설정에서 켠다). 키패드 [완료]가 rare-level 칸을 덮는지는 확인하지 않기로 함(사용자 결정, 2026-11-25)
## 6. 기기 설치·운영
- [x] prod 변형 release 빌드를 개인 기기에 설치하는 절차를 `docs/ops.md`에 기록, `scripts/install-prod.sh`(2026-11-25, 14P 대상 `--build-only` 서명 빌드 확인. 실제 설치는 RN prod 앱을 덮어써서 아직 안 함)
- [x] RN 앱과 같은 앱 ID라 바꿔 설치할 때 할 일 기록(`docs/ops.md`)
- [x] 업데이트 배포 방식: OTA 없음, 같은 스크립트로 재설치, 빌드 번호는 커밋 수 (IOS-010)
- [x] 14P에 실제 설치해 B 맨 아래 빌드 번호·접근 키 재입력 흐름 확인(2026-11-25, 빌드 83 `eddcbd2`, B 맨 아래 `런타임 1.0.0 (83)`)
