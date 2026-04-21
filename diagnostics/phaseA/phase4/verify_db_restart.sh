#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="${1:-$ROOT_DIR/diagnostics/phaseA/phase4/evidence/${STAMP}-db-restart}"
API_URL="${API_URL:-http://localhost:5022}"
STARTUP_WAIT_SECONDS="${STARTUP_WAIT_SECONDS:-120}"
WORKER_WAIT_SECONDS="${WORKER_WAIT_SECONDS:-120}"
READINESS_OUTAGE_WAIT_SECONDS="${READINESS_OUTAGE_WAIT_SECONDS:-30}"
READINESS_RECOVERY_WAIT_SECONDS="${READINESS_RECOVERY_WAIT_SECONDS:-120}"
REQUEST_RECOVERY_WAIT_SECONDS="${REQUEST_RECOVERY_WAIT_SECONDS:-120}"
POSTGRES_READY_WAIT_SECONDS="${POSTGRES_READY_WAIT_SECONDS:-90}"
POSTGRES_OUTAGE_SECONDS="${POSTGRES_OUTAGE_SECONDS:-8}"
REQUEST_SOURCE="${REQUEST_SOURCE:-db-restart-verifier}"

SUMMARY_PATH="$EVIDENCE_DIR/summary.txt"
MANIFEST_PATH="$EVIDENCE_DIR/manifest.json"
CHECKS_PATH="$EVIDENCE_DIR/checks.txt"
APPHOST_LOG="$EVIDENCE_DIR/apphost.log"
APPHOST_PID_PATH="$EVIDENCE_DIR/apphost.pid"

RESULT="fail"
FAILURE_CLASS="unknown"
FAILURE_REASON=""
POSTGRES_CONTAINER=""
POSTGRES_USER=""
POSTGRES_PASSWORD=""
BASELINE_REQUEST_ID=""
RECOVERY_REQUEST_ID=""
OUTAGE_READY_HTTP="000"
OUTAGE_DATABASE_HEALTHY="unknown"
RECOVERY_DATABASE_HEALTHY="unknown"
RECOVERY_BROKER_HEALTHY="unknown"
RECOVERY_STATUS_VALUE="unknown"
RECOVERY_RECENT_STATUS="unknown"

mkdir -p "$EVIDENCE_DIR"
: > "$CHECKS_PATH"

log() {
  printf "[%s] %s\n" "$(date -u +%FT%TZ)" "$*"
}

