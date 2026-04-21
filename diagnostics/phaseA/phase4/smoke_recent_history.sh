#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="${1:-$ROOT_DIR/diagnostics/phaseA/phase4/evidence/$STAMP/recent-history-smoke}"
API_URL="${API_URL:-http://localhost:5022}"
MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-60}"
RECENT_TAKE="${RECENT_TAKE:-25}"
SMOKE_SOURCE="${SMOKE_SOURCE:-phase4-recent-history-smoke}"

REQUEST_BODY_PATH="$EVIDENCE_DIR/request.json"
POST_RESPONSE_PATH="$EVIDENCE_DIR/post-response.json"
STATUS_RESPONSE_PATH="$EVIDENCE_DIR/status-response.json"
RECENT_RESPONSE_PATH="$EVIDENCE_DIR/recent-response.json"
RECENT_ITEM_PATH="$EVIDENCE_DIR/recent-item.json"
HISTORY_RESPONSE_PATH="$EVIDENCE_DIR/history-response.json"
CHECKS_PATH="$EVIDENCE_DIR/checks.txt"
SUMMARY_PATH="$EVIDENCE_DIR/summary.txt"
MANIFEST_PATH="$EVIDENCE_DIR/manifest.json"

mkdir -p "$EVIDENCE_DIR"
: > "$CHECKS_PATH"

log() {
  printf "[%s] %s\n" "$(date -u +%FT%TZ)" "$*"
}

record_check() {
  printf "%s\n" "$*" >> "$CHECKS_PATH"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

wait_for_http() {
  local url="$1"
  local max_seconds="$2"
  for _ in $(seq 1 "$max_seconds"); do
    if curl -fsS --max-time 2 "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

wait_for_api_ready() {
  local base_url="$1"
  local max_seconds="$2"
  if wait_for_http "${base_url%/}/health" "$max_seconds"; then
    return 0
  fi
  wait_for_http "${base_url%/}/" "$max_seconds"
}

fail() {
  local message="$1"
  record_check "FAIL $message"
  printf "failure=%s\n" "$message" > "$SUMMARY_PATH"
  exit 1
}

assert_omits_content() {
  local file="$1"
  local label="$2"
  local content_value="$3"

  if grep -Fqi '"content":' "$file"; then
    fail "$label exposed content field"
  fi

  if grep -Fq "$content_value" "$file"; then
    fail "$label exposed request content"
  fi

  record_check "PASS $label omits request content"
}

require_cmd curl
require_cmd jq

if ! wait_for_api_ready "$API_URL" 15; then
  fail "API did not become ready at $API_URL"
fi

request_content="phase4-recent-history-smoke-$STAMP-$RANDOM"
jq -n \
  --arg content "$request_content" \
  --arg source "$SMOKE_SOURCE" \
  '{content:$content,source:$source}' > "$REQUEST_BODY_PATH"

log "Submitting smoke request to $API_URL"
post_http_code="$(
  curl -sS \
    -o "$POST_RESPONSE_PATH" \
    -w "%{http_code}" \
    -X POST "$API_URL/api/compliance/check" \
    -H "Content-Type: application/json" \
    --data-binary @"$REQUEST_BODY_PATH" || true
)"

if [[ "$post_http_code" != "200" ]]; then
  fail "POST /api/compliance/check returned HTTP $post_http_code"
fi

request_id="$(jq -r '.checkId // empty' "$POST_RESPONSE_PATH")"
post_status="$(jq -r '.status // empty' "$POST_RESPONSE_PATH")"

if [[ -z "$request_id" ]]; then
  fail "POST response missing checkId"
fi

if [[ "$post_status" != "accepted" ]]; then
  fail "POST response returned unexpected status=$post_status"
fi

record_check "PASS post requestId=$request_id status=$post_status"

processed_status=""
for _ in $(seq 1 "$MAX_WAIT_SECONDS"); do
  status_http_code="$(
    curl -sS \
      -o "$STATUS_RESPONSE_PATH" \
      -w "%{http_code}" \
      "$API_URL/api/compliance/check/$request_id" || true
  )"

  if [[ "$status_http_code" == "200" ]]; then
    current_status="$(jq -r '.status // empty' "$STATUS_RESPONSE_PATH")"
    if [[ "$current_status" == "processed" ]]; then
      processed_status="$current_status"
      break
    fi
  fi

  sleep 1
done

if [[ "$processed_status" != "processed" ]]; then
  last_status="$(jq -r '.status // empty' "$STATUS_RESPONSE_PATH" 2>/dev/null || true)"
  fail "requestId=$request_id did not reach processed state within ${MAX_WAIT_SECONDS}s last_status=${last_status:-unknown}"
fi

record_check "PASS status requestId=$request_id status=$processed_status"

recent_http_code="$(
  curl -sS \
    -o "$RECENT_RESPONSE_PATH" \
    -w "%{http_code}" \
    "$API_URL/api/compliance/check/recent?take=$RECENT_TAKE" || true
)"

if [[ "$recent_http_code" != "200" ]]; then
  fail "GET /api/compliance/check/recent returned HTTP $recent_http_code"
fi

jq --arg requestId "$request_id" 'map(select(.requestId == $requestId)) | .[0]' "$RECENT_RESPONSE_PATH" > "$RECENT_ITEM_PATH"

