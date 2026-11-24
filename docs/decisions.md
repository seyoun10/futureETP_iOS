# 결정 기록 (Decision Log)

> Swift/SwiftUI 앱의 결정과 근거를 시간순으로 추가한다. 번호는 `IOS-xxx`이고 공통 결정 D-xxx(`../futureETP/docs/decisions.md`)와 겹치지 않는다.
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
- 결정: (a). 이 저장소는 `CLAUDE.md`·`TODO.md`·`docs/tech-stack.md`·`architecture.md`·`decisions.md`만 갖고, 나머지는 `../futureETP/...`를 읽는다. 두 저장소는 같은 상위 폴더(`_project/`)에 나란히 있어야 한다.
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
- 영향: 빌드·테스트 전에 `tuist generate`(또는 `tuist test`)가 필요하다. 2단계에서 CLAUDE.md Commands를 실제 명령으로 고친다. Tuist 버전을 올릴 때는 `mise.toml`만 바꾼다.
