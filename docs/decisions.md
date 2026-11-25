# 결정 기록 (Decision Log)

> Swift/SwiftUI 앱의 결정과 근거를 시간순으로 추가한다. 번호는 `IOS-xxx`이고 공통 결정 D-xxx(`../futureETP_ReactNative/docs/decisions.md`)와 겹치지 않는다.
> 번복 시 기존 항목은 지우지 말고 상태를 `대체됨`으로 바꾼다. 공통으로 바뀌어야 할 결정(제품·API·화면 동작)은 여기가 아니라 futureETP에 D-xxx로 적는다.

<!--
## IOS-001: <제목>
- 날짜: YYYY-MM-DD
- 상태: 확정 | 검토중 | 대체됨(IOS-xxx)
- 맥락:
- 선택지:
- 결정:
- 근거:
- 영향:
-->

## IOS-001: 공통 문서는 futureETP 원본을 상대경로로 읽는다
- 날짜: 2026-11-18
- 상태: 확정 (사용자 요청, D-141)
- 맥락: 같은 서버로 RN·Flutter·Swift·Kotlin 앱 네 개를 만든다. 제품·화면·API 계약 문서를 저장소마다 둘지 정해야 했다.
- 선택지: (a) futureETP 원본 + 상대경로 참조 (b) 저장소마다 복사 (c) 상위 공통 폴더로 이동
- 결정: (a). 이 저장소는 `CLAUDE.md`·`TODO.md`·`docs/tech-stack.md`·`architecture.md`·`decisions.md`만 갖고, 나머지는 `../futureETP_ReactNative/...`를 읽는다. 두 저장소는 같은 상위 폴더(`_project/futureETP/`)에 나란히 있어야 한다.
- 근거: 복사하면 제품 결정이 바뀔 때 네 곳을 고쳐야 해 어긋난다. 원본 변경은 futureETP가 이 저장소 `TODO.md`의 "원본 변경 반영"에 적는다.
- 영향: `CLAUDE.md` "공통 문서", `TODO.md` "원본 변경 반영".

## IOS-002: 앱 ID를 RN과 같이 쓰고 `appVersion` 접두사로 구분한다
- 날짜: 2026-11-18
- 상태: 확정 (사용자 요청, D-141)
- 맥락: 앱마다 다른 ID면 한 기기에 함께 설치할 수 있지만 서버 푸시 설정(FCM 앱 등록·APNs topic)을 여러 앱으로 늘려야 한다.
- 결정: 앱 ID `io.github.seyoon.futureetp`, dev 변형 `io.github.seyoon.futureetp.dev`. `PUT /v1/devices`의 `appVersion`은 `ios-<버전>`.
- 근거: 서버·Firebase·APNs 설정을 바꾸지 않는다. `appVersion`은 64자 문자열이라 스키마 변경 없이 어느 클라이언트인지 서버 기록에서 알 수 있다.
- 영향: 한 기기에 RN 앱과 함께 설치할 수 없다. 바꿔 설치하면 새 installation ID로 새 기기 행이 생겨 접근 키·기기 설정을 다시 넣는다. 서명 키가 다르면 기존 앱을 지운 뒤 설치해야 한다(Android).

## IOS-003: 프로젝트 파일은 Tuist로 생성하고 모듈로 import 방향을 강제한다
- 날짜: 2026-11-24
- 상태: 확정 (사용자 선택)
- 맥락: `.xcodeproj`(pbxproj)는 사람이 아닌 Claude가 편집하기 어렵고 병합 충돌이 잦다. 또 RN D-041의 import 방향(feature끼리 금지, 공용 → feature 금지)을 검사로 강제해야 한다.
- 선택지: (a) Xcode 프로젝트 직접(폴더 동기화 그룹) + SPM 로컬 패키지 (b) XcodeGen 2.46.0(`project.yml`) (c) Tuist(`Project.swift`)
- 결정: (c) Tuist CLI 4.218.4(GitHub 최신 stable 릴리스, 2026-11-23 확인). 버전은 저장소 `mise.toml`에 `tuist = "4.218.4"`로 고정하고 `brew install mise` → `mise install`로 설치한다(Tuist 공식 권장 방식).
  - 타깃: 앱 `FutureETP` → feature framework(`CommodityList`·`Commodity`·`Settings` 등) → `Core`. 의존성은 이 방향으로만 선언해 feature 간·`Core` → feature import가 빌드 오류가 되게 한다.
  - 변형: configuration `Debug-Dev`·`Release` + `Config/*.xcconfig`. dev bundle ID `.dev`.
  - 생성물(`*.xcodeproj`·`*.xcworkspace`·`Derived/`)은 커밋하지 않고 `tuist generate`로 만든다.
