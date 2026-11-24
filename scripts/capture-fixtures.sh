#!/usr/bin/env bash
# 계약 테스트 예시 저장: 로컬 dev 서버 응답 봉투를 Core/Tests/Fixtures/<스키마>[.<변형>].json으로 쓴다 (D-142)
# 접근 키는 futureETP apps/server/.env의 API_TOKEN을 읽는다. 서버는 `npm run dev -w apps/server`로 먼저 띄운다
# 사용: scripts/capture-fixtures.sh [이름 ...]   (이름이 없으면 전부)
set -euo pipefail
cd "$(dirname "$0")/.."

FUTUREETP_DIR="${FUTUREETP_DIR:-../futureETP}"
BASE_URL="${BASE_URL:-http://localhost:3000}"
OUT=Core/Tests/Fixtures
TOKEN=$(grep '^API_TOKEN=' "$FUTUREETP_DIR/apps/server/.env" | cut -d= -f2-)
DEVICE_ID=00000000-0000-4000-8000-000000000001

# 파일 이름(스키마[.변형]) 경로 인증
FIXTURES=(
  "health /v1/health no"
  "commodities /v1/commodities yes"
  "disparityChart /v1/commodities/GC/disparity?basis=FRONT&ma=20&window=Y3&levels=1,2.5,5,10,20 yes"
  "disparityChart.before /v1/commodities/CL/disparity?basis=KR&ma=200&window=ALL&levels=1,2,5,10,20&before=2018-01-02 yes"
  "contractsChart /v1/commodities/GC/contracts yes"
  "contractsChart.before /v1/commodities/NG/contracts?before=2018-01-02 yes"
  "curve /v1/commodities/GC/curve yes"
  "curve.baseDate /v1/commodities/CL/curve?baseDate=2020-04-20 yes"
)

capture() {
  local name=$1 path=$2 auth=$3
  local args=(-sS -m 30 --fail-with-body)
  if [[ $auth == yes ]]; then
    args+=(-H "Authorization: Bearer $TOKEN" -H "X-Device-Id: $DEVICE_ID")
  fi
  curl "${args[@]}" "$BASE_URL$path" | jq . >"$OUT/$name.json"
  echo "$OUT/$name.json ← $path"
}

for entry in "${FIXTURES[@]}"; do
  read -r name path auth <<<"$entry"
  if [[ $# -eq 0 ]] || [[ " $* " == *" $name "* ]]; then
    capture "$name" "$path" "$auth"
  fi
done
