# TODO

목표: Swift/SwiftUI로 RN 앱(`../futureETP_ReactNative/apps/mobile`)과 같은 기능의 앱 만들기(iOS, 개인용, D-011)
지침: 남은 항목만 둔다. 최상위 항목이 하위 항목까지 모두 끝나면 블록째 `docs/history.md`의 같은 절 끝으로 옮긴다. 새 단계·항목은 여기에 추가한다
원본 변경 따라가기: `../futureETP_ReactNative`에서 API·shared 스키마·화면 동작이 바뀌면 그쪽에서 이 파일의 "원본 변경 반영"에 항목을 적는다

## 원본 변경 반영
마지막 대조: futureETP `271b148`(2026-11-25, 앱 코드를 쓰기 전이라 그 전 RN 앱 코드 수정은 현재 RN 코드를 보고 구현할 때 들어간다). 적힌 항목 밖에 빠진 것이 있는지는 `git -C ../futureETP_ReactNative log --oneline 17a2dfa..HEAD -- apps/mobile packages/shared`로 그 뒤 커밋만 이 저장소 구현과 맞춰 본다. 다 보면 이 줄의 커밋을 그 HEAD로 바꾼다

## 0. 환경
- [ ] Apple Developer 가입 전에는 시뮬레이터와 개인 무료 서명(7일) 실기기만 가능. APNs는 가입 뒤 (D-039, futureETP TODO 5-10)

## 1. 스택 확정
- [x] 차트는 SwiftUI `Canvas` 직접 구현 (IOS-008, 2026-11-24)

## 2. 스캐폴딩
- [ ] (선택) 원격 저장소·CI(GitHub Actions에서 check): `.github/workflows/check.yml`(러너 `xcode-27`, Xcode 27.2, futureETP main을 함께 받아 `FUTUREETP_DIR`로 넘김) 작성(2026-11-24). 첫 실행 통과 확인이 남음

## 3. 공통 기반
- [ ] import redundant 검사 켜기: App이 `Commodity`·`Settings`·`Core`를 import한 뒤 `scripts/check.sh`의 `--only implicit`을 지운다 (IOS-003 보충)
- [ ] 접근 키 B-b: 붙여넣기·QR(`futureetp-key:v1:` 접두사), `GET /v1/settings`로 확인 뒤 저장, 키 없으면 첫 화면이 B-b, `UNAUTHORIZED`면 어느 화면에서든 B-b + 거절 줄 (D-044, D-077~D-079)
  - 코드 완료(a4da4d4~ba01dfd). 시뮬레이터에서 dev 서버 키 붙여넣기·Keychain 저장·재실행 유지 확인(2026-11-24). 남은 확인: 키 교체 뒤 거절 시 B-b 이동, 실기기 QR 스캔. 확인되면 이 항목을 `docs/history.md`로 옮긴다
- [ ] 공용 조회 UI: 기준 시각 줄(freshness)·로딩/오류/빈 상태 분기·`nextUpdateAt` + 1분 자동 새로고침·앱 복귀 재조회·접근 키 저장 뒤 전체 재조회(`AccessKeyView` `onSaved`, 기다리지 않음) (D-048, D-075, D-044)
  - View 완료(2026-11-24): `FooterLine`·`FreshnessLine`(`FooterTime`)·`QueryStateView`(`QueryState.phase`)·`LoadingView`·`CenterSpinner`·`ErrorView`
  - 조회 캐시 완료(2026-11-24): `QueryCache`(키 접두사 무효화·`keepFor` 5분/차트 1시간)·`Query`(진행 중 조회 합류·`StalePolicy.untilNextUpdate`)·`.queryLifecycle`(진입·앱 복귀 재조회·`nextUpdateAt` + 1분 자동 새로고침)·키 저장 뒤 전체 무효화. 무한 조회는 `ChartPages`·`PagedQuery`(`QueryCache.pagedQuery`, 받은 페이지 수만큼 다시 조회·`fetchOlder` 실패는 Alert용으로 돌려줌·늦은 응답도 붙음, 2026-11-24). 남음: 기준 시각 줄을 홈 인디케이터 여백에 겹치는 배치(A는 `safeAreaInset`으로 목록 아래에 둠, 시뮬레이터 확인)
- [ ] 앱 실행 때 시간대 PATCH (D-084), 세로 잠금·[⟲] 가로 전환 (D-076)
  - 시간대·언어 PATCH 코드 완료(2026-11-24): `SettingsStore`(설정 조회·낙관적 PATCH 줄 세우기)·`.deviceSettingsSync`(루트, 키 있을 때). 남음: dev 서버에서 기기 시간대·언어 바꿔 PATCH 확인
  - 세로 잠금 기반 완료(2026-11-24): `OrientationLock`(시작 세로, `lockPortrait`·`lockLandscape`·[⟲]용 `toggle(isLandscape:)`, `AppDelegate`가 허용 방향 반환)·`\.isLandscape`(창 모양, 루트 `providesIsLandscape`)
  - C [⟲] 완료(2026-11-24): ETP 탭 밖에서만 보임, ETP 탭 진입·C를 떠날 때 `lockPortrait`, 가로에서 tab-bar·기준 시각 줄 숨김. 시뮬레이터에서 가로 전환·가로에서 [←]로 A 세로 복귀 확인. 남음: 실기기 확인

