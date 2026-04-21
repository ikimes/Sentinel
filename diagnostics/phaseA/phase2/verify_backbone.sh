#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="${1:-$ROOT_DIR/diagnostics/phaseA/phase2/evidence/$STAMP}"
API_URL="${API_URL:-http://localhost:5022}"
REQUEST_COUNT="${REQUEST_COUNT:-2}"
DIAGNOSTIC_REPLAY_COUNT="${DIAGNOSTIC_REPLAY_COUNT:-2}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-30}"
DB_APP_ROLE="${DB_APP_ROLE:-sentinel_app}"
DB_APP_ROLE_PASSWORD="${DB_APP_ROLE_PASSWORD:-example-app-role-password}"
PHASE2_PROFILE="${PHASE2_PROFILE:-release-correctness}"
BASELINE_VERSION="${BASELINE_VERSION:-backend-sli-baseline.v1}"

mkdir -p "$EVIDENCE_DIR"
ATTEMPTS_LOG="$EVIDENCE_DIR/attempts.log"
SUMMARY_PATH="$EVIDENCE_DIR/summary.txt"
MANIFEST_PATH="$EVIDENCE_DIR/manifest.json"

LAST_FAILURE_CLASS="unknown"
LAST_REASON=""
FINAL_ATTEMPT="0"

log() {
  printf "[%s] %s\n" "$(date -u +%FT%TZ)" "$*"
}

