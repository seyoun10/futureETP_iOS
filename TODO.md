# TODO

목표: Swift/SwiftUI로 RN 앱(`../futureETP_ReactNative/apps/mobile`)과 같은 기능의 앱 만들기(iOS, 개인용, D-011)
지침: 남은 항목만 둔다. 최상위 항목이 하위 항목까지 모두 끝나면 블록째 `docs/history.md`의 같은 절 끝으로 옮긴다. 새 단계·항목은 여기에 추가한다
원본 변경 따라가기: `../futureETP_ReactNative`에서 API·shared 스키마·화면 동작이 바뀌면 그쪽에서 이 파일의 "원본 변경 반영"에 항목을 적는다

## 원본 변경 반영
마지막 대조: futureETP `271b148`(2026-11-25, 앱 코드를 쓰기 전이라 그 전 RN 앱 코드 수정은 현재 RN 코드를 보고 구현할 때 들어간다). 적힌 항목 밖에 빠진 것이 있는지는 `git -C ../futureETP_ReactNative log --oneline 271b148..HEAD -- apps/mobile packages/shared docs/wireframes`로 그 뒤 커밋만 이 저장소 구현과 맞춰 본다. 다 보면 이 줄의 커밋을 그 HEAD로 바꾼다
- [ ] 설정 키패드는 [완료]로만 닫기(2026-11-25, futureETP D-083 보충, `821b8c5`): B rare-level 키패드를 화면을 끌거나 빈 곳을 눌러도 닫지 않는다. iOS는 키패드 위 [완료] 줄, Android는 키패드의 완료 키로만 닫고, 열린 채 다른 행을 누르면 그 행이 눌린다(futureETP `SettingsScreen.tsx` `keyboardDismissMode="none"`·`keyboardShouldPersistTaps="always"`). screens.md B
- [ ] 설정 키패드가 입력칸을 가리지 않게(2026-11-25, futureETP D-083 보충, `675fb8d`): B rare-level 키패드가 올라오면 포커스된 입력칸과 그 아래 안내 줄이 키패드·iOS [완료] 줄에 가리지 않도록 화면을 끌어올린다(futureETP `components/useKeepFocusedInputVisible.ts`: 입력칸 아래 + 48pt가 보이는 영역 아래를 넘은 만큼 스크롤). screens.md B
- [ ] 설정 맨 아래 줄 머리에 클라이언트 구분·변형(2026-11-25, futureETP D-141, `b16c6e7`·`6dda52a`): 같은 앱 ID를 쓰는 앱 중 어느 것이, dev·prod 중 어느 변형이 떠 있는지 보이도록 B 맨 아래 줄을 `iOS prod:`·`iOS dev:`로 시작한다(RN은 `앱 번들:` → `RN prod:`, 네이티브 앱은 예: `iOS prod: 1.0.0 (빌드 1)`). 줄은 한 줄 고정이라 글자 수를 늘리지 않는다. screens.md B 맨 아래 앱 번들 줄

## 0. 환경
- [ ] Apple Developer 가입 전에는 시뮬레이터와 개인 무료 서명(7일) 실기기만 가능. APNs는 가입 뒤 (D-039, futureETP TODO 5-10)

## 1. 스택 확정
- [x] 차트는 SwiftUI `Canvas` 직접 구현 (IOS-008, 2026-11-24)

## 2. 스캐폴딩

## 3. 공통 기반

