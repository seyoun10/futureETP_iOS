#!/usr/bin/env bash
# 커밋 전 검사: lint → import 방향 → 빌드(dev·prod) → 테스트
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

step "generate"
mise exec -- tuist generate --no-open >/dev/null

step "import 방향 (IOS-003)"
mise exec -- tuist inspect dependencies --only implicit

step "build Release"
"${XCODEBUILD[@]}" -scheme FutureETP build

step "test Debug-Dev"
"${XCODEBUILD[@]}" -scheme FutureETP-Dev test

step "ok"