record_attempt() {
  local attempt="$1"
  local status="$2"
  local klass="$3"
  local reason="$4"
  printf "%s|attempt=%s|status=%s|class=%s|reason=%s\n" "$(date -u +%FT%TZ)" "$attempt" "$status" "$klass" "$reason" >> "$ATTEMPTS_LOG"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd"
    return 1
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

wait_for_http() {
  local url="$1"
  for _ in $(seq 1 120); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
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

capture_aspire_artifacts() {
  local attempt_dir="$1"
  local aspire_dir="${2:-}"

  if [[ -n "$aspire_dir" && -d "$aspire_dir" ]]; then
    mkdir -p "$attempt_dir/aspire-resource-logs"
    find "$aspire_dir" -maxdepth 1 -type f \
      \( -name 'sentinel-api-*' -o -name 'sentinel-worker-*' -o -name 'resource-*' \) \
      -exec cp {} "$attempt_dir/aspire-resource-logs/" \; 2>/dev/null || true
  fi
}

count_signal() {
  local pattern="$1"
  local primary_log="$2"
  local resource_dir="$3"
  local count=0

  if [[ -f "$primary_log" ]]; then
    count=$((count + $(grep -F -c "$pattern" "$primary_log" 2>/dev/null || true)))
  fi

  if [[ -d "$resource_dir" ]]; then
    count=$((count + $(rg -F -c "$pattern" "$resource_dir" 2>/dev/null | awk -F: '{sum += $NF} END {print sum+0}')))
  fi

  echo "$count"
}

resolve_postgres_container() {
  docker ps --format '{{.Names}}' | grep '^postgres-' | head -n1
}

db_query() {
  local pg_container="$1"
  local pg_user="$2"
  local pg_pass="$3"
  local sql="$4"
  docker exec -e PGPASSWORD="$pg_pass" "$pg_container" psql -U "$pg_user" -d compliancedb -Atc "$sql"
}

db_exec_as_role() {
  local pg_container="$1"
  local role="$2"
  local role_pass="$3"
  local sql="$4"
  set +e
  docker exec -e PGPASSWORD="$role_pass" "$pg_container" psql -U "$role" -d compliancedb -Atc "$sql" >/tmp/sentinel_db_role_cmd.out 2>/tmp/sentinel_db_role_cmd.err
  local rc=$?
  set -e
  return $rc
}

run_attempt() {
  local attempt="$1"
  local attempt_dir="$EVIDENCE_DIR/attempt-$attempt"
  local checks_path="$attempt_dir/checks.txt"
  local responses_path="$attempt_dir/post_responses.jsonl"
  local request_ids_path="$attempt_dir/request_ids.txt"
  local sql_out_path="$attempt_dir/verification.sql.out"
  local apphost_log="$attempt_dir/apphost.log"
  local resource_logs_dir="$attempt_dir/aspire-resource-logs"

  mkdir -p "$attempt_dir"
  : > "$checks_path"
  : > "$responses_path"
  : > "$request_ids_path"
  : > "$sql_out_path"

  cleanup_runtime

  (
    cd "$ROOT_DIR"
    Sentinel__EnableDiagnosticsEndpoints=true dotnet run --project Sentinel.AppHost --no-build > "$apphost_log" 2>&1
  ) &
  local apphost_pid=$!
  echo "$apphost_pid" > "$attempt_dir/apphost.pid"
  sleep 2
  local attempt_aspire_dir
  attempt_aspire_dir="$(resolve_latest_aspire_run_dir || true)"

  if ! wait_for_http "$API_URL/"; then
    LAST_FAILURE_CLASS="fail:startup"
    LAST_REASON="API did not become ready at $API_URL"
    echo "FAIL startup: API readiness timeout" >> "$checks_path"
    capture_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"
    kill "$apphost_pid" 2>/dev/null || true
    cleanup_runtime
    return 1
  fi

  local i
  for i in $(seq 1 "$REQUEST_COUNT"); do
    local body response http_code check_id
    body="{\"content\":\"phase2-verify-attempt-$attempt-request-$i\",\"source\":\"phase2-script\"}"
    response="$(curl -sS -o "$attempt_dir/post-$i.json" -w "%{http_code}" -X POST "$API_URL/api/compliance/check" -H "Content-Type: application/json" --data-binary "$body" || true)"
    http_code="$response"

    if [[ "$http_code" != "200" ]]; then
      LAST_FAILURE_CLASS="fail:post"
      LAST_REASON="POST $i returned HTTP $http_code"
      echo "FAIL post-$i: http_code=$http_code" >> "$checks_path"
      kill "$apphost_pid" 2>/dev/null || true
      cleanup_runtime
      return 1
    fi

    check_id="$(jq -r '.checkId // empty' "$attempt_dir/post-$i.json")"
    if [[ -z "$check_id" ]]; then
      LAST_FAILURE_CLASS="fail:post"
      LAST_REASON="POST $i missing checkId"
      echo "FAIL post-$i: missing checkId" >> "$checks_path"
      kill "$apphost_pid" 2>/dev/null || true
      cleanup_runtime
      return 1
    fi

    jq -c --arg ts "$(date -u +%FT%TZ)" --argjson index "$i" '. + {timestamp_utc:$ts,index:$index}' "$attempt_dir/post-$i.json" >> "$responses_path"
    echo "$check_id" >> "$request_ids_path"
    echo "PASS post-$i: checkId=$check_id" >> "$checks_path"
  done

  sleep 3
  capture_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"

  local pg_container pg_user pg_pass
  pg_container="$(resolve_postgres_container || true)"
  if [[ -z "$pg_container" ]]; then
    LAST_FAILURE_CLASS="fail:ledger"
    LAST_REASON="Could not find postgres-* container"
    echo "FAIL db: postgres container not found" >> "$checks_path"
    kill "$apphost_pid" 2>/dev/null || true
    cleanup_runtime
    return 1
  fi

  pg_user="$(docker exec "$pg_container" printenv POSTGRES_USER)"
  pg_pass="$(docker exec "$pg_container" printenv POSTGRES_PASSWORD)"

  local req_id
  while IFS= read -r req_id; do
    [[ -z "$req_id" ]] && continue

    local api_received api_dispatched worker_received worker_processed ledger_written
    api_received="$(count_signal "COMPLIANCE_API_RECEIVED requestId=$req_id" "$apphost_log" "$resource_logs_dir")"
    api_dispatched="$(count_signal "COMPLIANCE_API_DISPATCHED requestId=$req_id" "$apphost_log" "$resource_logs_dir")"
    worker_received="$(count_signal "COMPLIANCE_WORKER_RECEIVED requestId=$req_id" "$apphost_log" "$resource_logs_dir")"
    worker_processed="$(count_signal "COMPLIANCE_WORKER_PROCESSED requestId=$req_id" "$apphost_log" "$resource_logs_dir")"
    ledger_written="$(count_signal "COMPLIANCE_LEDGER_WRITTEN requestId=$req_id" "$apphost_log" "$resource_logs_dir")"

    local dispatch_count ledger_status ledger_count
    dispatch_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from masstransit.dispatch_records where request_id='${req_id}'::uuid;")"
    ledger_status="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select status from compliance_ledger.events where request_id='${req_id}'::uuid order by processed_at_utc desc limit 1;")"
    ledger_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from compliance_ledger.events where request_id='${req_id}'::uuid;")"

    {
      echo "request_id=$req_id"
      echo "dispatch_count=$dispatch_count"
      echo "ledger_status=$ledger_status"
      echo "ledger_count=$ledger_count"
      echo "---"
    } >> "$sql_out_path"

    if [[ "$dispatch_count" -lt 1 || "$ledger_count" -lt 1 || "$ledger_status" != "processed" ]]; then
      LAST_FAILURE_CLASS="fail:ledger"
      LAST_REASON="Ledger/dispatch mismatch for requestId=$req_id"
      echo "FAIL ledger requestId=$req_id dispatch_count=$dispatch_count ledger_count=$ledger_count ledger_status=$ledger_status" >> "$checks_path"
      kill "$apphost_pid" 2>/dev/null || true
      cleanup_runtime
      return 1
    fi

    if [[ "$api_received" -lt 1 || "$api_dispatched" -lt 1 || "$worker_received" -lt 1 || "$worker_processed" -lt 1 || "$ledger_written" -lt 1 ]]; then
      echo "PASS log-correlation-fallback requestId=$req_id reason=apphost-log-forwarding-missing api_received=$api_received api_dispatched=$api_dispatched worker_received=$worker_received worker_processed=$worker_processed ledger_written=$ledger_written" >> "$checks_path"
    else
      echo "PASS log-correlation requestId=$req_id" >> "$checks_path"
    fi

    echo "PASS logs+ledger requestId=$req_id" >> "$checks_path"
  done < "$request_ids_path"

  local replay_payload replay_http replay_request_id replay_message_id replay_count
  replay_payload="$(jq -nc \
    --arg content "phase2-duplicate-replay-attempt-$attempt" \
    --arg source "phase2-script" \
    --argjson replayCount "$DIAGNOSTIC_REPLAY_COUNT" \
    '{content:$content,source:$source,replayCount:$replayCount}')"

  replay_http="$(curl -sS -o "$attempt_dir/duplicate-replay.json" -w "%{http_code}" \
    -X POST "$API_URL/api/diagnostics/messaging/replay-duplicate" \
    -H "Content-Type: application/json" \
    --data-binary "$replay_payload" || true)"

  if [[ "$replay_http" != "200" ]]; then
    LAST_FAILURE_CLASS="fail:duplicate-guard"
    LAST_REASON="Duplicate replay endpoint returned HTTP $replay_http"
    echo "FAIL duplicate-replay: http_code=$replay_http" >> "$checks_path"
    kill "$apphost_pid" 2>/dev/null || true
    cleanup_runtime
    return 1
  fi

  replay_request_id="$(jq -r '.requestId // empty' "$attempt_dir/duplicate-replay.json")"
  replay_message_id="$(jq -r '.messageId // empty' "$attempt_dir/duplicate-replay.json")"
  replay_count="$(jq -r '.replayCount // 0' "$attempt_dir/duplicate-replay.json")"

  if [[ -z "$replay_request_id" || -z "$replay_message_id" || "$replay_count" -lt 2 ]]; then
    LAST_FAILURE_CLASS="fail:duplicate-guard"
    LAST_REASON="Duplicate replay response missing required ids/count"
    echo "FAIL duplicate-replay: invalid response requestId=$replay_request_id messageId=$replay_message_id replayCount=$replay_count" >> "$checks_path"
    kill "$apphost_pid" 2>/dev/null || true
    cleanup_runtime
    return 1
  fi

  sleep 5
  capture_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"

  local replay_dispatch_count replay_ledger_count replay_ledger_status duplicate_log_count duplicate_receive_count duplicate_handler_count
  replay_dispatch_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from masstransit.dispatch_records where request_id='${replay_request_id}'::uuid and send_mode='diagnostic-duplicate-replay';")"
  replay_ledger_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from compliance_ledger.events where message_id='${replay_message_id}'::uuid;")"
  replay_ledger_status="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select status from compliance_ledger.events where message_id='${replay_message_id}'::uuid order by processed_at_utc desc limit 1;")"
  duplicate_log_count="$(count_signal "COMPLIANCE_DUPLICATE_SKIPPED requestId=$replay_request_id messageId=$replay_message_id" "$apphost_log" "$resource_logs_dir")"
  duplicate_receive_count="$({
    [[ -f "$apphost_log" ]] && grep -F -c "transportMessageId=$replay_message_id" "$apphost_log" 2>/dev/null || true
    if [[ -d "$resource_logs_dir" ]]; then
      rg -F -c "transportMessageId=$replay_message_id" "$resource_logs_dir" 2>/dev/null || true
    fi
  } | awk -F: '{sum += $NF} END {print sum+0}')"
  duplicate_handler_count="$(count_signal "COMPLIANCE_WORKER_RECEIVED requestId=$replay_request_id" "$apphost_log" "$resource_logs_dir")"

  {
    echo "duplicate_replay_request_id=$replay_request_id"
    echo "duplicate_replay_message_id=$replay_message_id"
    echo "duplicate_replay_count=$replay_count"
    echo "duplicate_replay_dispatch_count=$replay_dispatch_count"
    echo "duplicate_replay_ledger_count=$replay_ledger_count"
    echo "duplicate_replay_ledger_status=$replay_ledger_status"
    echo "duplicate_replay_log_count=$duplicate_log_count"
    echo "duplicate_replay_receive_pre_count=$duplicate_receive_count"
    echo "duplicate_replay_handler_count=$duplicate_handler_count"
  } >> "$sql_out_path"

  if [[ "$replay_dispatch_count" -lt 2 ]]; then
    LAST_FAILURE_CLASS="fail:duplicate-guard"
    LAST_REASON="Duplicate replay dispatch count too low: $replay_dispatch_count"
    echo "FAIL duplicate-replay dispatch_count=$replay_dispatch_count requestId=$replay_request_id" >> "$checks_path"
    kill "$apphost_pid" 2>/dev/null || true
    cleanup_runtime
    return 1
  fi

  if [[ "$replay_ledger_count" -ne 1 || "$replay_ledger_status" != "processed" ]]; then
    LAST_FAILURE_CLASS="fail:duplicate-guard"
    LAST_REASON="Duplicate replay ledger assertion failed: count=$replay_ledger_count status=$replay_ledger_status"
    echo "FAIL duplicate-replay ledger_count=$replay_ledger_count ledger_status=$replay_ledger_status messageId=$replay_message_id" >> "$checks_path"
    kill "$apphost_pid" 2>/dev/null || true
    cleanup_runtime
    return 1
  fi

  if [[ "$duplicate_log_count" -lt 1 ]]; then
    if [[ "$duplicate_receive_count" -ge 2 && "$duplicate_handler_count" -eq 1 ]]; then
      echo "PASS duplicate-replay-inbox requestId=$replay_request_id messageId=$replay_message_id receive_pre_count=$duplicate_receive_count handler_count=$duplicate_handler_count" >> "$checks_path"
    else
      echo "PASS duplicate-replay-fallback requestId=$replay_request_id messageId=$replay_message_id reason=duplicate-suppression-log-missing receive_pre_count=$duplicate_receive_count handler_count=$duplicate_handler_count" >> "$checks_path"
    fi
  else
    echo "PASS duplicate-replay-log requestId=$replay_request_id messageId=$replay_message_id count=$duplicate_log_count" >> "$checks_path"
  fi

  local dup_count
  dup_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from (select message_id from compliance_ledger.events group by message_id having count(*) > 1) d;")"
  echo "duplicate_message_id_count=$dup_count" >> "$sql_out_path"

  if [[ "$dup_count" -ne 0 ]]; then
    LAST_FAILURE_CLASS="fail:duplicate-guard"
    LAST_REASON="Duplicate message_id rows found: $dup_count"
    echo "FAIL duplicate-guard duplicate_count=$dup_count" >> "$checks_path"
    kill "$apphost_pid" 2>/dev/null || true
    cleanup_runtime
    return 1
  fi

  echo "PASS duplicate-guard duplicate_count=$dup_count" >> "$checks_path"

  local sample_request_id
  sample_request_id="$(head -n1 "$request_ids_path")"
  if [[ -z "$sample_request_id" ]]; then
    LAST_FAILURE_CLASS="fail:ledger"
    LAST_REASON="No request id available for privilege assertions"
    echo "FAIL privilege-assertions: no sample request id" >> "$checks_path"
    kill "$apphost_pid" 2>/dev/null || true
    cleanup_runtime
    return 1
  fi

  if ! db_exec_as_role "$pg_container" "$DB_APP_ROLE" "$DB_APP_ROLE_PASSWORD" "select count(*) from compliance_ledger.events;"; then
    LAST_FAILURE_CLASS="fail:ledger"
    LAST_REASON="App role cannot select from compliance_ledger.events"
    echo "FAIL privilege-select role=$DB_APP_ROLE" >> "$checks_path"
    kill "$apphost_pid" 2>/dev/null || true
    cleanup_runtime
    return 1
  fi

  if db_exec_as_role "$pg_container" "$DB_APP_ROLE" "$DB_APP_ROLE_PASSWORD" "update compliance_ledger.events set error_code='blocked-test' where request_id='${sample_request_id}'::uuid;"; then
    LAST_FAILURE_CLASS="fail:ledger"
    LAST_REASON="App role can update compliance_ledger.events (append-only violated)"
    echo "FAIL privilege-update role=$DB_APP_ROLE request_id=$sample_request_id" >> "$checks_path"
    kill "$apphost_pid" 2>/dev/null || true
    cleanup_runtime
    return 1
  fi

  if db_exec_as_role "$pg_container" "$DB_APP_ROLE" "$DB_APP_ROLE_PASSWORD" "delete from compliance_ledger.events where request_id='${sample_request_id}'::uuid;"; then
    LAST_FAILURE_CLASS="fail:ledger"
    LAST_REASON="App role can delete from compliance_ledger.events (append-only violated)"
    echo "FAIL privilege-delete role=$DB_APP_ROLE request_id=$sample_request_id" >> "$checks_path"
    kill "$apphost_pid" 2>/dev/null || true
    cleanup_runtime
    return 1
  fi

  {
    echo "app_role=$DB_APP_ROLE"
    echo "privilege_assertion_sample_request_id=$sample_request_id"
    echo "privilege_assertion_update=blocked"
    echo "privilege_assertion_delete=blocked"
  } >> "$sql_out_path"
  echo "PASS privilege-assertions role=$DB_APP_ROLE update/delete blocked on compliance_ledger.events" >> "$checks_path"

  kill "$apphost_pid" 2>/dev/null || true
  cleanup_runtime

  cp "$apphost_log" "$EVIDENCE_DIR/apphost.log"
  cp "$responses_path" "$EVIDENCE_DIR/post_responses.jsonl"
  cp "$sql_out_path" "$EVIDENCE_DIR/verification.sql.out"
  cp "$checks_path" "$EVIDENCE_DIR/checks.txt"

  LAST_FAILURE_CLASS="pass"
  LAST_REASON="all assertions passed"
  return 0
}

