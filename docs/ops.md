# 운영: 기기 설치·업데이트

서버 운영(주소·접근 키 생성·dev 서버)은 원본 `../futureETP_ReactNative/docs/ops.md`. 이 문서는 iOS 앱을 개인 iPhone에 까는 절차만 둔다.

## prod 변형 설치 (IOS-010)

Apple Developer 가입 전에는 무료 Apple ID(Personal Team `E8B6A6F4B9`)로 서명해 Mac에서 직접 설치한다. 서명은 7일 뒤 만료되므로 그 전에 다시 설치한다. 스토어·TestFlight·OTA는 쓰지 않는다. Push 권한(entitlements)이 없어 알림은 Apple 가입 뒤(TODO 5단계)다.

### 처음 한 번

1. Xcode → Settings → Accounts에 Apple ID가 있어야 한다(Personal Team)
2. iPhone을 USB로 연결하고 "이 컴퓨터를 신뢰"에 동의한다. 설정 > 개인정보 보호 및 보안 > 개발자 모드를 켠다
3. `xcrun devicectl list devices`에서 기기가 `available (paired)`로 보이는지 확인한다(Name 예: `14P`)
4. 처음 설치한 뒤 실행이 거부되면 기기에서 설정 > 일반 > VPN 및 기기 관리 → 개발자 앱 신뢰

### 빌드·설치 (업데이트·7일 재설치도 같다)

```bash
./scripts/install-prod.sh 14P
```

- 앱 경로(`App`·`Core`·`Features`·`Config`·`Project.swift`·`Tuist.swift`)에 커밋 안 한 변경이 있으면 멈춘다
- generate → Release 빌드(`build/prod-dd`) → 기기마다 설치·실행. 기기를 여럿 주면 모두 설치한다
- 빌드 번호(`CFBundleVersion`)는 `git rev-list --count HEAD`다. B 맨 아래 `앱 번들: 빌드에 내장 · 런타임 1.0.0 (<커밋 수>)`로 어느 커밋이 깔렸는지 본다(IOS-009)
- 처음 쓰는 기기는 맨 앞에 둔다. 첫 기기를 빌드 대상으로 써서 팀에 등록한다(`0xe8008012`가 나면 그 기기를 앞에 두고 다시)
- `--build-only`: 서명된 빌드만 하고 설치하지 않는다
- 이전 iOS 빌드 위에 덮어 설치하면 접근 키·installation ID(Keychain)와 표시 설정(UserDefaults)이 그대로 남는다

### RN·Flutter 앱과 바꿔 설치

앱 ID가 같아(IOS-002) 한 기기에 하나만 깔린다. 같은 팀으로 서명하므로 지우지 않고 덮어 설치된다. RN `expo-secure-store`·Flutter `flutter_secure_storage`와 이 앱의 Keychain 항목은 이름이 달라, 어느 쪽으로 바꾸든 앱 안 데이터는 이어지지 않는다.

- RN·FL → iOS: `./scripts/install-prod.sh 14P`. 처음 켜면 새 기기다
  1. B-b에서 접근 키를 다시 입력한다(QR 또는 붙여넣기)
  2. installation ID가 새로 생겨 서버가 새 기기 행을 만든다(D-120). B-a의 대상 원자재·rare 레벨·거부 시간을 다시 맞춘다
  3. B의 언어·등락 색을 다시 고른다. 시간대·언어는 앱이 서버에 PATCH한다(D-084)
- iOS → RN: futureETP에서 `npm run ios:prod-install -- 14P`
- iOS → FL: `../futureETP_Flutter/docs/ops.md`의 iOS 절
