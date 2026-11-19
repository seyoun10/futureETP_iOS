# TODO

목표: Swift/SwiftUI로 RN 앱(`../futureETP/apps/mobile`)과 같은 기능의 앱 만들기(iOS, 개인용, D-011)
지침: 남은 항목만 둔다. 최상위 항목이 하위 항목까지 모두 끝나면 블록째 `docs/history.md`의 같은 절 끝으로 옮긴다. 새 단계·항목은 여기에 추가한다
원본 변경 따라가기: `../futureETP`에서 API·shared 스키마·화면 동작이 바뀌면 그쪽에서 이 파일의 "원본 변경 반영"에 항목을 적는다

## 원본 변경 반영
- [ ] API 계약 JSON Schema 생성(2026-11-19, futureETP D-142): `../futureETP/packages/shared/contract/`. 3단계 응답 모델은 이 파일을 기준으로 한다(아래 3단계에 반영됨, 확인 뒤 체크)
- [ ] 레이어 import 방향 lint 강제(2026-11-19, futureETP D-041 변경): feature 간 import 금지, 공용 계층 → features·라우트 금지. `docs/architecture.md` "규칙"과 아래 2단계에 반영됨, 확인 뒤 체크
- [ ] 첫 로딩 가운데 스피너(2026-11-19, futureETP 527a3b2): 첫 조회 중 스켈레톤(공용 막대·차트 격자) 위 가운데에 큰 스피너를 겹친다. 차트 탭은 차트 자리 가운데. `../futureETP/docs/wireframes/screens.md` 공통 로딩 항목

## 0. 환경
- [ ] Xcode 27.2 · Swift 6.4.2 확인됨(2026-11-18). 시뮬레이터 런타임 설치 여부만 확인
- [ ] Apple Developer 가입 전에는 시뮬레이터와 개인 무료 서명(7일) 실기기만 가능. APNs는 가입 뒤 (D-039, futureETP TODO 5-10)
- [ ] 프로젝트 파일 관리: Xcode 프로젝트 직접 vs XcodeGen·Tuist 생성(사람이 아닌 Claude가 편집하기 쉬운 쪽)을 1단계에서 정한다

## 1. 스택 확정
- [ ] `docs/tech-stack.md`의 후보를 하나씩 정한다. 각 패키지·도구의 최신 안정 버전을 웹 검색으로 확인하고 출처 날짜를 적는다. 결정과 근거는 `docs/decisions.md`(IOS-003부터)
- [ ] 차트 방식은 2단계 뒤 C-a 스파이크(아래 4단계 첫 항목)로 정한다

## 2. 스캐폴딩
- [ ] 프로젝트 생성, 앱 ID `io.github.seyoon.futureetp`·dev `.dev` 두 변형, 앱 이름·아이콘(RN `apps/mobile/assets` 재사용)
- [ ] lint·format·test 설정과 검사 명령 하나(`check`), CLAUDE.md Commands를 실제 명령으로 갱신
  - import 방향 규칙(architecture.md "규칙")을 검사에 넣는다. 후보: feature·Core를 SPM 로컬 패키지 모듈로 나눠 컴파일러가 막게 하거나, 검사 스크립트
- [ ] dev 변형이 로컬 dev 서버 `GET /v1/health`를 부르는 최소 화면으로 연결 확인
- [ ] (선택) 원격 저장소·CI(GitHub Actions에서 check)

## 3. 공통 기반
- [ ] API client: 헤더(Bearer·`X-Device-Id`), 타임아웃 15초, 봉투 디코딩, `AppError`, 재시도 규칙 (D-042, D-072)
- [ ] 응답 모델: `../futureETP/packages/shared/contract/schemas/*.json`과 맞춘 모델(손으로 또는 생성 도구) + 계약 테스트(실제 dev 서버 응답을 저장한 예시를 모델로 디코딩하고, 같은 예시가 JSON Schema를 통과하는지) (D-142)
- [ ] installation ID(첫 실행 UUID) 생성·보안 저장소 보관 (D-120)
- [ ] 접근 키 B-b: 붙여넣기·QR(`futureetp-key:v1:` 접두사), `GET /v1/settings`로 확인 뒤 저장, 키 없으면 첫 화면이 B-b, `UNAUTHORIZED`면 어느 화면에서든 B-b + 거절 줄 (D-044, D-077~D-079)
- [ ] i18n ko/en, 앱 안 언어 설정을 서버 기기 설정과 맞춤 (D-033, D-073, D-137)
- [ ] 테마 토큰(다크 전용)·등락 색 설정 저장 (D-031, D-073)
- [ ] 공용 조회 UI: 기준 시각 줄(freshness)·로딩/오류/빈 상태 분기·`nextUpdateAt` + 1분 자동 새로고침·앱 복귀 재조회 (D-048, D-075)
- [ ] 앱 실행 때 시간대 PATCH (D-084), 세로 잠금·[⟲] 가로 전환 (D-076)
- [ ] 숫자·날짜 포맷(RN `formatNumber`·`formatDateTime`과 같은 결과) 단위 테스트

## 4. 화면 수직 슬라이스 (RN 순서)
- [ ] C-a 차트 스파이크: 봉 756개 + 이평선·rare-level 밴드, 핀치·드래그·십자선, 가장 과거 봉이 보이면 이전 3년 이어 받기에서 범위 유지, 60fps 이상 (D-056, D-087, D-104, D-106) → 차트 방식 결정
- [ ] A 원자재 목록: `GET /v1/commodities`, 대표월물 ●·알림 🔔·거래 없음, 당겨서 새로고침(햅틱·터치 차단·5초 시간 초과 Alert, D-138), C-a 이동·미리 조회 (D-085)
- [ ] C-a 이격도차트: `GET /v1/commodities/:code/disparity`, 기간 버튼 6개(D-102), 롤 음영, 십자선 상세, 가로 모드, 이전 3년 받기 중 화면 터치 차단·5초 시간 초과·실패 Alert (D-086, D-103, D-108, D-139)
- [ ] C-c 월물차트: `GET /v1/commodities/:code/contracts`, log y축, 끝값 라벨 (D-092, D-093, D-113, D-118)
- [ ] C-b 월물커브: `GET /v1/commodities/:code/curve?baseDate`, 기준일 OS 날짜 피커, 이전·다음 기준일, 변화율 라벨 배치, 롤 수익률 (D-090, D-091, D-114~D-123)
- [ ] C-d ETP 목록(필터·정렬은 앱에서)·C-d-a 상세 (D-017)
- [ ] B 설정·B-a 알림 설정: 낙관적 PATCH, rare-level 입력 검증, 알림 대상 없음 빨간 점 (D-081~D-083, D-124)
- [ ] 화면별 세부 동작은 `../futureETP/docs/wireframes/screens.md`와 하나씩 대조

## 5. 푸시
- [ ] APNs 기기 토큰 등록(Apple 가입 뒤), 가입 전에는 등록하지 않음
- [ ] `PUT /v1/devices`(토큰·플랫폼·`appVersion` `ios-<버전>`), 알림 탭으로 해당 C 화면 이동, 앱 사용 중 알림 표시 (D-037, D-120)

## 6. 기기 설치·운영
- [ ] prod 변형 release 빌드를 개인 기기에 설치하는 절차를 `docs/ops.md`(새로 만든다)에 기록
- [ ] RN 앱과 같은 앱 ID라 바꿔 설치할 때 할 일(기존 앱 삭제, 접근 키 다시 입력, 기기 설정 다시 맞춤) 기록
- [ ] 업데이트 배포 방식(OTA 없음, 재설치) 결정
