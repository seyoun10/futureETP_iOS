# TODO

목표: Swift/SwiftUI로 RN 앱(`../futureETP/apps/mobile`)과 같은 기능의 앱 만들기(iOS, 개인용, D-011)
지침: 남은 항목만 둔다. 최상위 항목이 하위 항목까지 모두 끝나면 블록째 `docs/history.md`의 같은 절 끝으로 옮긴다. 새 단계·항목은 여기에 추가한다
원본 변경 따라가기: `../futureETP`에서 API·shared 스키마·화면 동작이 바뀌면 그쪽에서 이 파일의 "원본 변경 반영"에 항목을 적는다

## 원본 변경 반영
마지막 대조: futureETP `646af4f`(2026-11-23, 앱 코드를 쓰기 전이라 그 전 RN 앱 코드 수정은 현재 RN 코드를 보고 구현할 때 들어간다). 적힌 항목 밖에 빠진 것이 있는지는 `git -C ../futureETP log --oneline 646af4f..HEAD -- apps/mobile packages/shared`로 그 뒤 커밋만 이 저장소 구현과 맞춰 본다. 다 보면 이 줄의 커밋을 그 HEAD로 바꾼다
- [ ] 핀치 중 십자선 막기(2026-11-23, futureETP D-087 보충): 두 손가락으로 핀치하다 멈추면 길게 누르기 십자선이 켜지던 것. 핀치를 시작한 터치에서는 손가락을 댄 채 멈춰도 십자선·봉 스냅 햅틱·상세 박스를 띄우지 않고, 손을 모두 떼고 다시 길게 눌러야 나타난다(C-a·C-c 공통, futureETP `charts/useChartViewport.ts` `pinchedInTouch`). screens.md C-a 길게 누르기
- [ ] 휴장 달력 일정을 기기 로컬로(2026-11-23, futureETP D-144): 예외 일정을 시장 날짜 대신 기기 로컬 날짜 칸에 둔다. 시각 있는 일정은 `at`(시장 현지)을, CLOSED는 정규 개장 시각(CME 전날 17:00 CT, KRX 09:00 KST, NYSE 09:30 ET)을 로컬로 바꾼 날짜. 목록과 날짜 칸 점은 로컬 시각순(휴장은 정규 개장 시각, 같은 시각은 시장 순). 문구 시각은 로컬 `HH:mm`이고 시간대 표기 없음(`calendar.kinds`의 `{{tz}}`·`calendar.timeZones` 삭제). 조회 범위를 앞뒤 하루씩 넓히고 3개월 밖 연도 `missing`은 숨김. 같은 날 같은 시장 점이 둘일 수 있음. futureETP `features/calendar/localSchedule.ts`, screens.md A-a
- [ ] 휴장 달력 화면 A-a(2026-11-21, futureETP D-143): A title-bar [⚙] 왼쪽에 [📅](`calendar-month-outline`) → 이번 달~다다음 달 3개월 세로 달력, 오늘(기기 로컬)·CME/KRX/NYSE 휴장(채운 점)·조기 마감/개장 지연(빈 점)·달별 휴일 이름 목록·미입력 안내. API `GET /v1/calendar?from&to`(계약 `calendar`·`calendarQuery`), 색 `colors.market`·`today`, 문구 `calendar.*`. `../futureETP/docs/wireframes/screens.md` A-a. 캐시: 응답 `missing`이 비어 있으면 12시간, 있으면 5분 stale(화면 재진입·앱 복귀 때 다시 조회, 서버 import 뒤 재시작 없이 반영. futureETP `useMarketCalendar.ts`)
- [ ] rare 레벨 입력 규칙 강화(2026-11-21, futureETP 품질 검증 B2/D1·D3): rare 레벨은 소수 첫째 자리로 반올림한 값으로 중복을 본다(1과 1.00000000001은 중복). C-a `levels` query는 `^d+(.d+)?(,d+(.d+)?)*$`만 받는다(공백·`0x8`·`1e1` 거절, 계약 `disparityQuery`). 앱 입력 검증이 같은 규칙인지, 직렬화가 숫자 기본 문자열(`1`, `2.5`)인지 확인. 모델 `RareLevels`(반올림 뒤 중복·범위·소수 첫째 자리)와 `levels` 직렬화는 반영(2026-11-24), B-a 입력 UI가 이 타입을 쓰는지 남음
- [ ] 첫 로딩 가운데 스피너(2026-11-19, futureETP 527a3b2): 첫 조회 중 스켈레톤(공용 막대·차트 격자) 위 가운데에 큰 스피너를 겹친다. 공용 막대 스켈레톤은 반영(`LoadingView`, 2026-11-24). 차트 탭은 차트 자리 가운데이고, 데이터가 온 뒤 첫 기간 맞춤 전(차트를 감춘 동안)에도 띄운다(e94b2c2). `../futureETP/docs/wireframes/screens.md` 공통 로딩 항목
- [ ] 차트 데이터가 바뀌면 십자선·상세 박스 지우기(2026-11-21, futureETP E1 수정): C-a·C-c에서 이전 3년을 앞에 붙이거나 자동 새로고침으로 데이터 배열이 바뀌면 십자선과 상세 박스를 지운다(옛 순번으로 다른 봉을 가리키지 않게). `../futureETP/docs/wireframes/screens.md` C-a 길게 누르기