- 근거: 프로젝트 정의가 Swift 코드라 편집·리뷰가 쉽고, 모듈 경계를 선언 한 곳에서 관리한다. 사용자가 (a) 추천 대신 (c)를 골랐다.
- 보충(2026-11-24, 스캐폴딩): 같은 빌드 폴더에 framework가 모두 생겨 선언하지 않은 타깃도 import하면 컴파일된다(`CommodityList`에서 `import Settings`가 빌드 성공으로 확인). 그래서 import 방향은 컴파일러가 아니라 `tuist inspect dependencies --only implicit`(선언 밖 import를 찾으면 실패)로 막고, 검사 명령(`check`)에 넣는다. 화면 코드 타깃은 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `Core`는 기본(nonisolated)이다. 경고는 모두 오류로 한다(D-128 대응).
- 보충(2026-11-25): App이 `Commodity`·`Settings`·`Core`를 모두 import하게 되어 `--only implicit`를 지우고 redundant 검사도 켠다. Core를 import하지 않는 feature 테스트(`CommodityListTests`)는 Core 의존을 선언하지 않는다(`Project.swift` `testsWithoutCore`).
- 영향: 빌드·테스트 전에 `tuist generate`(또는 `tuist test`)가 필요하다. 2단계에서 CLAUDE.md Commands를 실제 명령으로 고친다. Tuist 버전을 올릴 때는 `mise.toml`만 바꾼다.

## IOS-004: 최소 배포 버전은 iOS 18이다
- 날짜: 2026-11-24
- 상태: 확정 (사용자 선택)
- 맥락: 최신은 iOS 27(2026-09 출시)이고 개인 기기 iPhone 14 Pro도 iOS 27을 지원한다(Apple, 2026-06-08 발표).
- 선택지: (a) iOS 27(N) (b) iOS 26(N-1) (c) iOS 18(N-2)
- 결정: (c) iOS 18. 테스트는 설치된 iOS 27.2 시뮬레이터로 하고, iOS 18 런타임은 필요해질 때 설치한다.
- 근거: 사용자가 보편적인 하위 호환 범위를 골랐다. 반대 의견: 사용자 1명·기기 1대라 하위 호환 이점이 작고, iOS 26·27 전용 API를 쓰려면 `#available` 분기가 생긴다(추천은 (a)였다).
- 영향: `@Observable`(17+)·`sensoryFeedback`(17+)·Swift Charts·VisionKit `DataScannerViewController`(16+)는 분기 없이 쓴다. iOS 26 이상 전용 API(Liquid Glass 계열 등)는 iOS 18 대안을 먼저 쓰고, 꼭 필요하면 `#available`로 감싼다. 18에서 동작은 실기기·18 런타임으로 확인하지 않는 한 보장하지 않는다.

## IOS-005: 아키텍처는 MVVM + repository이고 Clean Architecture 계층은 두지 않는다
- 날짜: 2026-11-24
- 상태: 확정 (사용자 선택)
- 맥락: MVVM·Clean Architecture 적용 여부. 기존 설계는 View → `@Observable` 화면 Model → repository → API client였다.
- 선택지: (a) MVVM + repository (b) Clean Architecture 전체(Presentation·Domain(Entity·UseCase·Repository protocol)·Data(DTO·구현)) (c) MVVM + Domain 모듈만 분리
- 결정: (a). 화면 `@Observable` 타입이 ViewModel 역할이고 이름은 `<Screen>Model`(예: `CommodityListModel`)로 쓴다. repository는 protocol과 구현으로 나눠 테스트에서 가짜로 바꾼다. 응답 `Codable` 모델을 화면까지 그대로 쓰고 Entity로 다시 매핑하지 않는다.
- 근거: 앱은 계산하지 않고 서버 값을 표시만 해서 UseCase는 대부분 값을 넘기기만 하고 DTO↔Entity 매핑만 늘어난다. RN 구조(D-041: 화면 → 훅 → 조회 → API)와 1:1로 대응해 원본 변경을 따라가기 쉽다. 의존 방향은 Tuist 타깃(IOS-003)이 강제한다.
- 영향: 로직이 있는 곳(낙관적 PATCH, rare 레벨 입력 검증, 무한 조회)은 화면 Model 또는 repository에 둔다. 한 로직을 두 화면 이상이 쓰면 `Core`로 옮긴다.

