# Tech Stack

> Swift/SwiftUI 앱의 스택. 지금은 후보이고, TODO 1단계에서 하나씩 확정하며 이 표를 고친다.
> 결정 근거는 `decisions.md`(IOS-xxx)에 적고 여기에는 결과만 적는다. 버전은 확정할 때 웹 검색으로 최신 안정판을 확인하고 출처 날짜를 함께 적는다.
> 서버·DB·배치는 `../futureETP/docs/tech-stack.md`(공용).

상태: 후보 (2026-11-18 작성)

| 영역 | 후보 / 선택 | 메모 |
|---|---|---|
| 언어 / 툴체인 | Swift 6.4.4 · Xcode 27.2(27B52) · 시뮬레이터 런타임 iOS 27.2 (로컬 확인 2026-11-24) | 최소 배포 iOS 18 (IOS-004) |
| UI | SwiftUI |  |
| 상태 | Observation(`@Observable`) + 화면별 Model, 앱 전역 `AppSettings` | RN의 TanStack Query 캐시(staleTime·자동 새로고침)는 작은 조회 캐시 계층으로 직접 만든다 |
| 내비게이션 | `NavigationStack` + `TabView`(C 하단 탭) | A → C 스택, 탭 밖 C-d-a |
| HTTP / JSON | `URLSession` async/await + `Codable` | 의존성 없음. 타임아웃 15초·취소는 Task 취소로 |
| 차트 | SwiftUI `Canvas` 직접 구현(후보), Swift Charts 검토 | C-a 봉 756~3,000개 + 핀치·드래그·십자선. 스파이크로 정한다 |
| 보안 저장소 | Keychain | 접근 키(D-044)·installation ID |
| 기기 설정 저장 | `UserDefaults`(`@AppStorage`) | 언어·등락 색(D-073) |
| QR | AVFoundation(`AVCaptureMetadataOutput`) 또는 VisionKit `DataScannerViewController` | B-b(D-078) |
| i18n | String Catalog | 앱 안 언어 설정(D-073)이 기기 언어와 다를 수 있어 `Locale`을 환경으로 주입 |
| 푸시 | APNs 직접(`UNUserNotificationCenter`, 기기 토큰) | Apple 가입 뒤 |
| 햅틱 | `sensoryFeedback` / UIKit FeedbackGenerator | D-109·D-138·D-139 |
| 테스트 / lint | Swift Testing · XCUITest / swift-format |  |
| 외부 패키지 | 원칙적으로 없음(SPM으로 꼭 필요할 때만) |  |

## RN 스택과의 대응

| RN(`../futureETP`) | 이 앱 |
|---|---|
| TanStack Query(서버 상태·캐시·자동 새로고침) | 상태 계층 + repository 캐시 |
| Zustand persist(언어·등락 색) | 기기 설정 저장 |
| Victory Native XL + Skia | 위 "차트" |
| expo-secure-store | 위 "보안 저장소" |
| expo-camera | 위 "QR" |
| i18next | 위 "i18n" |
| EAS Update(OTA) | 없음(재설치) |