## 4. 화면 수직 슬라이스 (RN 순서)
- [ ] C-a 차트 스파이크: 봉 756개 + 이평선·rare-level 밴드, 핀치·드래그·십자선, 가장 과거 봉이 보이면 이전 3년 이어 받기에서 범위 유지, 60fps 이상 (D-056, D-087, D-104, D-106) → 차트 방식 결정
  - 1단계 렌더링 완료(2026-11-24): `CandleViewport`·`PriceScale`·`LineSample`·`CanvasCandleChart`, 측정 화면 `ChartSpikeView`(dev, `-chartSpike`). Canvas로 결정(IOS-008)
  - 2단계 제스처 완료(2026-11-24): `ChartInteraction`(십자선 유지·탭으로 지우기·십자선이 있으면 끌기가 십자선을 옮김·핀치한 터치에서 십자선 막기·핀치 가운데 따라가기), `ChartGestureSurface`(UIKit 인식기: 길게 누르기 0.3초·탭·한 손가락 끌기·핀치), `DetailCorner`(상세 박스 귀퉁이), 봉 스냅 햅틱(`sensoryFeedback(.selection)`). 시뮬레이터에서 동작 확인
  - 3단계 과거 봉 붙이기 완료(2026-11-24): `CandleViewport.rebased`·`showsFirstBar`, `ChartInteraction.dataChanged(barCount:prepended:)`(보던 범위 유지·십자선 지우기·핀치 중이면 시작 범위도 옮김). 스파이크는 가장 과거 봉이 보이면 0.5초 뒤 756봉을 앞에 붙인다(3,024봉까지). C-a 화면은 RN `prependedBars`처럼 첫 날짜가 앞당겨지고 마지막 날짜가 같을 때만 앞에 붙은 봉으로 센다
  - 남음: 실기기 120Hz·Release 측정(십자선을 끄는 동안 상세 박스 다시 그리기 비용 포함. 시뮬레이터 짧은 끌기에서 43~54fps)
- [ ] C 화면 뼈대 (screens.md C, D-047, D-107, D-111)
  - 완료(2026-11-24): `CommodityView`(title-bar [←]·`원자재명 (심볼)`·🔔·[⟲]·[⚙], 시스템 뒤로 버튼 숨김으로 쓸어서 뒤로 가기 막음 D-105, 탭 4개는 처음 열 때 만들고 숨겨도 유지, 탭 화면이 `tabFooterTime`으로 보이는 탭의 기준 시각 줄을 올림), `ChartPeriods`(C-a·C-c 기간, C에 들어올 때마다 6M)·`ChartPeriod.nearest`, [⚙]는 A와 공용 `SettingsButton`. 시뮬레이터에서 탭 전환·문구 확인
  - 남음: title-bar 아래 1px `barSeparator`(A·B·C 공통, 아직 없음), C 탭 화면 채우기(아래 항목들), ETP 상세(C-d-a)에서도 기간 유지
