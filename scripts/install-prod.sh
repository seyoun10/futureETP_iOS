#!/usr/bin/env bash
# prod 변형 Release를 Personal Team으로 iPhone에 설치한다(7일 서명 만료 대응, IOS-010). 저장소 루트에서:
#   ./scripts/install-prod.sh <기기 이름|UDID>... [--build-only]
# 기기 이름은 `xcrun devicectl list devices`의 Name(예: 14P). 연결·잠금 해제된 기기만 설치된다.
# 같은 앱 ID라 기기에 깔린 RN·Flutter prod 앱을 덮어쓴다(IOS-002). 절차와 바꿔 설치할 때 할 일은 docs/ops.md.
# 빌드 번호(CFBundleVersion)는 커밋 수라 B 맨 아래 줄로 어느 커밋이 깔렸는지 본다.
# 첫 기기를 빌드 대상으로 써서 -allowProvisioningDeviceRegistration으로 팀에 등록하므로, 처음 쓰는 기기는 맨 앞에 둔다.
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID=E8B6A6F4B9
BUNDLE_ID=io.github.seyoon.futureetp
DD=build/prod-dd

fail() {
  echo "install-prod: $*" >&2
  exit 1
}
log() { echo "install-prod: $*"; }

build_only=0
devices=()
for arg in "$@"; do
  case $arg in
    --build-only) build_only=1 ;;
    -*) fail "알 수 없는 옵션: $arg" ;;
    *) devices+=("$arg") ;;
  esac
done
((${#devices[@]} > 0)) || fail "기기를 하나 이상 주세요 (예: ./scripts/install-prod.sh 14P)"

# 기기 이름을 UDID로 바꾼다. 연결 안 된 기기는 빌드 전에 거른다
device_list=$(xcrun devicectl list devices 2>/dev/null)
udids=()
for d in "${devices[@]}"; do
  line=$(awk -v d="$d" '$0 ~ /physical/ && ($1 == d || index($0, d" ")) {print; exit}' <<<"$device_list")
  [[ -n $line ]] || fail "기기를 찾지 못했습니다: $d (xcrun devicectl list devices)"
  [[ $line == *"available (paired)"* ]] || fail "기기가 연결되지 않았습니다: $d"
  udids+=("$(grep -oE '[0-9A-F]{8}-[0-9A-F]{16}' <<<"$line")")
done

# 커밋 안 한 변경이 들어가면 빌드 번호(커밋 수)로 어느 코드인지 알 수 없다
[[ -z $(git status --porcelain -- App Core Features Config Project.swift Tuist.swift) ]] ||
  fail "앱 경로에 커밋하지 않은 변경이 있습니다. 커밋하거나 stash한 뒤 다시 실행하세요"

build_number=$(git rev-list --count HEAD)
log "generate"
mise exec -- tuist generate --no-open >/dev/null

log "xcodebuild Release $(git rev-parse --short HEAD) (빌드 ${build_number}, 빌드 대상 ${devices[0]})"
xcodebuild -workspace FutureETP.xcworkspace -scheme FutureETP -configuration Release \
  -destination "platform=iOS,id=${udids[0]}" -derivedDataPath "$DD" \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM="$TEAM_ID" CURRENT_PROJECT_VERSION="$build_number" -quiet build

APP="$DD/Build/Products/Release-iphoneos/FutureETP.app"
[[ -d $APP ]] || fail "빌드 산출물이 없습니다: $APP"
if ((build_only)); then
  log "빌드만 했습니다: $APP"
  exit 0
fi

for i in "${!udids[@]}"; do
  log "설치: ${devices[$i]}"
  # 0xe8008012면 그 기기가 프로필에 없다. 그 기기를 맨 앞에 두고 다시 실행한다
  xcrun devicectl device install app --device "${udids[$i]}" "$APP" >/dev/null
  xcrun devicectl device process launch --device "${udids[$i]}" --terminate-existing "$BUNDLE_ID" >/dev/null 2>&1 ||
    log "설치는 됐지만 실행이 거부됐습니다: ${devices[$i]}. 기기 잠금을 풀고, 설정 > 일반 > VPN 및 기기 관리에서 개발자 앱을 신뢰한 뒤 직접 여세요"
done
log "완료: ${devices[*]} (7일 뒤 만료, $(date -v+7d '+%m/%d %H:%M') 전에 다시 설치)"
