# TODO

목표: Swift/SwiftUI로 RN 앱(`../futureETP_ReactNative/apps/mobile`)과 같은 기능의 앱 만들기(iOS, 개인용, D-011)
지침: 남은 항목만 둔다. 최상위 항목이 하위 항목까지 모두 끝나면 블록째 `docs/history.md`의 같은 절 끝으로 옮긴다. 새 단계·항목은 여기에 추가한다
원본 변경 따라가기: `../futureETP_ReactNative`에서 API·shared 스키마·화면 동작이 바뀌면 그쪽에서 이 파일의 "원본 변경 반영"에 항목을 적는다

## 원본 변경 반영
마지막 대조: futureETP `271b148`(2026-11-25, 앱 코드를 쓰기 전이라 그 전 RN 앱 코드 수정은 현재 RN 코드를 보고 구현할 때 들어간다). 적힌 항목 밖에 빠진 것이 있는지는 `git -C ../futureETP_ReactNative log --oneline 271b148..HEAD -- apps/mobile packages/shared docs/wireframes`로 그 뒤 커밋만 이 저장소 구현과 맞춰 본다. 다 보면 이 줄의 커밋을 그 HEAD로 바꾼다

## 0. 환경
- [ ] Apple Developer 가입 전에는 시뮬레이터와 개인 무료 서명(7일) 실기기만 가능. APNs는 가입 뒤 (D-039, futureETP TODO 5-10)

## 1. 스택 확정
- [x] 차트는 SwiftUI `Canvas` 직접 구현 (IOS-008, 2026-11-24)

## 2. 스캐폴딩
- [ ] (선택) 원격 저장소·CI(GitHub Actions에서 check): `.github/workflows/check.yml`(러너 `xcode-27`, Xcode 27.2, futureETP main을 함께 받아 `FUTUREETP_DIR`로 넘김) 작성(2026-11-24). 첫 실행 통과 확인이 남음

## 3. 공통 기반
- [ ] 접근 키 B-b: 붙여넣기·QR(`futureetp-key:v1:` 접두사), `GET /v1/settings`로 확인 뒤 저장, 키 없으면 첫 화면이 B-b, `UNAUTHORIZED`면 어느 화면에서든 B-b + 거절 줄 (D-044, D-077~D-079)
  - 코드 완료(a4da4d4~ba01dfd). 시뮬레이터에서 dev 서버 키 붙여넣기·Keychain 저장·재실행 유지 확인(2026-11-24). 14P prod에서 RN 앱을 덮어쓴 뒤 첫 화면 B-b·키 재입력 뒤 A 표시 확인(2026-11-25, iPhone 미러링 창에서 ⌘V 붙여넣기는 안 됨). 남은 확인: 키 교체 뒤 거절 시 B-b 이동, 실기기 QR 스캔. 확인되면 이 항목을 `docs/history.md`로 옮긴다
- [ ] 앱 실행 때 시간대 PATCH (D-084), 세로 잠금·[⟲] 가로 전환 (D-076)
  - 시간대·언어 PATCH 코드 완료(2026-11-24): `SettingsStore`(설정 조회·낙관적 PATCH 줄 세우기)·`.deviceSettingsSync`(루트, 키 있을 때). dev 서버 확인 완료(2026-11-25): `TZ=America/Chicago`·영어로 실행하면 `device` 행이 `en`·`America/Chicago`로, 서울로 다시 실행하면 시간대가 되돌아감. 언어는 앱 설정 저장값이 기기 언어보다 앞서므로(D-033) B에서 [한국어]를 누를 때 `ko`로 PATCH됨
  - 세로 잠금 기반 완료(2026-11-24): `OrientationLock`(시작 세로, `lockPortrait`·`lockLandscape`·[⟲]용 `toggle(isLandscape:)`, `AppDelegate`가 허용 방향 반환)·`\.isLandscape`(창 모양, 루트 `providesIsLandscape`)
  - C [⟲] 완료(2026-11-24): ETP 탭 밖에서만 보임, ETP 탭 진입·C를 떠날 때 `lockPortrait`, 가로에서 tab-bar·기준 시각 줄 숨김. 시뮬레이터에서 가로 전환·가로에서 [←]로 A 세로 복귀 확인. 14P 미러링에서 [⟲] 가로 전환·세로 복귀 확인(2026-11-25). 남음: 기기를 직접 돌릴 때 동작