record_check() {
  local status="$1"
  shift
  printf "%s %s\n" "$status" "$*" >> "$CHECKS_PATH"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

preflight() {
  require_cmd dotnet
  require_cmd docker
  require_cmd curl
  require_cmd jq
  require_cmd pkill
  docker info >/dev/null
}

cleanup_runtime() {
  pkill -f "Sentinel.AppHost" 2>/dev/null || true
  pkill -f "Sentinel.Api" 2>/dev/null || true
  pkill -f "Sentinel.Worker" 2>/dev/null || true
  pkill -f "dotnet run --project $ROOT_DIR/Sentinel" 2>/dev/null || true
  sleep 2
}

resolve_latest_aspire_run_dir() {
  local dir
  local with_logs=""
  local all_dirs=""

  for dir in /var/folders/*/*/T/aspire*; do
    [[ -d "$dir" ]] || continue
    all_dirs+="$dir"$'\n'

    if find "$dir" -maxdepth 1 -type f \
      \( -name 'sentinel-api-*' -o -name 'sentinel-worker-*' -o -name 'resource-service-*.log' -o -name 'resource-executable-*.log' \) \
      | grep -q .; then
      with_logs+="$dir"$'\n'
    fi
  done

  if [[ -n "$with_logs" ]]; then
    printf '%s' "$with_logs" | sed '/^$/d' | xargs ls -td 2>/dev/null | head -n1
    return 0
  fi

  if [[ -n "$all_dirs" ]]; then
    printf '%s' "$all_dirs" | sed '/^$/d' | xargs ls -td 2>/dev/null | head -n1
  fi
}

capture_live_aspire_artifacts() {
  local aspire_dir
  aspire_dir="$(resolve_latest_aspire_run_dir || true)"
  if [[ -n "$aspire_dir" && -d "$aspire_dir" ]]; then
    mkdir -p "$EVIDENCE_DIR/aspire-resource-logs"
    find "$aspire_dir" -maxdepth 1 -type f \
      \( -name 'sentinel-api-*' -o -name 'sentinel-worker-*' -o -name 'resource-*' \) \
      -exec cp {} "$EVIDENCE_DIR/aspire-resource-logs/" \; 2>/dev/null || true
  fi
}

write_summary() {
  cat > "$SUMMARY_PATH" <<EOF
result=$RESULT
failure_class=$FAILURE_CLASS
failure_reason=$FAILURE_REASON
api_url=$API_URL
evidence_dir=$EVIDENCE_DIR
postgres_container=$POSTGRES_CONTAINER
baseline_request_id=$BASELINE_REQUEST_ID
recovery_request_id=$RECOVERY_REQUEST_ID
outage_readiness_http=$OUTAGE_READY_HTTP
outage_database_healthy=$OUTAGE_DATABASE_HEALTHY
recovery_database_healthy=$RECOVERY_DATABASE_HEALTHY
recovery_broker_healthy=$RECOVERY_BROKER_HEALTHY
recovery_status=$RECOVERY_STATUS_VALUE
recovery_recent_status=$RECOVERY_RECENT_STATUS
EOF
}

write_manifest() {
  jq -nc \
    --arg result "$RESULT" \
    --arg failureClass "$FAILURE_CLASS" \
    --arg failureReason "$FAILURE_REASON" \
    --arg apiUrl "$API_URL" \
    --arg evidenceDir "$EVIDENCE_DIR" \
    --arg postgresContainer "$POSTGRES_CONTAINER" \
    --arg baselineRequestId "$BASELINE_REQUEST_ID" \
    --arg recoveryRequestId "$RECOVERY_REQUEST_ID" \
    --arg outageReadinessHttp "$OUTAGE_READY_HTTP" \
    --arg outageDatabaseHealthy "$OUTAGE_DATABASE_HEALTHY" \
    --arg recoveryDatabaseHealthy "$RECOVERY_DATABASE_HEALTHY" \
    --arg recoveryBrokerHealthy "$RECOVERY_BROKER_HEALTHY" \
    --arg recoveryStatus "$RECOVERY_STATUS_VALUE" \
    --arg recoveryRecentStatus "$RECOVERY_RECENT_STATUS" \
    --arg generatedUtc "$(date -u +%FT%TZ)" \
    '{
      generated_utc: $generatedUtc,
      verifier: "verify_db_restart.sh",
      result: $result,
      failure_class: $failureClass,
      failure_reason: $failureReason,
      api_url: $apiUrl,
      evidence_dir: $evidenceDir,
      postgres_container: $postgresContainer,
      baseline_request_id: $baselineRequestId,
      recovery_request_id: $recoveryRequestId,
      outage_readiness_http: $outageReadinessHttp,
      outage_database_healthy: $outageDatabaseHealthy,
      recovery_database_healthy: $recoveryDatabaseHealthy,
      recovery_broker_healthy: $recoveryBrokerHealthy,
      recovery_status: $recoveryStatus,
      recovery_recent_status: $recoveryRecentStatus,
      artifacts: [
        "summary.txt",
        "manifest.json",
        "checks.txt",
        "baseline-post.json",
        "baseline-status.json",
        "outage-readiness.json",
        "recovery-readiness.json",
        "recovery-post.json",
        "recovery-status.json",
        "recovery-history.json",
        "recovery-recent.json",
        "request-ledger.csv",
        "db-counts.txt",
        "apphost.log",
        "aspire-resource-logs/"
      ]
    }' > "$MANIFEST_PATH"
}

finish() {
  capture_live_aspire_artifacts
  write_summary
  write_manifest
}

on_exit() {
  local exit_code="$1"
  if [[ "$RESULT" != "pass" && -z "$FAILURE_REASON" ]]; then
    FAILURE_CLASS="${FAILURE_CLASS:-fail:script}"
    FAILURE_REASON="Verifier exited unexpectedly with code $exit_code"
  fi
  finish
  cleanup_runtime
}

trap 'on_exit $?' EXIT

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