recent_request_id="$(jq -r '.requestId // empty' "$RECENT_ITEM_PATH")"
recent_status="$(jq -r '.status // empty' "$RECENT_ITEM_PATH")"
recent_accepted_utc="$(jq -r '.acceptedUtc // empty' "$RECENT_ITEM_PATH")"
recent_processed_utc="$(jq -r '.processedAtUtc // empty' "$RECENT_ITEM_PATH")"

if [[ "$recent_request_id" != "$request_id" ]]; then
  fail "recent response did not include requestId=$request_id"
fi

if [[ "$recent_status" != "processed" ]]; then
  fail "recent response returned unexpected status=$recent_status for requestId=$request_id"
fi

if [[ -z "$recent_accepted_utc" || -z "$recent_processed_utc" ]]; then
  fail "recent response missing acceptedUtc or processedAtUtc for requestId=$request_id"
fi

assert_omits_content "$RECENT_RESPONSE_PATH" "recent response" "$request_content"
record_check "PASS recent requestId=$request_id status=$recent_status"

history_http_code="$(
  curl -sS \
    -o "$HISTORY_RESPONSE_PATH" \
    -w "%{http_code}" \
    "$API_URL/api/compliance/check/$request_id/history" || true
)"

if [[ "$history_http_code" != "200" ]]; then
  fail "GET /api/compliance/check/$request_id/history returned HTTP $history_http_code"
fi

history_request_id="$(jq -r '.requestId // empty' "$HISTORY_RESPONSE_PATH")"
history_status="$(jq -r '.status // empty' "$HISTORY_RESPONSE_PATH")"
history_accepted_utc="$(jq -r '.acceptedUtc // empty' "$HISTORY_RESPONSE_PATH")"
history_processed_utc="$(jq -r '.processedAtUtc // empty' "$HISTORY_RESPONSE_PATH")"
history_event_count="$(jq '.events | length' "$HISTORY_RESPONSE_PATH")"
history_first_status="$(jq -r '.events[0].status // empty' "$HISTORY_RESPONSE_PATH")"
history_last_status="$(jq -r '.events | last | .status // empty' "$HISTORY_RESPONSE_PATH")"
history_event_statuses="$(jq -r '[.events[].status] | join(",")' "$HISTORY_RESPONSE_PATH")"

if [[ "$history_request_id" != "$request_id" ]]; then
  fail "history response returned unexpected requestId=$history_request_id"
fi

if [[ "$history_status" != "processed" ]]; then
  fail "history response returned unexpected status=$history_status for requestId=$request_id"
fi

if [[ -z "$history_accepted_utc" || -z "$history_processed_utc" ]]; then
  fail "history response missing acceptedUtc or processedAtUtc for requestId=$request_id"
fi

if (( history_event_count < 2 )); then
  fail "history response returned event_count=$history_event_count for requestId=$request_id"
fi

if [[ "$history_first_status" != "accepted" ]]; then
  fail "history response first event status=$history_first_status for requestId=$request_id"
fi

if [[ "$history_last_status" != "processed" ]]; then
  fail "history response last event status=$history_last_status for requestId=$request_id"
fi

assert_omits_content "$HISTORY_RESPONSE_PATH" "history response" "$request_content"
record_check "PASS history requestId=$request_id events=$history_event_count statuses=$history_event_statuses"

cat > "$SUMMARY_PATH" <<EOF
script=smoke_recent_history.sh
api_url=$API_URL
evidence_dir=$EVIDENCE_DIR
request_id=$request_id
post_status=$post_status
status_endpoint=$processed_status
recent_status=$recent_status
history_status=$history_status
accepted_utc=$history_accepted_utc
processed_at_utc=$history_processed_utc
history_event_count=$history_event_count
history_event_statuses=$history_event_statuses
recent_take=$RECENT_TAKE
EOF

jq -n \
  --arg script "smoke_recent_history.sh" \
  --arg apiUrl "$API_URL" \
  --arg evidenceDir "$EVIDENCE_DIR" \
  --arg requestId "$request_id" \
  --arg postStatus "$post_status" \
  --arg statusEndpoint "$processed_status" \
  --arg recentStatus "$recent_status" \
  --arg historyStatus "$history_status" \
  --arg acceptedUtc "$history_accepted_utc" \
  --arg processedAtUtc "$history_processed_utc" \
  --argjson historyEventCount "$history_event_count" \
  --arg historyEventStatuses "$history_event_statuses" \
  --argjson recentTake "$RECENT_TAKE" \
  '{
    script: $script,
    api_url: $apiUrl,
    evidence_dir: $evidenceDir,
    request_id: $requestId,
    post_status: $postStatus,
    status_endpoint: $statusEndpoint,
    recent_status: $recentStatus,
    history_status: $historyStatus,
    accepted_utc: $acceptedUtc,
    processed_at_utc: $processedAtUtc,
    history_event_count: $historyEventCount,
    history_event_statuses: ($historyEventStatuses | split(",")),
    recent_take: $recentTake
  }' > "$MANIFEST_PATH"

log "Recent/history smoke passed. Evidence at $EVIDENCE_DIR"