## 4. 화면 수직 슬라이스 (RN 순서)
- [ ] C-a 차트 스파이크: 봉 756개 + 이평선·rare-level 밴드, 핀치·드래그·십자선, 가장 과거 봉이 보이면 이전 3년 이어 받기에서 범위 유지, 60fps 이상 (D-056, D-087, D-104, D-106) → 차트 방식 결정
  - 1단계 렌더링 완료(2026-11-24): `CandleViewport`·`PriceScale`·`LineSample`·`CanvasCandleChart`, 측정 화면 `ChartSpikeView`(dev, `-chartSpike`). Canvas로 결정(IOS-008)
  - 2단계 제스처 완료(2026-11-24): `ChartInteraction`(십자선 유지·탭으로 지우기·십자선이 있으면 끌기가 십자선을 옮김·핀치한 터치에서 십자선 막기·핀치 가운데 따라가기), `ChartGestureSurface`(UIKit 인식기: 길게 누르기 0.3초·탭·한 손가락 끌기·핀치), `DetailCorner`(상세 박스 귀퉁이), 봉 스냅 햅틱(`sensoryFeedback(.selection)`). 시뮬레이터에서 동작 확인
  - 3단계 과거 봉 붙이기 완료(2026-11-24): `CandleViewport.rebased`·`showsFirstBar`, `ChartInteraction.dataChanged(barCount:prepended:)`(보던 범위 유지·십자선 지우기·핀치 중이면 시작 범위도 옮김). 스파이크는 가장 과거 봉이 보이면 0.5초 뒤 756봉을 앞에 붙인다(3,024봉까지). C-a 화면은 RN `prependedBars`처럼 첫 날짜가 앞당겨지고 마지막 날짜가 같을 때만 앞에 붙은 봉으로 센다
  - 남음: 실기기 120Hz·Release 측정(십자선을 끄는 동안 상세 박스 다시 그리기 비용 포함. 시뮬레이터 짧은 끌기에서 43~54fps)
- [ ] B 설정·B-a 알림 설정: 낙관적 PATCH, rare-level 입력 검증, 알림 대상 없음 빨간 점 (D-081~D-083, D-124)
  - 완료(2026-11-24): `SettingsView`(일반·이격도차트·기타 묶음, `SegmentedRow`, rare-level 5칸 `RareLevelsInput`·`RareLevelsDraft`는 키패드가 닫힐 때 `RareLevels`로 검증·정렬 저장, [초기화] 확인 뒤 표시 설정·`SettingsPatch.disparityDefaults`+언어 PATCH, 저장 실패 줄은 이 화면의 마지막 변경만, 앱 번들 줄 IOS-009·키패드가 보이면 뺌), `AlertSettingsView`(권한 배너 `PushPermission`·대상 원자재·현재 적용 기준·`QuietTimeSection` 30분 48칸 시트), `DataSourcesView`, 공용 `backTitleBar`. `SegmentedRow`는 한 줄에 안 들어가면 쌓는다. 시뮬레이터에서 dev 서버로 언어 전환·rare-level 중복 오류·저장·초기화·알림 대상·알림 거부 시간·데이터 출처 확인
  - 남음: [허용](권한 창)·[설정 열기] 누르기. 14P에서 권한 배너 표시 확인(2026-11-25). 키패드 [완료]가 rare-level 칸을 덮는지는 미러링(하드웨어 키보드라 키패드가 안 뜸)으로 못 봄. 미러링에서는 [완료] 막대가 뜨고 앱 번들 줄이 남아 접근 키 행 위에 겹쳐 보임

## 5. 푸시
- [ ] APNs 기기 토큰 등록(Apple 가입 뒤), 가입 전에는 등록하지 않음
- [ ] `PUT /v1/devices`(토큰·플랫폼·`appVersion` `ios-<버전>`), 알림 탭으로 해당 C 화면 이동, 앱 사용 중 알림 표시 (D-037, D-120)