## 0. 환경
- [ ] Apple Developer 가입 전에는 시뮬레이터와 개인 무료 서명(7일) 실기기만 가능. APNs는 가입 뒤 (D-039, futureETP TODO 5-10)

## 1. 스택 확정
- [x] 차트는 SwiftUI `Canvas` 직접 구현 (IOS-008, 2026-11-24)

## 2. 스캐폴딩
- [ ] (선택) 원격 저장소·CI(GitHub Actions에서 check)

## 3. 공통 기반
- [ ] import redundant 검사 켜기: App이 `Commodity`·`Settings`·`Core`를 import한 뒤 `scripts/check.sh`의 `--only implicit`을 지운다 (IOS-003 보충)
- [ ] 접근 키 B-b: 붙여넣기·QR(`futureetp-key:v1:` 접두사), `GET /v1/settings`로 확인 뒤 저장, 키 없으면 첫 화면이 B-b, `UNAUTHORIZED`면 어느 화면에서든 B-b + 거절 줄 (D-044, D-077~D-079)
  - 코드 완료(a4da4d4~ba01dfd). 시뮬레이터에서 dev 서버 키 붙여넣기·Keychain 저장·재실행 유지 확인(2026-11-24). 남은 확인: 키 교체 뒤 거절 시 B-b 이동, 실기기 QR 스캔. 확인되면 이 항목을 `docs/history.md`로 옮긴다
- [ ] i18n ko/en, 앱 안 언어 설정을 서버 기기 설정과 맞춤 (D-033, D-073, D-137)
  - 문구 카탈로그는 RN 리소스에서 생성(`scripts/gen-strings.mjs`), `{{name}}` 자리 표시자 helper `L10n`, 앱 언어를 루트 `\.locale`로 주입(`DisplaySettings.locale`, 언어만 바꾸고 기기 지역 유지, 시뮬레이터에서 ko/en 전환 확인) (2026-11-24). 남음: B 설정의 언어 선택 UI(4단계 B)
  - 서버 기기 설정과 맞춤은 `DeviceSettingsSync`로 완료(2026-11-24, D-137)
- [ ] 공용 조회 UI: 기준 시각 줄(freshness)·로딩/오류/빈 상태 분기·`nextUpdateAt` + 1분 자동 새로고침·앱 복귀 재조회·접근 키 저장 뒤 전체 재조회(`AccessKeyView` `onSaved`, 기다리지 않음) (D-048, D-075, D-044)
  - View 완료(2026-11-24): `FooterLine`·`FreshnessLine`(`FooterTime`)·`QueryStateView`(`QueryState.phase`)·`LoadingView`·`CenterSpinner`·`ErrorView`
  - 조회 캐시 완료(2026-11-24): `QueryCache`(키 접두사 무효화·`keepFor` 5분/차트 1시간)·`Query`(진행 중 조회 합류·`StalePolicy.untilNextUpdate`)·`.queryLifecycle`(진입·앱 복귀 재조회·`nextUpdateAt` + 1분 자동 새로고침)·키 저장 뒤 전체 무효화. 남음: 무한 조회(`before`, C-a·C-c에서), 기준 시각 줄을 홈 인디케이터 여백에 겹치는 배치(A는 `safeAreaInset`으로 목록 아래에 둠, 시뮬레이터 확인)