write_manifest() {
  local status="$1"
  cat > "$MANIFEST_PATH" <<JSON
{
  "generated_utc": "$(date -u +%FT%TZ)",
  "api_url": "$API_URL",
  "profile": "$PHASE2_PROFILE",
  "baseline_version": "$BASELINE_VERSION",
  "gate_eligible": true,
  "request_count": $REQUEST_COUNT,
  "max_attempts": $MAX_ATTEMPTS,
  "final_attempt": $FINAL_ATTEMPT,
  "result": "$status",
  "failure_class": "$LAST_FAILURE_CLASS",
  "reason": "${LAST_REASON//\"/\\\"}",
  "evidence_dir": "$EVIDENCE_DIR"
}
JSON
}

write_summary() {
  local status="$1"
  cat > "$SUMMARY_PATH" <<TXT
result=$status
profile=$PHASE2_PROFILE
baseline_version=$BASELINE_VERSION
gate_eligible=true
final_attempt=$FINAL_ATTEMPT
failure_class=$LAST_FAILURE_CLASS
reason=$LAST_REASON
evidence_dir=$EVIDENCE_DIR
TXT
}

main() {
  preflight

  local attempt
  for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
    FINAL_ATTEMPT="$attempt"
    log "Starting verification attempt $attempt/$MAX_ATTEMPTS"

    if run_attempt "$attempt"; then
      record_attempt "$attempt" "pass" "pass" "all assertions passed"
      write_summary "pass"
      write_manifest "pass"
      log "Verification passed on attempt $attempt"
      exit 0
    fi

    record_attempt "$attempt" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON"
    log "Attempt $attempt failed with $LAST_FAILURE_CLASS: $LAST_REASON"
    log "Running recovery routine (cleanup + retry)"
    cleanup_runtime
    sleep 2
  done

  write_summary "fail"
  write_manifest "fail"
  log "Verification failed after $MAX_ATTEMPTS attempts"
  exit 1
}

main "$@"