## 4. 화면 수직 슬라이스 (RN 순서)
- [ ] C-a 차트 스파이크: 봉 756개 + 이평선·rare-level 밴드, 핀치·드래그·십자선, 가장 과거 봉이 보이면 이전 3년 이어 받기에서 범위 유지, 60fps 이상 (D-056, D-087, D-104, D-106) → 차트 방식 결정
  - 1단계 렌더링 완료(2026-11-24): `CandleViewport`·`PriceScale`·`LineSample`·`CanvasCandleChart`, 측정 화면 `ChartSpikeView`(dev, `-chartSpike`). Canvas로 결정(IOS-008)
  - 2단계 제스처 완료(2026-11-24): `ChartInteraction`(십자선 유지·탭으로 지우기·십자선이 있으면 끌기가 십자선을 옮김·핀치한 터치에서 십자선 막기·핀치 가운데 따라가기), `ChartGestureSurface`(UIKit 인식기: 길게 누르기 0.3초·탭·한 손가락 끌기·핀치), `DetailCorner`(상세 박스 귀퉁이), 봉 스냅 햅틱(`sensoryFeedback(.selection)`). 시뮬레이터에서 동작 확인
  - 3단계 과거 봉 붙이기 완료(2026-11-24): `CandleViewport.rebased`·`showsFirstBar`, `ChartInteraction.dataChanged(barCount:prepended:)`(보던 범위 유지·십자선 지우기·핀치 중이면 시작 범위도 옮김). 스파이크는 가장 과거 봉이 보이면 0.5초 뒤 756봉을 앞에 붙인다(3,024봉까지). C-a 화면은 RN `prependedBars`처럼 첫 날짜가 앞당겨지고 마지막 날짜가 같을 때만 앞에 붙은 봉으로 센다
  - 14P prod 미러링 확인(2026-11-25): GC C-a 12M 칩·끌기·[↻]·가장 과거 봉에서 이전 3년 받기(표시·범위 유지), C-b [<]·기준일 시트·되돌리기, C-d 순자산 정렬·C-d-a 상세. 길게 눌러 십자선 상세·탭으로 지우기도 확인. 미러링으로 못 본 핀치·A 당겨서 새로고침은 14P에서 직접 확인(2026-11-25)
  - 14P prod 빌드 93 Animation Hitches 30초(2026-11-25): 차트 끌기·핀치·십자선 동안 화면 갱신이 16.7ms(60Hz)에 머묾(883프레임 중 772), 끊김 21번 모두 한 프레임. 기기 vsync에 8.3ms가 있어 기기 설정(저전력·프레임 속도 제한) 제한은 아님. 앱이 차트 제스처 동안 높은 프레임 속도를 요청하지 않는 것으로 보임(`CAFrameRateRange`를 쓰는 곳은 dev 측정기뿐). 제스처 동안 120Hz 요청을 넣음(`FrameRateBoost`: 길게 누르기·끌기·핀치 동안 `CADisplayLink` 80~120Hz, 2026-11-25)
  - 14P prod 빌드 97 Animation Hitches 120초(2026-11-25, 끌기→핀치→십자선 순): 세 동작 모두 vsync가 8.3ms(120Hz)로 오르고 손을 떼면 100ms로 내려감(`FrameRateBoost` 동작 확인). 앱이 실제로 보낸 프레임은 끌기 평균 약 55/s(35~79), 핀치 약 45/s(4~69), 십자선 약 98/s(82~109). 끊김 121번은 모두 한 프레임(8.3ms, 12.5ms 두 번)이고 대부분 "Potentially expensive app update(s)"
  - 14P prod 빌드 97 Time Profiler 120초(2026-11-25): 제스처 중 메인 스레드 샘플의 약 25%가 `L10n.string`(그중 10~12%는 `{{…}}` 정규식 리터럴을 호출마다 다시 해석), 18%가 `ChartText.widestMonthLabel`(월 라벨 12개 너비를 매 프레임 측정). 자리 표시자 없는 문구는 정규식 건너뛰기·정규식과 언어 번들 한 번만 만들기·월 라벨 최대 너비 locale별 기억으로 고침
  - 14P prod 빌드 99 Time Profiler 120초(2026-11-25, 빌드 97과 같은 launch 방식, 끌기→핀치→십자선 순): 메인 스레드 샘플 중 `L10n.string` 25%→5%, 정규식 16%→1%, `widestMonthLabel` 18%→0%, `DisparityInfoLines` 9%→3%. 메인 스레드 사용률은 끌기 29%→25%, 핀치 약 29%, 십자선 42%. 남은 큰 몫은 렌더 커밋(RenderBox·QuartzCore) 약 60%, `CanvasCandleChart` 그리기 약 42%(그중 `drawLabels` 27%, `drawExtremeTags` 11%). 사용률이 30% 안팎이라 CPU가 꽉 찬 상태는 아니다. 같은 날 launch 방식 Animation Hitches(빌드 99)는 끌기 약 28/s·핀치 약 35/s로 빌드 97(실행 중인 앱에 붙여 잼)보다 낮았지만 방식·손동작 차이를 가를 수 없음
  - [ ] (선택, 2026-11-25 보류) 끌기·핀치 프레임 수 더 올리기. 눈으로 끊김이 보이면 진행한다. RN 87~107fps는 `perf:collect` UI 스레드 fps라 Animation Hitches 프레임 수와 바로 비교하지 않는다
    - 14P dev 빌드 스파이크 화면(`-chartSpike`, 자동 시나리오)을 Animation Hitches로 재서 Canvas 자체 비용과 C-a 화면 상태 갱신 비용을 가른다. 스파이크가 120fps 가까이면 C-a 화면에서 제스처 상태를 읽는 범위를 좁히고, 거기서도 낮으면 그리기 범위 나누기를 검토한다
    - `CanvasCandleChart.drawLabels`(27%)·`drawExtremeTags`(11%)가 매 프레임 글자를 다시 만드는 부분 줄이기
    - 측정 방법: `xcrun devicectl device info ddiServices --device <UDID>`로 기기를 xctrace에 올린 뒤 `xcrun xctrace record --template 'Animation Hitches'`(또는 `'Time Profiler'`) `--device <UDID> --time-limit 120s --launch -- <bundle ID>`. 실행 중인 앱에 붙이는 것과 결과가 달라 같은 방식끼리만 비교한다

## 5. 푸시
- [ ] APNs 기기 토큰 등록(Apple 가입 뒤), 가입 전에는 등록하지 않음
- [ ] `PUT /v1/devices`(토큰·플랫폼·`appVersion` `ios-<버전>`), 알림 탭으로 해당 C 화면 이동, 앱 사용 중 알림 표시 (D-037, D-120)