## IOS-006: 나머지 스택은 후보대로 확정하고 QR은 VisionKit, 햅틱은 `sensoryFeedback`
- 날짜: 2026-11-24
- 상태: 확정
- 맥락: TODO 1단계. `docs/tech-stack.md` 후보 가운데 둘 중 하나로 남은 줄과 나머지 줄을 확정한다.
- 결정: SwiftUI, Observation, `NavigationStack`+`TabView`, `URLSession`+`Codable`, Keychain(`Security`), `UserDefaults`, String Catalog, APNs 직접, Swift Testing·XCUITest, swift-format(Xcode 동봉)은 후보대로. QR은 VisionKit `DataScannerViewController`, 햅틱은 SwiftUI `sensoryFeedback`. 외부 패키지는 쓰지 않는다. 차트는 C-a 스파이크 뒤 정한다.
- 근거: QR은 `DataScannerViewController`가 카메라 세션·권한 화면·인식 영역을 맡아 AVFoundation 직접 구현보다 코드가 적고, iOS 16+·A12+라 iOS 18 대상(IOS-004)과 iPhone 14 Pro에서 된다. `sensoryFeedback`은 iOS 17+ SwiftUI 수정자라 UIKit 생성기를 감쌀 필요가 없다.
- 영향: 시뮬레이터에는 카메라가 없어 QR은 실기기에서만 시험하고, 시뮬레이터에서는 붙여넣기로 B-b를 시험한다. `DataScannerViewController.isSupported`가 false면 붙여넣기만 보인다.

## IOS-007: 응답 모델은 손으로 쓴 `Codable`이고 계약 예시는 원본 zod 스키마로 검증한다
- 날짜: 2026-11-24
- 상태: 확정
- 맥락: TODO 3단계 응답 모델(D-142). 계약 `schemas/*.json`과 맞춘 모델과, 저장한 dev 서버 응답이 모델로 디코딩되고 스키마도 통과하는지 보는 계약 테스트가 필요하다.
- 선택지: 모델 (a) 손으로 쓴 `Codable` (b) quicktype 등 생성 도구. 스키마 검증 (a) futureETP의 원본 zod 스키마를 Node로 실행 (b) Swift JSON Schema 패키지를 테스트 타깃에 추가 (c) ajv(futureETP에는 draft 2020-12를 못 읽는 6.x만 있음)
- 결정: 모델은 (a). `Core/Sources/API/Models/`에 계약 이름별 파일로 두고, enum 문자열은 Swift enum, `date-time`은 `Date`(`JSONDecoder.api()`, `Z` UTC만), `date`는 `LocalDate`, `YYYY-MM`은 `ContractMonth`로 받는다. 검증은 (a). `scripts/capture-fixtures.sh`가 dev 서버 응답 봉투를 `Core/Tests/Fixtures/<스키마>[.<변형>].json`으로 저장하고, `scripts/validate-fixtures.mjs`(check.sh)가 원본 zod로, `ContractFixtureTests`가 `APIClient` 디코딩으로 같은 파일을 본다.
- 근거: 스키마가 17개로 적고 생성 도구는 이름·enum·날짜 타입을 다시 손봐야 한다. JSON Schema는 zod에서 생성되므로 zod로 검증하면 같은 규칙에 refine까지 함께 보고, 외부 패키지를 쓰지 않는다(IOS-006).
- 영향: check.sh가 `../futureETP_ReactNative`(`node_modules` 설치됨)와 Node를 필요로 한다(`FUTUREETP_DIR`로 위치 변경). nullable 필드는 synthesized `Decodable`이라 키가 빠져도 nil로 받는다(zod는 거절). 서버는 항상 키를 보내므로 런타임 디코딩은 이대로 두고, 키 누락은 예시 검증이 잡는다. 계약에 정수 범위(`minimum` 등)가 있으면 `init(from:)`에서 확인한다.

## IOS-008: 차트는 SwiftUI `Canvas`로 직접 그린다
- 날짜: 2026-11-24
- 상태: 확정
- 맥락: TODO 4단계 C-a 스파이크. C-a는 봉 756개(이전 3년을 이어 받으면 3,000개 이상)에 이평선·rare-level 밴드 6개를 겹치고, 핀치·드래그마다 보이는 봉으로 log y축을 다시 맞춘다(D-056, D-087, D-106). 60fps 이상이 기준이다.
- 선택지: (a) SwiftUI `Canvas`에 `Path`로 직접 그리기 (b) Swift Charts(`RectangleMark`·`RuleMark`·`LineMark`, x·y 도메인을 보이는 범위로)
- 결정: (a). 보이는 범위는 소수 봉 순번 `CandleViewport`, y는 `PriceScale`(log, 위·아래 6% 여백), 선은 `LineSample`(1pt에 점 하나 이하)로 RN `fitTransform.ts`·`lineSampling.ts`와 같은 규칙을 순수 타입으로 둔다. 위치는 `Features/Commodity/Sources/Chart`(C-a·C-c가 같은 feature라 Core에 두지 않는다).
- 근거: 같은 가짜 봉·같은 4초 자동 시나리오(1년 범위로 끝→처음 이동 뒤 20봉→전체 축소)를 iPhone 18 Pro 시뮬레이터(60Hz, Debug-Dev)에서 잰 결과, Canvas는 756봉 60.0fps(최악 16.7ms, 끊김 0)·3,024봉 59.5fps(최악 33.5ms, 끊김 2), Swift Charts는 보이는 봉만 넘겨도 756봉 23.0fps(최악 161ms)·3,024봉 18.9fps(최악 261ms)였다. Swift Charts는 프레임마다 마크 수천 개를 다시 만들어 목표에 한참 못 미친다. Canvas는 색별로 `Path` 하나에 모아 4~11번만 그린다.
- 영향: 축·라벨·십자선·롤 음영도 직접 그린다(RN도 라이브러리 축을 끄고 레이어로 그렸다). ProMotion 120Hz를 위해 Info.plist에 `CADisableMinimumFrameDurationOnPhone`을 켰다. 실기기(iPhone 14 Pro, 120Hz)와 Release 빌드 측정은 남았다(TODO). 스파이크 화면(`ChartSpikeView`, dev 빌드 실행 인자 `-chartSpike`)과 비교용 `SwiftChartsCandleChart`는 C-a 화면을 만들 때 지운다.