wait_for_worker_ready() {
  local max_seconds="$1"
  for _ in $(seq 1 "$max_seconds"); do
    if pgrep -fal "/Sentinel.Worker/bin/" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

start_runtime() {
  cleanup_runtime
  (
    cd "$ROOT_DIR"
    Sentinel__EnableDiagnosticsEndpoints=true dotnet run --project Sentinel.AppHost > "$APPHOST_LOG" 2>&1
  ) &
  echo "$!" > "$APPHOST_PID_PATH"

  if ! wait_for_api_ready "$API_URL" "$STARTUP_WAIT_SECONDS"; then
    FAILURE_CLASS="fail:startup"
    FAILURE_REASON="API did not become ready at $API_URL"
    record_check "FAIL" "startup api_ready=false url=$API_URL"
    return 1
  fi

  if ! wait_for_worker_ready "$WORKER_WAIT_SECONDS"; then
    FAILURE_CLASS="fail:startup"
    FAILURE_REASON="Worker did not become ready"
    record_check "FAIL" "startup worker_ready=false"
    return 1
  fi

  record_check "PASS" "startup api_ready=true worker_ready=true"
  return 0
}

resolve_postgres_container() {
  docker ps --format '{{.Names}}' | grep '^postgres-' | head -n1
}

wait_for_postgres_ready() {
  local pg_container="$1"
  local pg_user="$2"
  local pg_pass="$3"
  local max_seconds="$4"
  for _ in $(seq 1 "$max_seconds"); do
    if docker exec -e PGPASSWORD="$pg_pass" "$pg_container" pg_isready -U "$pg_user" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

fetch_with_status() {
  local method="$1"
  local url="$2"
  local output_path="$3"
  local body_path="${4:-}"
  local http_code

  if [[ -n "$body_path" ]]; then
    http_code="$(curl -sS --max-time 30 -o "$output_path" -w "%{http_code}" \
      -X "$method" "$url" \
      -H "Content-Type: application/json" \
      --data-binary "@$body_path" || true)"
  else
    http_code="$(curl -sS --max-time 30 -o "$output_path" -w "%{http_code}" \
      -X "$method" "$url" || true)"
  fi

  printf '%s' "$http_code"
}

post_check() {
  local label="$1"
  local content="$2"
  local body_path="$EVIDENCE_DIR/${label}-request.json"
  local response_path="$EVIDENCE_DIR/${label}-post.json"
  local http_path="$EVIDENCE_DIR/${label}-post.http"

  jq -nc --arg content "$content" --arg source "$REQUEST_SOURCE" \
    '{content:$content,source:$source}' > "$body_path"

  local http_code
  http_code="$(fetch_with_status "POST" "$API_URL/api/compliance/check" "$response_path" "$body_path")"
  printf '%s\n' "$http_code" > "$http_path"

  if [[ "$http_code" != "200" ]]; then
    FAILURE_CLASS="fail:http"
    FAILURE_REASON="POST /api/compliance/check failed for $label with HTTP $http_code"
    record_check "FAIL" "post label=$label http=$http_code"
    return 1
  fi

  local check_id status
  check_id="$(jq -r '.checkId // .requestId // empty' "$response_path" 2>/dev/null || true)"
  status="$(jq -r '.status // empty' "$response_path" 2>/dev/null || true)"

  if [[ -z "$check_id" || "$status" != "accepted" ]]; then
    FAILURE_CLASS="fail:http"
    FAILURE_REASON="POST /api/compliance/check returned unexpected payload for $label"
    record_check "FAIL" "post label=$label payload_invalid=true"
    return 1
  fi

  record_check "PASS" "post label=$label requestId=$check_id status=$status"
  printf '%s\n' "$check_id"
}

wait_for_request_status() {
  local request_id="$1"
  local expected_status="$2"
  local max_seconds="$3"
  local output_path="$4"
  local http_path="$5"
  local attempt_path="$EVIDENCE_DIR/request-status-poll.csv"

  if [[ ! -f "$attempt_path" ]]; then
    echo "timestamp_utc,request_id,http_code,status" > "$attempt_path"
  fi

  local http_code status
  for _ in $(seq 1 "$max_seconds"); do
    http_code="$(fetch_with_status "GET" "$API_URL/api/compliance/check/$request_id" "$output_path")"
    status=""
    if [[ -f "$output_path" ]]; then
      status="$(jq -r '.status // empty' "$output_path" 2>/dev/null || true)"
    fi
    printf '%s,%s,%s,%s\n' "$(date -u +%FT%TZ)" "$request_id" "$http_code" "${status:-}" >> "$attempt_path"
    if [[ "$http_code" == "200" && "$status" == "$expected_status" ]]; then
      printf '%s\n' "$http_code" > "$http_path"
      return 0
    fi
    sleep 1
  done

  printf '%s\n' "${http_code:-000}" > "$http_path"
  FAILURE_CLASS="fail:request-state"
  FAILURE_REASON="Request $request_id did not reach status=$expected_status within ${max_seconds}s"
  record_check "FAIL" "request_status requestId=$request_id expected=$expected_status"
  return 1
}

fetch_readiness() {
  local label="$1"
  local output_path="$EVIDENCE_DIR/${label}-readiness.json"
  local http_path="$EVIDENCE_DIR/${label}-readiness.http"
  local http_code

  http_code="$(fetch_with_status "GET" "$API_URL/api/diagnostics/readiness" "$output_path")"
  printf '%s\n' "$http_code" > "$http_path"
  printf '%s' "$http_code"
}

wait_for_readiness_database_state() {
  local expected="$1"
  local max_seconds="$2"
  local label="$3"
  local output_path="$EVIDENCE_DIR/${label}-readiness.json"
  local http_path="$EVIDENCE_DIR/${label}-readiness.http"
  local poll_path="$EVIDENCE_DIR/${label}-readiness-poll.csv"
  local http_code database_healthy broker_healthy

  echo "timestamp_utc,http_code,database_healthy,broker_healthy" > "$poll_path"

  for _ in $(seq 1 "$max_seconds"); do
    http_code="$(fetch_with_status "GET" "$API_URL/api/diagnostics/readiness" "$output_path")"
    database_healthy=""
    broker_healthy=""
    if [[ "$http_code" == "200" ]]; then
      database_healthy="$(jq -r '.databaseHealthy' "$output_path" 2>/dev/null || true)"
      broker_healthy="$(jq -r '.brokerHealthy' "$output_path" 2>/dev/null || true)"
    fi

    printf '%s,%s,%s,%s\n' "$(date -u +%FT%TZ)" "$http_code" "${database_healthy:-}" "${broker_healthy:-}" >> "$poll_path"

    if [[ "$expected" == "false" ]]; then
      if [[ "$http_code" != "200" || "$database_healthy" == "false" ]]; then
        printf '%s\n' "$http_code" > "$http_path"
        return 0
      fi
    else
      if [[ "$http_code" == "200" && "$database_healthy" == "true" ]]; then
        printf '%s\n' "$http_code" > "$http_path"
        return 0
      fi
    fi
    sleep 1
  done

  printf '%s\n' "${http_code:-000}" > "$http_path"
  FAILURE_CLASS="fail:readiness"
  FAILURE_REASON="Readiness did not reach databaseHealthy=$expected within ${max_seconds}s"
  record_check "FAIL" "readiness expected_database_healthy=$expected"
  return 1
}

wait_for_readiness_healthy() {
  local max_seconds="$1"
  local label="$2"
  local output_path="$EVIDENCE_DIR/${label}-readiness.json"
  local http_path="$EVIDENCE_DIR/${label}-readiness.http"
  local poll_path="$EVIDENCE_DIR/${label}-readiness-poll.csv"
  local http_code database_healthy broker_healthy

  echo "timestamp_utc,http_code,database_healthy,broker_healthy" > "$poll_path"

  for _ in $(seq 1 "$max_seconds"); do
    http_code="$(fetch_with_status "GET" "$API_URL/api/diagnostics/readiness" "$output_path")"
    database_healthy=""
    broker_healthy=""
    if [[ "$http_code" == "200" ]]; then
      database_healthy="$(jq -r '.databaseHealthy' "$output_path" 2>/dev/null || true)"
      broker_healthy="$(jq -r '.brokerHealthy' "$output_path" 2>/dev/null || true)"
    fi

    printf '%s,%s,%s,%s\n' "$(date -u +%FT%TZ)" "$http_code" "${database_healthy:-}" "${broker_healthy:-}" >> "$poll_path"

    if [[ "$http_code" == "200" && "$database_healthy" == "true" && "$broker_healthy" == "true" ]]; then
      printf '%s\n' "$http_code" > "$http_path"
      return 0
    fi
    sleep 1
  done

  printf '%s\n' "${http_code:-000}" > "$http_path"
  FAILURE_CLASS="fail:readiness"
  FAILURE_REASON="Readiness did not return to databaseHealthy=true and brokerHealthy=true within ${max_seconds}s"
  record_check "FAIL" "readiness expected_database_healthy=true expected_broker_healthy=true"
  return 1
}

capture_recovery_reads() {
  local request_id="$1"
  local recent_http history_http

  recent_http="$(fetch_with_status "GET" "$API_URL/api/compliance/check/recent?take=5" "$EVIDENCE_DIR/recovery-recent.json")"
  printf '%s\n' "$recent_http" > "$EVIDENCE_DIR/recovery-recent.http"

  history_http="$(fetch_with_status "GET" "$API_URL/api/compliance/check/$request_id/history" "$EVIDENCE_DIR/recovery-history.json")"
  printf '%s\n' "$history_http" > "$EVIDENCE_DIR/recovery-history.http"

  if [[ "$recent_http" != "200" || "$history_http" != "200" ]]; then
    FAILURE_CLASS="fail:read-model"
    FAILURE_REASON="Recovery read endpoints did not return HTTP 200"
    record_check "FAIL" "read_model recent_http=$recent_http history_http=$history_http"
    return 1
  fi

  RECOVERY_RECENT_STATUS="$(jq -r --arg requestId "$request_id" '.[] | select(.requestId == $requestId) | .status' "$EVIDENCE_DIR/recovery-recent.json" | head -n1)"
  RECOVERY_RECENT_STATUS="${RECOVERY_RECENT_STATUS:-missing}"

  if ! jq -e --arg requestId "$request_id" '.[] | select(.requestId == $requestId)' "$EVIDENCE_DIR/recovery-recent.json" >/dev/null; then
    FAILURE_CLASS="fail:read-model"
    FAILURE_REASON="Recovery request did not appear in /recent output"
    record_check "FAIL" "read_model recent_contains_request=false requestId=$request_id"
    return 1
  fi

  if ! jq -e '.status == "processed"' "$EVIDENCE_DIR/recovery-history.json" >/dev/null; then
    FAILURE_CLASS="fail:read-model"
    FAILURE_REASON="Recovery history did not report processed status"
    record_check "FAIL" "read_model history_status_processed=false requestId=$request_id"
    return 1
  fi

  if ! jq -e '.events | length >= 2' "$EVIDENCE_DIR/recovery-history.json" >/dev/null; then
    FAILURE_CLASS="fail:read-model"
    FAILURE_REASON="Recovery history did not include accepted and processed events"
    record_check "FAIL" "read_model history_event_count_lt_2 requestId=$request_id"
    return 1
  fi

  record_check "PASS" "read_model requestId=$request_id recent_status=$RECOVERY_RECENT_STATUS"
}

capture_db_evidence() {
  docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d compliancedb -Atc "
select 'outbox_pending=' || count(*) from masstransit.outbox_message
union all
select 'inbox_count=' || count(*) from masstransit.inbox_state
union all
select 'dispatch_record_count=' || count(*) from masstransit.dispatch_records;
" > "$EVIDENCE_DIR/db-counts.txt"

  docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d compliancedb -F',' -Atc "
select request_id, status, processed_at_utc, coalesce(message_id::text, ''), coalesce(error_code, '')
from compliance_ledger.events
where request_id in ('${BASELINE_REQUEST_ID}'::uuid, '${RECOVERY_REQUEST_ID}'::uuid)
order by request_id, processed_at_utc;
" > "$EVIDENCE_DIR/request-ledger.csv"
}

main() {
  preflight

  log "Starting DB restart verifier"
  if ! start_runtime; then
    return 1
  fi

  POSTGRES_CONTAINER="$(resolve_postgres_container || true)"
  if [[ -z "$POSTGRES_CONTAINER" ]]; then
    FAILURE_CLASS="fail:startup"
    FAILURE_REASON="PostgreSQL container was not found after startup"
    record_check "FAIL" "startup postgres_container_missing=true"
    return 1
  fi

  POSTGRES_USER="$(docker exec "$POSTGRES_CONTAINER" printenv POSTGRES_USER)"
  POSTGRES_PASSWORD="$(docker exec "$POSTGRES_CONTAINER" printenv POSTGRES_PASSWORD)"

  local baseline_content recovery_content
  baseline_content="db-restart-baseline-$STAMP"
  recovery_content="db-restart-recovery-$STAMP"

  BASELINE_REQUEST_ID="$(post_check "baseline" "$baseline_content")"
  if ! wait_for_request_status \
    "$BASELINE_REQUEST_ID" \
    "processed" \
    "$REQUEST_RECOVERY_WAIT_SECONDS" \
    "$EVIDENCE_DIR/baseline-status.json" \
    "$EVIDENCE_DIR/baseline-status.http"; then
    return 1
  fi
  record_check "PASS" "baseline_processed requestId=$BASELINE_REQUEST_ID"

  log "Stopping PostgreSQL container $POSTGRES_CONTAINER"
  if ! docker stop "$POSTGRES_CONTAINER" >/dev/null 2>&1; then
    FAILURE_CLASS="fail:postgres-stop"
    FAILURE_REASON="Failed to stop PostgreSQL container $POSTGRES_CONTAINER"
    record_check "FAIL" "postgres_stop container=$POSTGRES_CONTAINER"
    return 1
  fi

  sleep "$POSTGRES_OUTAGE_SECONDS"

  if ! wait_for_readiness_database_state "false" "$READINESS_OUTAGE_WAIT_SECONDS" "outage"; then
    return 1
  fi
  OUTAGE_READY_HTTP="$(cat "$EVIDENCE_DIR/outage-readiness.http")"
  if [[ "$OUTAGE_READY_HTTP" == "200" ]]; then
    OUTAGE_DATABASE_HEALTHY="$(jq -r '.databaseHealthy' "$EVIDENCE_DIR/outage-readiness.json" 2>/dev/null || true)"
  else
    OUTAGE_DATABASE_HEALTHY="unreachable"
  fi
  record_check "PASS" "outage_detected http=$OUTAGE_READY_HTTP databaseHealthy=$OUTAGE_DATABASE_HEALTHY"

  log "Restarting PostgreSQL container $POSTGRES_CONTAINER"
  if ! docker start "$POSTGRES_CONTAINER" >/dev/null 2>&1; then
    FAILURE_CLASS="fail:postgres-start"
    FAILURE_REASON="Failed to restart PostgreSQL container $POSTGRES_CONTAINER"
    record_check "FAIL" "postgres_start container=$POSTGRES_CONTAINER"
    return 1
  fi

  if ! wait_for_postgres_ready "$POSTGRES_CONTAINER" "$POSTGRES_USER" "$POSTGRES_PASSWORD" "$POSTGRES_READY_WAIT_SECONDS"; then
    FAILURE_CLASS="fail:postgres-start"
    FAILURE_REASON="PostgreSQL container restarted but was not ready in time"
    record_check "FAIL" "postgres_ready container=$POSTGRES_CONTAINER"
    return 1
  fi

  if ! wait_for_readiness_healthy "$READINESS_RECOVERY_WAIT_SECONDS" "recovery"; then
    return 1
  fi
  RECOVERY_DATABASE_HEALTHY="$(jq -r '.databaseHealthy' "$EVIDENCE_DIR/recovery-readiness.json" 2>/dev/null || true)"
  RECOVERY_BROKER_HEALTHY="$(jq -r '.brokerHealthy' "$EVIDENCE_DIR/recovery-readiness.json" 2>/dev/null || true)"
  record_check "PASS" "recovery_readiness databaseHealthy=$RECOVERY_DATABASE_HEALTHY brokerHealthy=$RECOVERY_BROKER_HEALTHY"

  RECOVERY_REQUEST_ID="$(post_check "recovery" "$recovery_content")"
  if ! wait_for_request_status \
    "$RECOVERY_REQUEST_ID" \
    "processed" \
    "$REQUEST_RECOVERY_WAIT_SECONDS" \
    "$EVIDENCE_DIR/recovery-status.json" \
    "$EVIDENCE_DIR/recovery-status.http"; then
    return 1
  fi
  RECOVERY_STATUS_VALUE="$(jq -r '.status // empty' "$EVIDENCE_DIR/recovery-status.json" 2>/dev/null || true)"
  record_check "PASS" "recovery_processed requestId=$RECOVERY_REQUEST_ID status=$RECOVERY_STATUS_VALUE"

  if ! capture_recovery_reads "$RECOVERY_REQUEST_ID"; then
    return 1
  fi

  capture_db_evidence

  RESULT="pass"
  FAILURE_CLASS="pass"
  FAILURE_REASON="all assertions passed"
  log "DB restart verifier passed"
}

main "$@"