- [ ] 앱 실행 때 시간대 PATCH (D-084), 세로 잠금·[⟲] 가로 전환 (D-076)
  - 시간대·언어 PATCH 코드 완료(2026-11-24): `SettingsStore`(설정 조회·낙관적 PATCH 줄 세우기)·`.deviceSettingsSync`(루트, 키 있을 때). 남음: dev 서버에서 기기 시간대·언어 바꿔 PATCH 확인
  - 세로 잠금 기반 완료(2026-11-24): `OrientationLock`(시작 세로, `lockPortrait`·`lockLandscape`·[⟲]용 `toggle(isLandscape:)`, `AppDelegate`가 허용 방향 반환)·`\.isLandscape`(창 모양, 루트 `providesIsLandscape`). 남음(C 화면에서): C title-bar [⟲](ETP 탭 밖에서만), ETP 탭 진입·C를 떠날 때 `lockPortrait`, 가로 title-bar·tab-bar 높이, 시뮬레이터 회전 확인

## 4. 화면 수직 슬라이스 (RN 순서)
- [ ] C-a 차트 스파이크: 봉 756개 + 이평선·rare-level 밴드, 핀치·드래그·십자선, 가장 과거 봉이 보이면 이전 3년 이어 받기에서 범위 유지, 60fps 이상 (D-056, D-087, D-104, D-106) → 차트 방식 결정
  - 1단계 렌더링 완료(2026-11-24): `CandleViewport`·`PriceScale`·`LineSample`·`CanvasCandleChart`, 측정 화면 `ChartSpikeView`(dev, `-chartSpike`). Canvas로 결정(IOS-008)
  - 2단계 제스처 완료(2026-11-24): `ChartInteraction`(십자선 유지·탭으로 지우기·십자선이 있으면 끌기가 십자선을 옮김·핀치한 터치에서 십자선 막기·핀치 가운데 따라가기), `ChartGestureSurface`(UIKit 인식기: 길게 누르기 0.3초·탭·한 손가락 끌기·핀치), `DetailCorner`(상세 박스 귀퉁이), 봉 스냅 햅틱(`sensoryFeedback(.selection)`). 시뮬레이터에서 동작 확인
  - 3단계 과거 봉 붙이기 완료(2026-11-24): `CandleViewport.rebased`·`showsFirstBar`, `ChartInteraction.dataChanged(barCount:prepended:)`(보던 범위 유지·십자선 지우기·핀치 중이면 시작 범위도 옮김). 스파이크는 가장 과거 봉이 보이면 0.5초 뒤 756봉을 앞에 붙인다(3,024봉까지). C-a 화면은 RN `prependedBars`처럼 첫 날짜가 앞당겨지고 마지막 날짜가 같을 때만 앞에 붙은 봉으로 센다
  - 남음: 실기기 120Hz·Release 측정(십자선을 끄는 동안 상세 박스 다시 그리기 비용 포함. 시뮬레이터 짧은 끌기에서 43~54fps) / C-a 화면에서 십자선 날짜·가격 라벨(축 레이어와 함께)
- [ ] A 원자재 목록: `GET /v1/commodities`, 대표월물 ●·알림 🔔·거래 없음, 당겨서 새로고침(햅틱·터치 차단·5초 시간 초과 Alert, D-138), C-a 이동·미리 조회 (D-085)
  - 완료(2026-11-24): `CommoditiesRepository`·`QueryCache.commodityList`, `CommodityListView`(행·등락 색·●·🔔·거래 없음·기준 시각 줄·[⚙] 알림 꺼짐 점), `PullRefresh`(5초 시간 초과·실패 Alert, 늦은 조회는 그대로 반영), C·B 이동. 시뮬레이터에서 dev 서버 목록 표시 확인
  - 남음: [📅](A-a에서), 행 누를 때 C-a 미리 조회(C-a에서), 새로고침 중 터치 차단은 헤더 버튼 `disabled`라 RN처럼 화면 전체를 덮지는 않음(기기에서 느린 응답으로 확인)
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