## IOS-009: B 맨 아래 줄은 `iOS <변형>: 앱 버전 (빌드 번호)`를 쓴다
- 날짜: 2026-11-24, 2026-11-25 갱신(futureETP D-141 줄 머리 클라이언트·변형)
- 상태: 확정
- 맥락: RN B 맨 아래 줄은 OTA(EAS Update)를 받았는지와 런타임 fingerprint로 새 빌드가 필요한지를 보이고, 줄 머리에 클라이언트와 변형(`RN prod`·`RN dev`)을 써서 같은 앱 ID를 쓰는 형제 앱 중 무엇이 떠 있는지 보인다(screens.md B). iOS 앱은 OTA가 없고 재설치로만 바뀐다(`docs/tech-stack.md`).
- 결정: `settings.appVersion`(`iOS {{variant}}: {{version}} (빌드 {{build}})`, en `(build …)`)에 변형 `dev`·`prod`, `CFBundleShortVersionString`, `CFBundleVersion`을 넣는다(`AppBundleText`, 예: `iOS prod: 1.0.0 (빌드 1)`). RN 문구는 머리에 `RN`이 박혀 있어 쓰지 못하므로 iOS 전용 문구를 `scripts/ios-strings.json`에 두고 `scripts/gen-strings.mjs`가 RN 리소스와 합친다(RN 키와 겹치면 실패).
- 근거: 어느 앱·변형·빌드가 깔렸는지 기기에서 바로 보려는 목적은 같고, Flutter(`Flutter prod: 1.0.0 (빌드 1)`)와 같은 모양이다. iOS 전용 문구는 이 한 줄뿐이라 나머지 문구가 RN 리소스를 그대로 따르는 규칙(D-033)은 유지된다.
- 영향: `MARKETING_VERSION`은 `Config/Base.xcconfig`에서 손으로 올린다. 기기 설치 빌드의 빌드 번호는 커밋 수다(IOS-010). iOS 전용 문구가 늘면 `scripts/ios-strings.json`에 넣는다.

## IOS-010: prod 앱은 Mac에서 Personal Team으로 직접 설치하고, 업데이트도 재설치로 한다
- 날짜: 2026-11-25
- 상태: 확정
- 맥락: 스토어에 배포하지 않는 개인용 앱이고(D-011), Apple Developer 가입 전이라 TestFlight를 쓸 수 없다. 무료 서명은 7일 뒤 만료된다. RN은 EAS Update로 OTA를 받지만 네이티브 Swift 앱에는 같은 수단이 없다.
- 결정: `scripts/install-prod.sh <기기>...`로 HEAD를 Release 빌드해 `devicectl`로 설치한다. 업데이트·만료 대응 모두 같은 재설치다. 빌드 번호는 커밋 수(`git rev-list --count HEAD`)를 명령줄로 넣고, 앱 경로에 커밋 안 한 변경이 있으면 멈춘다. 절차는 `docs/ops.md`.
- 근거: RN `ios:prod-install`과 같은 흐름이라 기기 등록·신뢰 안내가 그대로 통한다. 커밋 수 빌드 번호로 B 맨 아래 줄(IOS-009)만 보고 깔린 커밋을 안다. iOS 프로젝트는 prebuild가 없어 임시 worktree 없이 작업 트리에서 빌드해도 dev 설정을 건드리지 않는다.
- 영향: Apple 가입 뒤 TestFlight로 바꿀지는 그때 다시 본다. `MARKETING_VERSION`은 손으로 올린다.
