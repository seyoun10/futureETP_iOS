# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Swift/SwiftUI로 만드는 futureETP 앱(iOS). 기능·화면·동작은 RN 앱(`../futureETP/apps/mobile`)과 똑같이 맞춘다. 사용자 본인 1명이 쓰는 개인용 앱이고 스토어에 배포하지 않는다(D-011).

- 서버는 만들지 않는다. `../futureETP/apps/server`(prod VM, dev는 로컬 Mac)를 함께 쓴다
- 제품·화면·API 계약의 원본은 `../futureETP`다. 이 저장소는 Swift/SwiftUI 구현과 그 결정만 갖는다 (D-141, IOS-001)
- 앱 ID는 RN과 같은 `io.github.seyoon.futureetp`(dev `.dev`)라 한 기기에 RN 앱과 함께 설치할 수 없다 (IOS-002)
- 진행 단계와 남은 항목은 `TODO.md`. RN 따라잡기는 `TODO.md` "원본 변경 반영" 절의 항목과 "마지막 대조" 커밋 이후 RN 커밋으로 한다

## 공통 문서 (원본, 읽기만)

작업 전 관련 문서만 골라 읽는다. 원본 문서를 고쳐야 하면 이 저장소가 아니라 `../futureETP`에서 고치도록 사용자에게 제안한다.

| 무엇 | 경로 |
|---|---|
| 서비스 기획·용어·계산 정의·사용자 흐름 | `../futureETP/docs/product.md` |
| 화면 와이어프레임과 화면별 세부 동작 | `../futureETP/docs/wireframes/screens.md` |
| API 규약(요청 헤더·응답 봉투·에러 코드·값 형식·freshness·AppError·엔드포인트) | `../futureETP/docs/architecture.md`의 "API 통신 및 에러 처리 규약" 절 |
| 다른 클라이언트 규칙(계약 공유·앱 ID·`appVersion` 접두사) | `../futureETP/docs/architecture.md`의 "다른 클라이언트" 절 |
| API 계약(엔드포인트·헤더·에러 코드, 응답·본문·쿼리 JSON Schema) | `../futureETP/packages/shared/contract/api.json`, `schemas/*.json` (D-142, 생성 파일) |
| 응답 필드 정의 원본(zod, refine 규칙·주석은 여기만) | `../futureETP/packages/shared/src/*.ts` |
| 결정 기록 D-xxx(2천 줄, 통째로 읽지 않음) | `../futureETP/docs/decisions.md`. `grep -n '^## D-' ../futureETP/docs/decisions.md`로 목록을 본 뒤 필요한 항목만 |
| RN 구현(동작이 문서로 모호할 때 참고) | `../futureETP/apps/mobile/src/` |
| 운영(서버 주소·접근 키 생성·dev 서버 실행) | `../futureETP/docs/ops.md`, `../futureETP/.claude/rules/server.md`의 명령 |

## 이 저장소 문서

결정이 바뀌면 해당 문서도 함께 갱신한다.

- `TODO.md`: 단계별 남은 항목. 끝난 블록은 `docs/history.md`(필요해지면 만든다)로 옮긴다
- `docs/tech-stack.md`: 스택 후보와 확정 결과(버전·출처 날짜)
- `docs/architecture.md`: 디렉터리 구조, 레이어, RN 구조 대응, D-번호 적용표
- `docs/decisions.md`: 이 저장소 결정 IOS-xxx. D-xxx(공통)와 번호가 겹치지 않는다

## Domain Context

용어 정의 전체는 `../futureETP/docs/product.md`의 "용어"·"계산 정의".

- CME 원자재 선물 데이터를 보는 앱. 모든 계산은 서버가 CME 공식 정산가(settlement) 기준으로 하고, 날짜는 CME 거래일(미국 중부 17시에 바뀜)로 센다
- 화면: A 원자재 목록 → C 원자재 화면의 하단 탭 C-a 이격도차트 / C-c 월물차트 / C-b 월물커브 / C-d ETP(D-111), 탭 밖 C-d-a ETP 상세. B 설정(B-a 알림 설정, B-b 접근 키). rare 레벨 도달 푸시 알림
- 장 상태는 장중/휴장/정산 대기(`OPEN`·`CLOSED`·`SETTLEMENT_PENDING`, D-022)

## Architecture 규칙

상세는 `docs/architecture.md`, 스택은 `docs/tech-stack.md`.