- [ ] C-a 이격도차트: `GET /v1/commodities/:code/disparity`, 기간 버튼 6개(D-102), 롤 음영, 십자선 상세, 가로 모드, 이전 3년 받기 중 화면 터치 차단·5초 시간 초과·실패 Alert (D-086, D-103, D-108, D-139)
  - 1단계 조회 완료(2026-11-24): `DisparityRepository`·`QueryCache.disparityChart`(키 `QueryKeys.disparity`, 설정 값별)
  - 2단계 계열 모델 완료(2026-11-24): `DisparityChartModel`(산출 불가일 제외·rare-level 밴드 순위 색·이평선 위·롤 음영/전환일·보이는 구간 최고·최저와 LC·HC·y축 특수 라벨·월물 구성·꼬리 백분위 표기)
  - 3단계 화면 뼈대 완료(2026-11-24): `DisparityTabView`(설정 → 조회, 설정 오류·스켈레톤)·`DisparityScreenModel`(같은 데이터면 그대로, 과거 봉이 앞에 붙으면 범위 유지)·`ChartViewState`(기간 홈·드래그/핀치로 벗어남·[↻]·가까운 기간 테두리)·`PeriodChips`·`ChartResetButton`·`ChartSkeleton`. 시뮬레이터에서 dev 서버 차트·드래그·[↻]·칩 확인
  - 4단계 정보 줄 완료(2026-11-24): `DisparityInfo`(기준값 이름·대체·롤 중·OHLC·안내·이격도 꼬리·LC·HC), 차트 위 반투명 두 줄과 기준값 안내 상자, 봉·선은 정보 줄 높이만큼 비켜 그림(`CanvasCandleChart.insetTop`). 시뮬레이터 확인
  - 5단계 축 완료(2026-11-24): `CandleAxes`(우측 y축 log 눈금 d3 `ticks(6)` 규칙·특수 라벨 밀기·눈금 글자 숨김, 현재가·마지막 종가 점선, x축 월 눈금, 십자선 가격·날짜 라벨과 겹치는 글자 숨김), `ChartAxes.swift`(`AxisTicks`·`PriceLabelLayout`·`MonthTicks`·`ChartText`). 제스처는 y축 자리를 뺀 폭으로 봉을 센다. 시뮬레이터 확인
  - 6단계 꼬리표·롤 표시 완료(2026-11-24): `ExtremeTagLayout`(가운데가 화면 안인 봉의 최고·최저 꼬리표, 회색 점선 비켜 가기·차트 끝에서 화살표 반대쪽), `CandleViewport.centerIndices`, `ChartRollMarks` 음영·전환일 점선(봉 뒤). 시뮬레이터에서 대표월물 전환일·꼬리표 확인(한국형·미국형 음영은 화면 확인 전)
  - 7단계 십자선 상세 완료(2026-11-24): `DisparityDetail`(날짜·월물 구성·전환일 `→ 새 월물`·시고저종·전일 대비·이격도 등락 색·선 값 가격순), 공용 `DetailBox`·`PlacedDetailBox`(정보 줄 아래 귀퉁이). 시뮬레이터 확인
  - 8단계 이전 3년 받기 완료(2026-11-24): `OlderPages`(첫 봉이 보이면 받기·햅틱·5초 시간 초과·실패 Alert·늦은 응답은 데이터만), `ChartViewState.rangeReports`(범위가 바뀌거나 드래그·핀치가 끝날 때 알림)·`locked`(받는 중 차트 제스처 무시), `OlderDataIndicator`, 받는 동안 `.blocksTouches`. 시뮬레이터에서 과거 봉 붙이기·범위 유지·서버를 끈 실패 Alert 확인
  - 9단계 A 행 누를 때 미리 조회 완료(2026-11-25): `CommodityQueries.prefetchDisparity`(캐시 설정을 그대로 쓰고 없을 때만 받음, 실패 무시, RN `prefetchDisparityChart`), RootView `onSelect`에서 기다리지 않고 시작
- [ ] C-c 월물차트: `GET /v1/commodities/:code/contracts`, log y축, 끝값 라벨 (D-092, D-093, D-113, D-118)
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
- [ ] B 설정·B-a 알림 설정: 낙관적 PATCH, rare-level 입력 검증, 알림 대상 없음 빨간 점 (D-081~D-083, D-124)
  - 완료(2026-11-24): `SettingsView`(일반·이격도차트·기타 묶음, `SegmentedRow`, rare-level 5칸 `RareLevelsInput`·`RareLevelsDraft`는 키패드가 닫힐 때 `RareLevels`로 검증·정렬 저장, [초기화] 확인 뒤 표시 설정·`SettingsPatch.disparityDefaults`+언어 PATCH, 저장 실패 줄은 이 화면의 마지막 변경만, 앱 번들 줄 IOS-009·키패드가 보이면 뺌), `AlertSettingsView`(권한 배너 `PushPermission`·대상 원자재·현재 적용 기준·`QuietTimeSection` 30분 48칸 시트), `DataSourcesView`, 공용 `backTitleBar`. `SegmentedRow`는 한 줄에 안 들어가면 쌓는다. 시뮬레이터에서 dev 서버로 언어 전환·rare-level 중복 오류·저장·초기화·알림 대상·알림 거부 시간·데이터 출처 확인
  - 남음: 실기기에서 권한 배너 [허용](권한 창)·[설정 열기] 확인. iOS 26 키패드 [완료]가 rare-level 칸 일부를 덮는다(누를 수는 있음, 실기기에서 다시 본다). ETP 상세·C title-bar를 `backTitleBar`로 합칠지 검토
- [ ] 화면별 세부 동작은 `../futureETP_ReactNative/docs/wireframes/screens.md`와 하나씩 대조

## 5. 푸시
- [ ] APNs 기기 토큰 등록(Apple 가입 뒤), 가입 전에는 등록하지 않음
- [ ] `PUT /v1/devices`(토큰·플랫폼·`appVersion` `ios-<버전>`), 알림 탭으로 해당 C 화면 이동, 앱 사용 중 알림 표시 (D-037, D-120)

## 6. 기기 설치·운영
- [ ] prod 변형 release 빌드를 개인 기기에 설치하는 절차를 `docs/ops.md`(새로 만든다)에 기록
- [ ] RN 앱과 같은 앱 ID라 바꿔 설치할 때 할 일(기존 앱 삭제, 접근 키 다시 입력, 기기 설정 다시 맞춤) 기록
- [ ] 업데이트 배포 방식(OTA 없음, 재설치) 결정
