#!/usr/bin/env bash
# 커밋 전 검사: lint → 계약 예시 → 문구 카탈로그 → import 방향 → 빌드(dev·prod) → 테스트
# 기기는 SIMULATOR 환경 변수로 바꿀 수 있다
set -euo pipefail
cd "$(dirname "$0")/.."

SIMULATOR="${SIMULATOR:-iPhone 18 Pro}"
DESTINATION="platform=iOS Simulator,name=${SIMULATOR}"
SOURCES=(App Core Features Project.swift Tuist.swift)
XCODEBUILD=(xcodebuild -workspace FutureETP.xcworkspace -destination "$DESTINATION"
  -derivedDataPath build/dd -quiet)

step() { printf '\n== %s\n' "$1"; }

step "lint"
swift format lint --recursive --strict "${SOURCES[@]}"

step "계약 예시 스키마 검사 (D-142)"
node scripts/validate-fixtures.mjs

step "문구 카탈로그 (D-033)"
node --no-warnings scripts/gen-strings.mjs --check

step "generate"
mise exec -- tuist generate --no-open >/dev/null

step "import 방향 (IOS-003)"
mise exec -- tuist inspect dependencies

step "Swift 6 언어 모드"
# 모든 타깃·configuration의 SWIFT_VERSION이 6.0인지. Tuist 기본값이 xcconfig를 덮어쓰던 회귀 방지
for config in Debug-Dev Release; do
  versions=$(xcodebuild -project FutureETP.xcodeproj -alltargets -configuration "$config" \
    -showBuildSettings 2>/dev/null | awk '$1 == "SWIFT_VERSION" { print $3 }' | sort -u)
  if [[ "$versions" != "6.0" ]]; then
    echo "SWIFT_VERSION($config)이 6.0이 아님: ${versions:-없음}" >&2
    exit 1
  fi
done

step "build Release"
"${XCODEBUILD[@]}" -scheme FutureETP build

step "test Debug-Dev"
"${XCODEBUILD[@]}" -scheme FutureETP-Dev test

step "ok"