- 언어: Swift 6(strict concurrency)
- 레이어(MVVM + repository, IOS-005): SwiftUI View → `@Observable` 화면 Model(ViewModel, `<Screen>Model`) → repository(protocol, 조회·캐시) → API client. UseCase·Entity 계층은 두지 않는다. 화면에서 HTTP를 직접 부르지 않는다 (D-041 대응)
- 앱은 계산하지 않는다. 서버 값을 표시만 한다(포맷·반올림 표시는 예외)
- API
  - 기본 경로 `<서버>/v1`. `/v1/health` 밖 모든 요청에 `Authorization: Bearer <접근 키>`와 `X-Device-Id: <installation ID>` (D-036, D-120)
  - 응답은 항상 `{ success: true, data } | { success: false, error: { code, message } }`. 봉투와 `data`를 모델로 디코딩하고 실패는 `SCHEMA_MISMATCH` (D-042)
  - 모든 실패는 `AppError`(서버 코드 `UNAUTHORIZED`·`RATE_LIMITED`·`VALIDATION_FAILED`·`NOT_FOUND`·`INTERNAL` + 앱 코드 `NETWORK`·`TIMEOUT`·`SCHEMA_MISMATCH`). 타임아웃 15초, 재시도는 `NETWORK`·`TIMEOUT`·`INTERNAL`만 최대 2회, 변경 요청은 자동 재시도 없음 (D-072)
  - `UNAUTHORIZED`면 어느 화면에서든 B-b로 보내고 거절 줄을 보인다 (D-079)
  - 응답 모델은 `../futureETP/packages/shared/contract/schemas/*.json`과 필드·nullable·enum 값을 맞춘다. 모델 생성 도구를 쓰면 이 파일을 입력으로 한다 (D-142)
- 접근 키·installation ID는 Keychain(`Security` 프레임워크, 작은 래퍼 하나)에만 둔다. 앱 번들·저장소에 넣지 않는다. 예외는 dev 변형의 `DEV_API_TOKEN`뿐 (D-043, D-044)
- dev 서버 주소·`DEV_API_TOKEN`은 `Config/Secrets.xcconfig`(커밋 안 함, `Secrets.example.xcconfig`만 커밋) → Info.plist 값으로 넣고, dev configuration에서만 읽는다
- 프로젝트는 Tuist(`Project.swift`, 버전은 `mise.toml`)로 생성하고 생성물은 커밋하지 않는다. 타깃 App → features → Core 의존성으로 import 방향을 강제한다 (IOS-003)
- 변형: Tuist configuration `Debug-Dev`·`Release` + xcconfig. dev는 bundle ID `.dev` (D-043, D-052 대응)
- 사용자에게 보이는 문구는 i18n 리소스로만 쓴다(ko 기준, en). String Catalog(`Localizable.xcstrings`, ko 기준·en). 권한 문구는 `InfoPlist.xcstrings` (D-033, D-073)
- 시세 숫자·월물 표기(`2,405.1`·`+0.51%`·`DEC26`)는 언어와 상관없이 RN `../futureETP/apps/mobile/src/lib/formatNumber.ts` 규칙과 같게 만든다
- 다크 전용 테마 토큰, 차트 색은 토큰에서, 등락 색은 표시 설정에서 읽는다 (D-031, D-073)
- `PUT /v1/devices`의 `appVersion`은 `ios-<버전>`으로 보낸다 (IOS-002)
- 푸시: APNs 기기 토큰(Apple 가입 뒤). 가입 전에는 토큰 조회가 실패하므로 `PUT /v1/devices`를 부르지 않는다(RN과 같은 규칙) (D-037)

## Conventions

- commit message: Conventional Commits(`feat:`, `fix:`, `chore:`, `docs:`). 관련 결정 번호를 끝에 `(D-xxx)`·`(IOS-xxx)`로 붙인다
- 커밋 전 검사 명령(아래 Commands의 check) 통과. 스캐폴딩 전에는 문서만이라 생략
- `fix:` 커밋은 회귀 테스트를 함께 넣는다. 시각 조정만 예외로 기기 확인으로 대신한다
- 이름: 타입 `UpperCamelCase`, 멤버 `lowerCamelCase`, 파일 이름 = 주 타입 이름. Swift API Design Guidelines를 따른다
- 테스트: Swift Testing(`@Test`), UI는 XCUITest
- 화면 전용 코드는 해당 feature 안에 두고, 두 곳 이상에서 쓰면 공용 계층으로 옮긴다

## Commands

스캐폴딩(TODO 2단계) 전이라 예정 명령이다. 프로젝트를 만든 뒤 실제 명령으로 고친다.

- `tuist generate`: 프로젝트 생성(빌드·테스트 전 먼저)
- `xcodebuild -scheme FutureETP-Dev -destination 'platform=iOS Simulator,name=<기기>' build`: dev 변형 빌드
- `xcodebuild test -scheme FutureETP-Dev -destination 'platform=iOS Simulator,name=<기기>'`: 전체 테스트. 단일: `-only-testing:<Target>/<Suite>/<test>`
- `swift format lint --recursive --strict .`: lint(Xcode 동봉 swift-format)
- `swift format --in-place --recursive .`: 포맷 적용
- `./scripts/check.sh`: lint → 빌드 → 테스트(스캐폴딩 때 만든다). 커밋 전 통과
- dev 서버 실행은 `../futureETP`에서 `npm run dev -w apps/server`. 에뮬레이터는 `http://10.0.2.2:<port>`, iOS 시뮬레이터는 `http://localhost:<port>`
