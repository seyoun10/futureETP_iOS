# History

TODO.md에서 끝난 항목을 같은 절 이름 아래로 옮겨 둔다.

## 원본 변경 반영
- [x] 레이어 import 방향 lint 강제(2026-11-19, futureETP D-041 변경): `tuist inspect dependencies --only implicit`를 `scripts/check.sh`에 넣음(2026-11-24, IOS-003 보충)

## 0. 환경
- [x] Xcode 27.2(27B52) · Swift 6.4.4 · 시뮬레이터 런타임 iOS 27.2 확인(2026-11-24)
- [x] 프로젝트 파일 관리: Tuist 4.218.4 + mise 고정 (IOS-003)

## 1. 스택 확정
- [x] `docs/tech-stack.md`의 후보를 하나씩 정한다. 각 패키지·도구의 최신 안정 버전을 웹 검색으로 확인하고 출처 날짜를 적는다. 결정과 근거는 `docs/decisions.md`(IOS-003부터)

## 2. 스캐폴딩
- [x] `brew install mise` → `mise install`(Tuist), `Project.swift`로 프로젝트 생성, 앱 ID `io.github.seyoon.futureetp`·dev `.dev` 두 변형(scheme `FutureETP-Dev`·`FutureETP`), 앱 이름(`futureETP`·`futureETP Dev`)·아이콘(RN `icon.png`를 검정 배경으로 알파 제거)(2026-11-24)
- [x] lint·format·test 설정과 검사 명령 `scripts/check.sh`(lint → generate → `tuist inspect dependencies --only implicit` → Release 빌드 → Debug-Dev 테스트), `.swift-format` 기본값·2칸, CLAUDE.md Commands 갱신(2026-11-24)

