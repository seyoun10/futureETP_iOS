#!/usr/bin/env bash
# 계약 테스트 예시 저장: 로컬 dev 서버 응답 봉투를 Core/Tests/Fixtures/<스키마>[.<변형>].json으로 쓴다 (D-142)
# 접근 키는 futureETP apps/server/.env의 API_TOKEN을 읽는다. 서버는 `npm run dev -w apps/server`로 먼저 띄운다
# 사용: scripts/capture-fixtures.sh [이름 ...]   (이름이 없으면 전부)
set -euo pipefail
cd "$(dirname "$0")/.."

FUTUREETP_DIR="${FUTUREETP_DIR:-../futureETP_ReactNative}"
BASE_URL="${BASE_URL:-http://localhost:3000}"
OUT=Core/Tests/Fixtures
TOKEN=$(grep '^API_TOKEN=' "$FUTUREETP_DIR/apps/server/.env" | cut -d= -f2-)
DEVICE_ID=00000000-0000-4000-8000-000000000001

# 파일 이름(스키마[.변형]) 경로 인증 [PUT 본문(공백 없는 JSON)]
FIXTURES=(
  "health /v1/health no"
  "commodities /v1/commodities yes"
  "disparityChart /v1/commodities/GC/disparity?basis=FRONT&ma=20&window=Y3&levels=1,2.5,5,10,20 yes"
  "disparityChart.before /v1/commodities/CL/disparity?basis=KR&ma=200&window=ALL&levels=1,2,5,10,20&before=2018-01-02 yes"
  "contractsChart /v1/commodities/GC/contracts yes"
  "contractsChart.before /v1/commodities/NG/contracts?before=2018-01-02 yes"
  "curve /v1/commodities/GC/curve yes"
  "curve.baseDate /v1/commodities/CL/curve?baseDate=2020-04-20 yes"
  "etpList /v1/commodities/GC/etps yes"
  # ETP id는 dev DB 값이다. DB를 다시 만들면 /v1/commodities/:code/etps에서 같은 조건의 상품으로 바꾼다
  # KRX ETN 시리즈 2개(총보수·상장일 null), US ETF(기초지수 null)
  "etpDetail /v1/etps/add5e164-981f-43b4-b751-bf7204602124 yes"
  "etpDetail.us /v1/etps/6281b11d-ab70-48c7-a9c7-7083c2c56d8e yes"
  # 2026년은 네 종류 예외가 모두 있고, 2028년은 아직 입력 전이라 missing이 찬다
  "calendar /v1/calendar?from=2026-01-01&to=2026-12-31 yes"
  "calendar.missing /v1/calendar?from=2027-06-01&to=2028-05-31 yes"
  "settings /v1/settings yes"
  # 고정 DEVICE_ID 행에 쓴다(dev DB). 토큰 없이 등록한다
  'device /v1/devices yes {"pushToken":null,"platform":"IOS","appVersion":"ios-0.1.0"}'
)

capture() {
  local name=$1 path=$2 auth=$3 body=${4:-}
  local args=(-sS -m 30 --fail-with-body)
  if [[ -n $body ]]; then
    args+=(-X PUT -H "Content-Type: application/json" -d "$body")
  fi
  if [[ $auth == yes ]]; then
    args+=(-H "Authorization: Bearer $TOKEN" -H "X-Device-Id: $DEVICE_ID")
  fi
  curl "${args[@]}" "$BASE_URL$path" | jq . >"$OUT/$name.json"
  echo "$OUT/$name.json ← $path"
}

for entry in "${FIXTURES[@]}"; do
  read -r name path auth body <<<"$entry"
  if [[ $# -eq 0 ]] || [[ " $* " == *" $name "* ]]; then
    capture "$name" "$path" "$auth" "$body"
  fi
done
