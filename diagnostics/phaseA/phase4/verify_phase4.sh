#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="${1:-$ROOT_DIR/diagnostics/phaseA/phase4/evidence/$STAMP}"
API_URL="${API_URL:-http://localhost:5022}"
PHASE4_MODE="${PHASE4_MODE:-release}"
PHASE4_PROFILE="${PHASE4_PROFILE:-}"
ORCHESTRATION_MODE="${ORCHESTRATION_MODE:-apphost}"
BASELINE_FILE="${BASELINE_FILE:-$ROOT_DIR/diagnostics/baselines/backend-sli-baseline.v1.json}"
LOAD_REQUEST_COUNT="${LOAD_REQUEST_COUNT:-24}"
LOAD_CONCURRENCY="${LOAD_CONCURRENCY:-6}"
BACKLOG_REQUEST_COUNT="${BACKLOG_REQUEST_COUNT:-48}"
BACKLOG_CONCURRENCY="${BACKLOG_CONCURRENCY:-12}"
STRESS_REQUEST_COUNT="${STRESS_REQUEST_COUNT:-96}"
STRESS_CONCURRENCY="${STRESS_CONCURRENCY:-24}"
SOAK_SECONDS="${SOAK_SECONDS:-20}"
CHAOS_BROKER_STOP_SECONDS="${CHAOS_BROKER_STOP_SECONDS:-8}"
QUEUE_SAMPLE_INTERVAL_SECONDS="${QUEUE_SAMPLE_INTERVAL_SECONDS:-1}"
STRICT_STARTUP_WAIT_SECONDS="${STRICT_STARTUP_WAIT_SECONDS:-90}"
STRICT_WORKER_WAIT_SECONDS="${STRICT_WORKER_WAIT_SECONDS:-120}"
DIRECT_RABBIT_USER="${DIRECT_RABBIT_USER:-diag}"
DIRECT_RABBIT_PASS="${DIRECT_RABBIT_PASS:-example-rabbit-password}"
DIRECT_PG_USER="${DIRECT_PG_USER:-postgres}"
DIRECT_PG_PASS="${DIRECT_PG_PASS:-example-postgres-password}"
DIRECT_DB="${DIRECT_DB:-compliancedb}"

MAX_ACCEPTABLE_FAILURE_RATE="${MAX_ACCEPTABLE_FAILURE_RATE:-}"
P95_LEDGER_LATENCY_MS="${P95_LEDGER_LATENCY_MS:-}"
P99_LEDGER_LATENCY_MS="${P99_LEDGER_LATENCY_MS:-}"
MAX_QUEUE_DEPTH="${MAX_QUEUE_DEPTH:-}"
MAX_DRAIN_SECONDS="${MAX_DRAIN_SECONDS:-}"
MAX_OUTAGE_RECOVERY_SECONDS="${MAX_OUTAGE_RECOVERY_SECONDS:-}"
MAX_RECOVERY_SECONDS="${MAX_RECOVERY_SECONDS:-120}"
TERMINAL_FAILURE_ROWS_EXACT="${TERMINAL_FAILURE_ROWS_EXACT:-}"

ATTEMPTS_LOG="$EVIDENCE_DIR/attempts.log"
SUMMARY_PATH="$EVIDENCE_DIR/summary.txt"
MANIFEST_PATH="$EVIDENCE_DIR/manifest.json"
CHECKS_PATH="$EVIDENCE_DIR/checks.txt"
LOAD_SAMPLES_PATH="$EVIDENCE_DIR/load_samples.csv"
LATENCY_SUMMARY_PATH="$EVIDENCE_DIR/latency_summary.json"
LATENCY_BREAKDOWN_SUMMARY_PATH="$EVIDENCE_DIR/latency_breakdown_summary.json"
QUEUE_TIMELINE_PATH="$EVIDENCE_DIR/queue_depth_timeline.csv"
RABBITMQ_TIMELINE_PATH="$EVIDENCE_DIR/rabbitmq_timeline.csv"
PERSISTENCE_TIMELINE_PATH="$EVIDENCE_DIR/persistence_timeline.csv"
DRAIN_TIMELINE_PATH="$EVIDENCE_DIR/drain_timeline.csv"
FAILURE_SUMMARY_PATH="$EVIDENCE_DIR/failure_injection_summary.txt"
CHAOS_CLASSIFICATION_PATH="$EVIDENCE_DIR/chaos_load_classification.csv"
PROFILE_RESULTS_PATH="$EVIDENCE_DIR/profile_results.jsonl"
SQL_OUT_PATH="$EVIDENCE_DIR/verification.sql.out"

LAST_FAILURE_CLASS="unknown"
LAST_REASON=""
ATTEMPT_API_URL="$API_URL"
ATTEMPT_STARTUP_MODE="aspire"
ATTEMPT_GATE_ELIGIBLE="true"
ATTEMPT_API_LOG=""
ATTEMPT_WORKER_LOG=""
ACTIVE_RABBIT_CONTAINER=""
ACTIVE_PG_CONTAINER=""
DIRECT_RABBIT_URI=""
DIRECT_PG_CONN=""
QUEUE_SAMPLER_PID=""
BASELINE_VERSION="backend-sli-baseline.v1"
BASELINE_ENVIRONMENT="local-aspire-single-node"
PROFILE_LABEL="release-suite"

mkdir -p "$EVIDENCE_DIR"
: > "$ATTEMPTS_LOG"
: > "$CHECKS_PATH"
: > "$SQL_OUT_PATH"
: > "$FAILURE_SUMMARY_PATH"
: > "$PROFILE_RESULTS_PATH"

log() {
  printf "[%s] %s\n" "$(date -u +%FT%TZ)" "$*"
}

record_attempt() {
  local status="$1"
  local klass="$2"
  local reason="$3"
  printf "%s|status=%s|class=%s|reason=%s\n" "$(date -u +%FT%TZ)" "$status" "$klass" "$reason" >> "$ATTEMPTS_LOG"
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
  require_cmd python3
  docker info >/dev/null
}

load_baseline() {
  if [[ -f "$BASELINE_FILE" ]]; then
    BASELINE_VERSION="$(jq -r '.baseline_version // "backend-sli-baseline.v1"' "$BASELINE_FILE")"
    BASELINE_ENVIRONMENT="$(jq -r '.environment // "local-aspire-single-node"' "$BASELINE_FILE")"

    [[ -n "$MAX_ACCEPTABLE_FAILURE_RATE" ]] || MAX_ACCEPTABLE_FAILURE_RATE="$(jq -r '.thresholds.max_acceptable_failure_rate // 0' "$BASELINE_FILE")"
    [[ -n "$P95_LEDGER_LATENCY_MS" ]] || P95_LEDGER_LATENCY_MS="$(jq -r '.thresholds.bounded_load_p95_latency_ms // 1000' "$BASELINE_FILE")"
    [[ -n "$P99_LEDGER_LATENCY_MS" ]] || P99_LEDGER_LATENCY_MS="$(jq -r '.thresholds.bounded_load_p99_latency_ms // 2000' "$BASELINE_FILE")"
    [[ -n "$MAX_QUEUE_DEPTH" ]] || MAX_QUEUE_DEPTH="$(jq -r '.thresholds.max_queue_depth_release // 50' "$BASELINE_FILE")"
    [[ -n "$MAX_DRAIN_SECONDS" ]] || MAX_DRAIN_SECONDS="$(jq -r '.thresholds.backlog_drain_seconds // 30' "$BASELINE_FILE")"
    [[ -n "$MAX_OUTAGE_RECOVERY_SECONDS" ]] || MAX_OUTAGE_RECOVERY_SECONDS="$(jq -r '.thresholds.outage_recovery_seconds // 60' "$BASELINE_FILE")"
    [[ -n "$TERMINAL_FAILURE_ROWS_EXACT" ]] || TERMINAL_FAILURE_ROWS_EXACT="$(jq -r '.thresholds.terminal_failure_rows_exact // 1' "$BASELINE_FILE")"
  fi

  : "${MAX_ACCEPTABLE_FAILURE_RATE:=0.0}"
  : "${P95_LEDGER_LATENCY_MS:=1000}"
  : "${P99_LEDGER_LATENCY_MS:=2000}"
  : "${MAX_QUEUE_DEPTH:=50}"
  : "${MAX_DRAIN_SECONDS:=30}"
  : "${MAX_OUTAGE_RECOVERY_SECONDS:=60}"
  : "${TERMINAL_FAILURE_ROWS_EXACT:=1}"
}

cleanup_runtime() {
  pkill -f "Sentinel.AppHost" 2>/dev/null || true
  pkill -f "Sentinel.Api" 2>/dev/null || true
  pkill -f "Sentinel.Worker" 2>/dev/null || true
  pkill -f "dotnet run --project $ROOT_DIR/Sentinel" 2>/dev/null || true
  if [[ -n "${ACTIVE_RABBIT_CONTAINER:-}" ]]; then
    docker rm -f "$ACTIVE_RABBIT_CONTAINER" >/dev/null 2>&1 || true
    ACTIVE_RABBIT_CONTAINER=""
  fi
  if [[ -n "${ACTIVE_PG_CONTAINER:-}" ]]; then
    docker rm -f "$ACTIVE_PG_CONTAINER" >/dev/null 2>&1 || true
    ACTIVE_PG_CONTAINER=""
  fi
  ATTEMPT_API_LOG=""
  ATTEMPT_WORKER_LOG=""
  sleep 2
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

wait_for_worker_ready() {
  local max_seconds="$1"
  for _ in $(seq 1 "$max_seconds"); do
    if [[ "$ORCHESTRATION_MODE" == "direct" ]]; then
      if [[ -f "$EVIDENCE_DIR/worker-direct.pid" ]]; then
        local worker_pid
        worker_pid="$(cat "$EVIDENCE_DIR/worker-direct.pid" 2>/dev/null || true)"
        if [[ -n "$worker_pid" ]] && kill -0 "$worker_pid" 2>/dev/null; then
          return 0
        fi
      fi
    fi
    if pgrep -fal "/Sentinel.Worker/bin/" >/dev/null 2>&1; then
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
  local aspire_dir="${1:-}"
  if [[ -n "$aspire_dir" && -d "$aspire_dir" ]]; then
    mkdir -p "$EVIDENCE_DIR/aspire-resource-logs"
    find "$aspire_dir" -maxdepth 1 -type f \
      \( -name 'sentinel-api-*' -o -name 'sentinel-worker-*' -o -name 'resource-*' \) \
      -exec cp {} "$EVIDENCE_DIR/aspire-resource-logs/" \; 2>/dev/null || true
  fi
}

capture_live_aspire_artifacts() {
  local aspire_dir_hint="${1:-}"
  local live_dir
  live_dir="$(resolve_latest_aspire_run_dir || true)"
  if [[ -n "$live_dir" ]]; then
    capture_aspire_artifacts "$live_dir"
  else
    capture_aspire_artifacts "$aspire_dir_hint"
  fi
}

resolve_container_port() {
  local container="$1"
  local internal_port="$2"
  docker port "$container" "$internal_port" | head -n1 | awk -F: '{print $NF}'
}

resolve_rabbit_image_tag() {
  local tag="${Sentinel__RabbitImageTag:-4.2-management}"
  [[ -n "$tag" ]] || tag="4.2-management"
  echo "$tag"
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

wait_for_rabbit_ready() {
  local rabbit_container="$1"
  local max_seconds="$2"
  for _ in $(seq 1 "$max_seconds"); do
    if docker exec "$rabbit_container" rabbitmq-diagnostics -q ping >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

resolve_postgres_container() {
  if [[ -n "${ACTIVE_PG_CONTAINER:-}" ]] && docker ps --format '{{.Names}}' | grep -Fxq "$ACTIVE_PG_CONTAINER"; then
    echo "$ACTIVE_PG_CONTAINER"
    return
  fi
  docker ps --format '{{.Names}}' | grep '^postgres-' | head -n1
}

resolve_rabbit_container() {
  if [[ -n "${ACTIVE_RABBIT_CONTAINER:-}" ]] && docker ps --format '{{.Names}}' | grep -Fxq "$ACTIVE_RABBIT_CONTAINER"; then
    echo "$ACTIVE_RABBIT_CONTAINER"
    return
  fi
  docker ps --format '{{.Names}}' | grep '^messaging-' | head -n1
}

db_query() {
  local pg_container="$1"
  local pg_user="$2"
  local pg_pass="$3"
  local sql="$4"
  docker exec -e PGPASSWORD="$pg_pass" "$pg_container" psql -U "$pg_user" -d compliancedb -Atc "$sql"
}

stop_pid_if_running() {
  local pid="${1:-}"
  [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
}

start_direct_infra() {
  local rabbit_tag safe_tag suffix rabbit_port pg_port
  rabbit_tag="$(resolve_rabbit_image_tag)"
  safe_tag="$(echo "$rabbit_tag" | tr '.:' '__')"
  suffix="$(date -u +%s)-$RANDOM"

  ACTIVE_RABBIT_CONTAINER="sentinel-phase4-rabbit-${safe_tag}-${suffix}"
  ACTIVE_PG_CONTAINER="sentinel-phase4-pg-${suffix}"

  docker rm -f "$ACTIVE_RABBIT_CONTAINER" "$ACTIVE_PG_CONTAINER" >/dev/null 2>&1 || true

  if ! docker run -d --name "$ACTIVE_RABBIT_CONTAINER" \
    -e RABBITMQ_DEFAULT_USER="$DIRECT_RABBIT_USER" \
    -e RABBITMQ_DEFAULT_PASS="$DIRECT_RABBIT_PASS" \
    -p 0:5672 -p 0:15672 "rabbitmq:${rabbit_tag}" >/dev/null; then
    LAST_FAILURE_CLASS="fail:startup"
    LAST_REASON="Direct mode: failed to start RabbitMQ container"
    return 1
  fi

  if ! docker run -d --name "$ACTIVE_PG_CONTAINER" \
    -e POSTGRES_USER="$DIRECT_PG_USER" \
    -e POSTGRES_PASSWORD="$DIRECT_PG_PASS" \
    -e POSTGRES_DB="$DIRECT_DB" \
    -p 0:5432 postgres:17.6 >/dev/null; then
    LAST_FAILURE_CLASS="fail:startup"
    LAST_REASON="Direct mode: failed to start Postgres container"
    return 1
  fi

  if ! wait_for_postgres_ready "$ACTIVE_PG_CONTAINER" "$DIRECT_PG_USER" "$DIRECT_PG_PASS" 90; then
    LAST_FAILURE_CLASS="fail:startup"
    LAST_REASON="Direct mode: Postgres did not become ready"
    return 1
  fi

  if ! wait_for_rabbit_ready "$ACTIVE_RABBIT_CONTAINER" 90; then
    LAST_FAILURE_CLASS="fail:startup"
    LAST_REASON="Direct mode: RabbitMQ did not become ready"
    return 1
  fi

  rabbit_port="$(resolve_container_port "$ACTIVE_RABBIT_CONTAINER" "5672/tcp")"
  pg_port="$(resolve_container_port "$ACTIVE_PG_CONTAINER" "5432/tcp")"
  DIRECT_RABBIT_URI="amqp://${DIRECT_RABBIT_USER}:${DIRECT_RABBIT_PASS}@localhost:${rabbit_port}/"
  DIRECT_PG_CONN="Host=localhost;Port=${pg_port};Database=${DIRECT_DB};Username=${DIRECT_PG_USER};Password=${DIRECT_PG_PASS}"
  return 0
}

determine_gate_eligibility() {
  if [[ "$PHASE4_MODE" != "release" ]]; then
    ATTEMPT_GATE_ELIGIBLE="false"
    return
  fi

  if [[ -z "$PHASE4_PROFILE" ]]; then
    ATTEMPT_GATE_ELIGIBLE="true"
    return
  fi

  case "$PHASE4_PROFILE" in
    release-bounded-load|release-backlog-recovery|release-terminal-failure) ATTEMPT_GATE_ELIGIBLE="true" ;;
    *) ATTEMPT_GATE_ELIGIBLE="false" ;;
  esac
}

start_runtime() {
  cleanup_runtime
  determine_gate_eligibility
  local apphost_pid=""
  local aspire_dir=""

  if [[ "$ORCHESTRATION_MODE" == "apphost" ]]; then
    (
      cd "$ROOT_DIR"
      Sentinel__EnableDiagnosticsEndpoints=true dotnet run --project Sentinel.AppHost --no-build > "$EVIDENCE_DIR/apphost.log" 2>&1
    ) &
    apphost_pid=$!
    echo "$apphost_pid" > "$EVIDENCE_DIR/apphost.pid"
    ATTEMPT_STARTUP_MODE="aspire"
    sleep 2
    aspire_dir="$(resolve_latest_aspire_run_dir || true)"
  else
    ATTEMPT_API_LOG="$EVIDENCE_DIR/api-direct.log"
    ATTEMPT_WORKER_LOG="$EVIDENCE_DIR/worker-direct.log"
    ATTEMPT_STARTUP_MODE="direct"

    if ! start_direct_infra; then
      return 1
    fi

    (
      cd "$ROOT_DIR"
      ConnectionStrings__messaging="$DIRECT_RABBIT_URI" \
        ConnectionStrings__compliancedb="$DIRECT_PG_CONN" \
        ConnectionStrings__compliancedb_admin="$DIRECT_PG_CONN" \
        Sentinel__DbAppRole="sentinel_app" \
        Sentinel__DbAppRolePassword="example-app-role-password" \
        dotnet run --project Sentinel.Worker --no-build --no-launch-profile > "$ATTEMPT_WORKER_LOG" 2>&1
    ) &
    echo "$!" > "$EVIDENCE_DIR/worker-direct.pid"

    (
      cd "$ROOT_DIR"
      ASPNETCORE_URLS="$ATTEMPT_API_URL" \
        ConnectionStrings__messaging="$DIRECT_RABBIT_URI" \
        ConnectionStrings__compliancedb="$DIRECT_PG_CONN" \
        ConnectionStrings__compliancedb_admin="$DIRECT_PG_CONN" \
        Sentinel__DbAppRole="sentinel_app" \
        Sentinel__DbAppRolePassword="example-app-role-password" \
        Sentinel__EnableDiagnosticsEndpoints="true" \
        dotnet run --project Sentinel.Api --no-build --no-launch-profile > "$ATTEMPT_API_LOG" 2>&1
    ) &
    echo "$!" > "$EVIDENCE_DIR/api-direct.pid"
  fi

  if ! wait_for_api_ready "$ATTEMPT_API_URL" "$STRICT_STARTUP_WAIT_SECONDS"; then
    capture_live_aspire_artifacts "$aspire_dir"
    LAST_FAILURE_CLASS="fail:startup"
    LAST_REASON="API did not become ready at $ATTEMPT_API_URL"
    stop_pid_if_running "$apphost_pid"
    cleanup_runtime
    return 1
  fi

  if ! wait_for_worker_ready "$STRICT_WORKER_WAIT_SECONDS"; then
    capture_live_aspire_artifacts "$aspire_dir"
    LAST_FAILURE_CLASS="fail:startup"
    LAST_REASON="Worker did not become ready"
    stop_pid_if_running "$apphost_pid"
    cleanup_runtime
    return 1
  fi

  capture_live_aspire_artifacts "$aspire_dir"
  return 0
}

run_single_post() {
  local scenario="$1"
  local idx="$2"
  local source="$3"
  local content_prefix="$4"
  local out_path="$EVIDENCE_DIR/${scenario}-response-${idx}.json"
  local body http_code check_id status

  body="{\"content\":\"${content_prefix}-${idx}\",\"source\":\"${source}\"}"
  http_code="$(curl -sS --max-time 20 -o "$EVIDENCE_DIR/${scenario}-post-${idx}.json" -w "%{http_code}" \
    -X POST "$ATTEMPT_API_URL/api/compliance/check" \
    -H "Content-Type: application/json" \
    --data-binary "$body" || true)"

  check_id="$(jq -r '.checkId // empty' "$EVIDENCE_DIR/${scenario}-post-${idx}.json" 2>/dev/null || true)"
  if [[ "$http_code" == "200" && -n "$check_id" ]]; then
    status="accepted"
  else
    status="http-failure"
  fi

  jq -nc \
    --arg scenario "$scenario" \
    --argjson index "$idx" \
    --arg httpCode "$http_code" \
    --arg checkId "$check_id" \
    --arg status "$status" \
    --arg utc "$(python3 - <<'PY'
from datetime import datetime, timezone
print(datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z"))
PY
)" \
    '{scenario:$scenario,index:$index,httpCode:$httpCode,checkId:$checkId,status:$status,accepted_utc:$utc}' > "$out_path"
}

init_scenario_request_artifacts() {
  local scenario="$1"
  rm -f "$EVIDENCE_DIR/${scenario}-response-"*.json "$EVIDENCE_DIR/${scenario}-post-"*.json 2>/dev/null || true
  : > "$EVIDENCE_DIR/${scenario}-responses.jsonl"
}

append_request_batch() {
  local scenario="$1"
  local start_idx="$2"
  local count="$3"
  local concurrency="$4"
  local source="$5"
  local content_prefix="$6"
  local responses_path="$EVIDENCE_DIR/${scenario}-responses.jsonl"
  local -a request_pids=()
  local -a request_ids=()

  local offset idx
  for offset in $(seq 0 $((count - 1))); do
    idx=$((start_idx + offset))
    run_single_post "$scenario" "$idx" "$source" "$content_prefix" &
    request_pids+=("$!")
    request_ids+=("$idx")

    while :; do
      local active_requests=0
      local pid
      for pid in "${request_pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
          active_requests=$((active_requests + 1))
        fi
      done

      if [[ "$active_requests" -lt "$concurrency" ]]; then
        break
      fi
      sleep 0.2
    done
  done

  local pid
  for pid in "${request_pids[@]}"; do
    wait "$pid"
  done

  local idx_value out_path
  for idx_value in "${request_ids[@]}"; do
    out_path="$EVIDENCE_DIR/${scenario}-response-${idx_value}.json"
    if [[ ! -f "$out_path" ]]; then
      LAST_FAILURE_CLASS="fail:load-http"
      LAST_REASON="Missing response artifact for scenario=$scenario index=$idx_value"
      return 1
    fi
    jq -c '.' "$out_path" >> "$responses_path"
  done
}

request_ids_to_sql_array() {
  local request_ids_path="$1"
  awk 'NF {printf "%s'\''%s'\''::uuid", sep, $0; sep=","}' "$request_ids_path"
}

is_numeric() {
  local value="${1:-}"
  [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

extract_queue_line() {
  local listing="$1"
  local queue_name="$2"
  printf '%s\n' "$listing" | awk -v q="$queue_name" '$1==q {print $0; exit}'
}

extract_queue_field() {
  local line="$1"
  local column="$2"
  if [[ -z "$line" ]]; then
    echo "0"
    return
  fi
  echo "$line" | awk -v col="$column" '{print $col}'
}

capture_rabbitmq_snapshot() {
  local label="$1"
  local rabbit_container="$2"
  {
    docker exec "$rabbit_container" rabbitmq-diagnostics -q ping 2>&1 || true
  } > "$EVIDENCE_DIR/rabbitmq-${label}-ping.txt"
  {
    docker exec "$rabbit_container" rabbitmqctl list_queues name messages messages_ready messages_unacknowledged consumers consumer_capacity 2>&1 || true
  } > "$EVIDENCE_DIR/rabbitmq-${label}-queues.txt"
  {
    docker exec "$rabbit_container" rabbitmqctl list_connections name state channels recv_oct send_oct 2>&1 || true
  } > "$EVIDENCE_DIR/rabbitmq-${label}-connections.txt"
  {
    docker exec "$rabbit_container" rabbitmqctl list_channels connection name number consumer_count messages_unacknowledged 2>&1 || true
  } > "$EVIDENCE_DIR/rabbitmq-${label}-channels.txt"
}

append_queue_sample() {
  local scenario="$1"
  local source_filter="$2"
  local pg_container="$3"
  local pg_user="$4"
  local pg_pass="$5"
  local rabbit_container="$6"

  local queue_listing compliance_line error_line
  local compliance_messages compliance_ready compliance_unacked compliance_consumers compliance_capacity
  local error_messages outbox_pending inbox_count dispatch_count ledger_count

  queue_listing="$(docker exec "$rabbit_container" rabbitmqctl list_queues -q name messages messages_ready messages_unacknowledged consumers consumer_capacity 2>/dev/null || true)"
  compliance_line="$(extract_queue_line "$queue_listing" "compliance")"
  error_line="$(extract_queue_line "$queue_listing" "compliance_error")"

  compliance_messages="$(extract_queue_field "$compliance_line" 2)"
  compliance_ready="$(extract_queue_field "$compliance_line" 3)"
  compliance_unacked="$(extract_queue_field "$compliance_line" 4)"
  compliance_consumers="$(extract_queue_field "$compliance_line" 5)"
  compliance_capacity="$(extract_queue_field "$compliance_line" 6)"
  error_messages="$(extract_queue_field "$error_line" 2)"
  outbox_pending="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from masstransit.outbox_message;" 2>/dev/null || echo 0)"
  inbox_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from masstransit.inbox_state;" 2>/dev/null || echo 0)"
  dispatch_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from masstransit.dispatch_records;" 2>/dev/null || echo 0)"
  if [[ -n "$source_filter" ]]; then
    ledger_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from compliance_ledger.events where source = '${source_filter}';" 2>/dev/null || echo 0)"
  else
    ledger_count="0"
  fi

  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$(date -u +%FT%TZ)" "$scenario" "$compliance_messages" "$compliance_ready" "$compliance_unacked" "$error_messages" \
    "$outbox_pending" "$inbox_count" "$dispatch_count" >> "$QUEUE_TIMELINE_PATH"

  [[ -n "$compliance_capacity" ]] || compliance_capacity="metric_unavailable"
  printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$(date -u +%FT%TZ)" "$scenario" "$compliance_messages" "$compliance_ready" "$compliance_unacked" \
    "$compliance_consumers" "$compliance_capacity" "$error_messages" >> "$RABBITMQ_TIMELINE_PATH"

  printf '%s,%s,%s,%s,%s,%s,%s\n' \
    "$(date -u +%FT%TZ)" "$scenario" "$source_filter" "$outbox_pending" "$inbox_count" "$dispatch_count" "$ledger_count" >> "$PERSISTENCE_TIMELINE_PATH"
}

start_queue_sampler() {
  local scenario="$1"
  local source_filter="$2"
  local stop_flag="$3"
  local pg_container="$4"
  local pg_user="$5"
  local pg_pass="$6"
  local rabbit_container="$7"

  (
    while [[ ! -f "$stop_flag" ]]; do
      append_queue_sample "$scenario" "$source_filter" "$pg_container" "$pg_user" "$pg_pass" "$rabbit_container"
      sleep "$QUEUE_SAMPLE_INTERVAL_SECONDS"
    done
  ) &
  QUEUE_SAMPLER_PID="$!"
}

stop_queue_sampler() {
  local stop_flag="$1"
  touch "$stop_flag"
  wait "${QUEUE_SAMPLER_PID:-}" || true
  QUEUE_SAMPLER_PID=""
}

wait_for_processed_requests() {
  local request_ids_path="$1"
  local max_seconds="$2"
  local pg_container="$3"
  local pg_user="$4"
  local pg_pass="$5"
  local expected array_sql processed_count

  expected="$(wc -l < "$request_ids_path" | tr -d ' ')"
  array_sql="$(request_ids_to_sql_array "$request_ids_path")"
  if [[ -z "$array_sql" ]]; then
    echo "0"
    return 1
  fi

  for _ in $(seq 1 "$max_seconds"); do
    processed_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from compliance_ledger.events where request_id = any(array[$array_sql]) and status='processed';")"
    if [[ "$processed_count" -ge "$expected" ]]; then
      echo "$processed_count"
      return 0
    fi
    sleep 1
  done

  echo "${processed_count:-0}"
  return 1
}

export_request_metrics() {
  local scenario="$1"
  local request_ids_path="$2"
  local scenario_csv="$EVIDENCE_DIR/${scenario}-samples.csv"
  local pg_container="$3"
  local pg_user="$4"
  local pg_pass="$5"
  local array_sql

  array_sql="$(request_ids_to_sql_array "$request_ids_path")"
  if [[ -z "$array_sql" ]]; then
    return 1
  fi

  docker exec -e PGPASSWORD="$pg_pass" "$pg_container" psql -U "$pg_user" -d compliancedb -c "\copy (
    select
      '$scenario' as scenario,
      d.request_id,
      d.send_mode,
      d.created_at_utc as dispatch_created_at_utc,
      e.processed_at_utc,
      coalesce(e.status, 'missing') as ledger_status,
      coalesce(round(extract(epoch from (e.processed_at_utc - d.created_at_utc)) * 1000.0, 3), 0) as ledger_latency_ms,
      coalesce(e.message_id::text, 'missing') as message_id,
      coalesce(e.handler_duration_ms, 0) as handler_duration_ms
    from masstransit.dispatch_records d
    left join compliance_ledger.events e on e.request_id = d.request_id
    where d.request_id = any(array[$array_sql])
    order by d.created_at_utc
  ) to stdout with csv header" > "$scenario_csv"

  if [[ ! -f "$LOAD_SAMPLES_PATH" ]]; then
    cp "$scenario_csv" "$LOAD_SAMPLES_PATH"
  else
    tail -n +2 "$scenario_csv" >> "$LOAD_SAMPLES_PATH"
  fi
}

compute_latency_metrics() {
  local csv_path="$1"
  python3 - "$csv_path" <<'PY'
import csv, json, sys

def percentile(values, pct):
    if not values:
        return 0.0
    values = sorted(values)
    if len(values) == 1:
        return float(values[0])
    rank = (len(values) - 1) * pct
    lower = int(rank)
    upper = min(lower + 1, len(values) - 1)
    weight = rank - lower
    return round(values[lower] * (1 - weight) + values[upper] * weight, 3)

latencies = []
with open(sys.argv[1], newline="") as handle:
    for row in csv.DictReader(handle):
        if row["ledger_status"] == "processed":
            latencies.append(float(row["ledger_latency_ms"]))

summary = {
    "count": len(latencies),
    "p50": percentile(latencies, 0.50),
    "p95": percentile(latencies, 0.95),
    "p99": percentile(latencies, 0.99),
    "max": round(max(latencies), 3) if latencies else 0.0,
}
print(json.dumps(summary))
PY
}

compute_latency_breakdown() {
  local scenario="$1"
  local responses_path="$2"
  local samples_csv="$3"
  local output_path="$EVIDENCE_DIR/${scenario}-latency-breakdown.json"

  python3 - "$scenario" "$responses_path" "$samples_csv" "$output_path" <<'PY'
import csv, json, math, re, sys
from datetime import datetime


def percentile(values, pct):
    if not values:
        return 0.0
    values = sorted(values)
    if len(values) == 1:
        return round(float(values[0]), 3)
    rank = (len(values) - 1) * pct
    lower = int(math.floor(rank))
    upper = min(lower + 1, len(values) - 1)
    weight = rank - lower
    return round(values[lower] * (1 - weight) + values[upper] * weight, 3)


def summarize(values):
    return {
        "count": len(values),
        "p50": percentile(values, 0.50),
        "p95": percentile(values, 0.95),
        "p99": percentile(values, 0.99),
        "max": round(max(values), 3) if values else 0.0,
        "avg": round(sum(values) / len(values), 3) if values else 0.0,
    }


def parse_ts(raw):
    normalized = raw.strip().replace("Z", "+00:00")
    if normalized.endswith("+00"):
        normalized = normalized[:-3] + "+00:00"
    if " " in normalized and "T" not in normalized:
        normalized = normalized.replace(" ", "T", 1)
    match = re.match(r"^(.*?\.\d+)([+-]\d{2}:\d{2})$", normalized)
    if match:
        fraction = match.group(1).split(".")[-1]
        normalized = normalized[: normalized.rfind(".") + 1] + fraction.ljust(6, "0")[:6] + match.group(2)
    return datetime.fromisoformat(normalized)


scenario = sys.argv[1]
responses_path = sys.argv[2]
samples_csv = sys.argv[3]
output_path = sys.argv[4]

responses = {}
with open(responses_path, encoding="ascii") as handle:
    for line in handle:
        line = line.strip()
        if not line:
            continue
        row = json.loads(line)
        check_id = row.get("checkId")
        accepted_utc = row.get("accepted_utc")
        if check_id and accepted_utc:
            responses[check_id] = row

api_to_dispatch = []
dispatch_to_ledger = []
handler_duration = []
queue_processing_gap = []
accepted_to_processed = []

with open(samples_csv, newline="", encoding="ascii") as handle:
    for row in csv.DictReader(handle):
        if row.get("ledger_status") != "processed":
            continue
        request_id = row.get("request_id")
        response = responses.get(request_id)
        if not response:
            continue

        accepted_at = parse_ts(response["accepted_utc"])
        dispatch_at = parse_ts(row["dispatch_created_at_utc"])
        processed_at = parse_ts(row["processed_at_utc"])

        api_to_dispatch_ms = max((dispatch_at - accepted_at).total_seconds() * 1000.0, 0.0)
        dispatch_to_ledger_ms = max(float(row.get("ledger_latency_ms") or 0.0), 0.0)
        handler_duration_ms = max(float(row.get("handler_duration_ms") or 0.0), 0.0)
        queue_processing_gap_ms = max(dispatch_to_ledger_ms - handler_duration_ms, 0.0)
        accepted_to_processed_ms = max((processed_at - accepted_at).total_seconds() * 1000.0, 0.0)

        api_to_dispatch.append(api_to_dispatch_ms)
        dispatch_to_ledger.append(dispatch_to_ledger_ms)
        handler_duration.append(handler_duration_ms)
        queue_processing_gap.append(queue_processing_gap_ms)
        accepted_to_processed.append(accepted_to_processed_ms)

stage_summaries = {
    "api_to_dispatch_ms": summarize(api_to_dispatch),
    "dispatch_to_ledger_ms": summarize(dispatch_to_ledger),
    "handler_duration_ms": summarize(handler_duration),
    "queue_processing_gap_ms": summarize(queue_processing_gap),
    "accepted_to_processed_ms": summarize(accepted_to_processed),
}

dominant_stage = "no-data"
dominant_p95 = -1.0
for stage_name in ("api_to_dispatch_ms", "queue_processing_gap_ms", "handler_duration_ms"):
    stage_p95 = stage_summaries[stage_name]["p95"]
    if stage_p95 > dominant_p95:
        dominant_p95 = stage_p95
        dominant_stage = stage_name

summary = {
    "scenario": scenario,
    "request_count": stage_summaries["accepted_to_processed_ms"]["count"],
    "dominant_stage": dominant_stage,
    "stages": stage_summaries,
}

with open(output_path, "w", encoding="ascii") as handle:
    json.dump(summary, handle, indent=2)
PY
}

write_latency_summary() {
  python3 - "$EVIDENCE_DIR" "$LATENCY_SUMMARY_PATH" <<'PY'
import csv, glob, json, os, sys

def percentile(values, pct):
    if not values:
        return 0.0
    values = sorted(values)
    if len(values) == 1:
        return float(values[0])
    rank = (len(values) - 1) * pct
    lower = int(rank)
    upper = min(lower + 1, len(values) - 1)
    weight = rank - lower
    return round(values[lower] * (1 - weight) + values[upper] * weight, 3)

summary = {}
for path in sorted(glob.glob(os.path.join(sys.argv[1], "*-samples.csv"))):
    scenario = os.path.basename(path).replace("-samples.csv", "")
    latencies = []
    with open(path, newline="") as handle:
        for row in csv.DictReader(handle):
            if row["ledger_status"] == "processed":
                latencies.append(float(row["ledger_latency_ms"]))
    summary[scenario] = {
        "count": len(latencies),
        "p50": percentile(latencies, 0.50),
        "p95": percentile(latencies, 0.95),
        "p99": percentile(latencies, 0.99),
        "max": round(max(latencies), 3) if latencies else 0.0,
    }

with open(sys.argv[2], "w", encoding="ascii") as handle:
    json.dump(summary, handle, indent=2)
PY
}

write_latency_breakdown_summary() {
  python3 - "$EVIDENCE_DIR" "$LATENCY_BREAKDOWN_SUMMARY_PATH" <<'PY'
import glob, json, os, sys

summary = {}
for path in sorted(glob.glob(os.path.join(sys.argv[1], "*-latency-breakdown.json"))):
    with open(path, encoding="ascii") as handle:
        data = json.load(handle)
    summary[data["scenario"]] = data

with open(sys.argv[2], "w", encoding="ascii") as handle:
    json.dump(summary, handle, indent=2)
PY
}

assert_numeric_threshold() {
  local value="$1"
  local comparator="$2"
  local threshold="$3"
  python3 - "$value" "$comparator" "$threshold" <<'PY'
import sys
value = float(sys.argv[1])
op = sys.argv[2]
threshold = float(sys.argv[3])
ok = {
    "<=": value <= threshold,
    ">=": value >= threshold,
    "<": value < threshold,
    ">": value > threshold,
}.get(op, False)
sys.exit(0 if ok else 1)
PY
}

max_for_scenario() {
  local csv_path="$1"
  local scenario="$2"
  local column="$3"
  awk -F, -v scenario="$scenario" -v col="$column" '
    NR > 1 && $2 == scenario {
      if ($col ~ /^[0-9]+([.][0-9]+)?$/ && $col + 0 > max) max = $col + 0
    }
    END { print max + 0 }
  ' "$csv_path"
}

consumer_capacity_for_scenario() {
  local csv_path="$1"
  local scenario="$2"
  python3 - "$csv_path" "$scenario" <<'PY'
import csv, sys
values = []
with open(sys.argv[1], newline="") as handle:
    for row in csv.DictReader(handle):
        if row["scenario"] == sys.argv[2]:
            raw = row["consumer_capacity"]
            try:
                values.append(float(raw))
            except ValueError:
                pass
if values:
    print(round(max(values), 3))
else:
    print("metric_unavailable")
PY
}

growth_for_scenario() {
  local csv_path="$1"
  local scenario="$2"
  local column="$3"
  awk -F, -v scenario="$scenario" -v col="$column" '
    NR > 1 && $2 == scenario && $col ~ /^[0-9]+([.][0-9]+)?$/ {
      value = $col + 0
      if (!seen) {
        min = value
        max = value
        seen = 1
      }
      if (value < min) min = value
      if (value > max) max = value
    }
    END {
      if (!seen) {
        print 0
      } else {
        print max - min
      }
    }
  ' "$csv_path"
}

append_profile_result() {
  local profile="$1"
  local gating="$2"
  local request_count="$3"
  local concurrency="$4"
  local result="$5"
  local failure_class="$6"
  local reason="$7"
  local success_rate="${8:-0}"
  local duplicate_count="${9:-0}"
  local p50="${10:-0}"
  local p95="${11:-0}"
  local p99="${12:-0}"
  local max_queue_depth="${13:-0}"
  local max_unacked="${14:-0}"
  local drain_seconds="${15:-0}"
  local recovery_seconds="${16:-0}"
  local terminal_failure_verified="${17:-false}"
  local error_queue_messages="${18:-0}"
  local consumer_capacity="${19:-metric_unavailable}"
  local consumers_max="${20:-0}"
  local peak_outbox_pending="${21:-0}"
  local peak_inbox_growth="${22:-0}"
  local peak_dispatch_records="${23:-0}"
  local peak_inbox_count="${24:-0}"
  local api_to_dispatch_p95="${25:-0}"
  local dispatch_to_ledger_p95="${26:-0}"
  local handler_duration_p95="${27:-0}"
  local queue_processing_gap_p95="${28:-0}"
  local accepted_to_processed_p95="${29:-0}"
  local dominant_latency_stage="${30:-no-data}"

  jq -nc \
    --arg profile "$profile" \
    --argjson gating "$gating" \
    --argjson request_count "$request_count" \
    --argjson concurrency "$concurrency" \
    --arg result "$result" \
    --arg failure_class "$failure_class" \
    --arg reason "$reason" \
    --argjson success_rate "$success_rate" \
    --argjson duplicate_count "$duplicate_count" \
    --argjson p50_latency_ms "$p50" \
    --argjson p95_latency_ms "$p95" \
    --argjson p99_latency_ms "$p99" \
    --argjson max_queue_depth "$max_queue_depth" \
    --argjson max_unacked "$max_unacked" \
    --argjson drain_seconds "$drain_seconds" \
    --argjson recovery_seconds "$recovery_seconds" \
    --argjson terminal_failure_verified "$terminal_failure_verified" \
    --argjson error_queue_messages "$error_queue_messages" \
    --arg consumer_capacity_observed "$consumer_capacity" \
    --argjson consumers_max "$consumers_max" \
    --argjson peak_outbox_pending "$peak_outbox_pending" \
    --argjson peak_inbox_growth "$peak_inbox_growth" \
    --argjson peak_dispatch_records "$peak_dispatch_records" \
    --argjson peak_inbox_count "$peak_inbox_count" \
    --argjson api_to_dispatch_p95_ms "$api_to_dispatch_p95" \
    --argjson dispatch_to_ledger_p95_ms "$dispatch_to_ledger_p95" \
    --argjson handler_duration_p95_ms "$handler_duration_p95" \
    --argjson queue_processing_gap_p95_ms "$queue_processing_gap_p95" \
    --argjson accepted_to_processed_p95_ms "$accepted_to_processed_p95" \
    --arg dominant_latency_stage "$dominant_latency_stage" \
    '{
      profile: $profile,
      gating: $gating,
      request_count: $request_count,
      concurrency: $concurrency,
      result: $result,
      failure_class: $failure_class,
      reason: $reason,
      success_rate: $success_rate,
      duplicate_count: $duplicate_count,
      p50_latency_ms: $p50_latency_ms,
      p95_latency_ms: $p95_latency_ms,
      p99_latency_ms: $p99_latency_ms,
      max_queue_depth: $max_queue_depth,
      max_unacked: $max_unacked,
      drain_seconds: $drain_seconds,
      recovery_seconds: $recovery_seconds,
      terminal_failure_verified: $terminal_failure_verified,
      error_queue_messages: $error_queue_messages,
      consumer_capacity_observed: $consumer_capacity_observed,
      consumers_max: $consumers_max,
      peak_outbox_pending: $peak_outbox_pending,
      peak_inbox_growth: $peak_inbox_growth,
      peak_dispatch_records: $peak_dispatch_records,
      peak_inbox_count: $peak_inbox_count,
      api_to_dispatch_p95_ms: $api_to_dispatch_p95_ms,
      dispatch_to_ledger_p95_ms: $dispatch_to_ledger_p95_ms,
      handler_duration_p95_ms: $handler_duration_p95_ms,
      queue_processing_gap_p95_ms: $queue_processing_gap_p95_ms,
      accepted_to_processed_p95_ms: $accepted_to_processed_p95_ms,
      dominant_latency_stage: $dominant_latency_stage
    }' >> "$PROFILE_RESULTS_PATH"
}

record_profile_success() {
  append_profile_result "$@"
}

record_profile_failure() {
  append_profile_result "$@"
}

prepare_request_ids() {
  local responses_path="$1"
  local request_ids_path="$2"
  jq -r 'select(.status == "accepted") | .checkId' "$responses_path" > "$request_ids_path"
}

run_load_scenario() {
  local profile="$1"
  local request_count="$2"
  local concurrency="$3"
  local source="$4"
  local content_prefix="$5"
  local gating="$6"
  local enforce_latency="$7"
  local pg_container="$8"
  local pg_user="$9"
  local pg_pass="${10}"
  local rabbit_container="${11}"

  local stop_flag="$EVIDENCE_DIR/${profile}.stop"
  local responses_path="$EVIDENCE_DIR/${profile}-responses.jsonl"
  local request_ids_path="$EVIDENCE_DIR/${profile}-request-ids.txt"
  local scenario_csv="$EVIDENCE_DIR/${profile}-samples.csv"
  local success_count total_count success_rate duplicate_count max_queue_depth max_unacked consumers_max capacity_observed
  local peak_outbox_pending peak_inbox_growth peak_dispatch_records peak_inbox_count breakdown_json dominant_latency_stage
  local api_to_dispatch_p95 dispatch_to_ledger_p95 handler_duration_p95 queue_processing_gap_p95 accepted_to_processed_p95
  local latency_json p50 p95 p99

  rm -f "$stop_flag"
  init_scenario_request_artifacts "$profile"
  start_queue_sampler "$profile" "$source" "$stop_flag" "$pg_container" "$pg_user" "$pg_pass" "$rabbit_container"

  if ! append_request_batch "$profile" 1 "$request_count" "$concurrency" "$source" "$content_prefix"; then
    stop_queue_sampler "$stop_flag"
    LAST_FAILURE_CLASS="fail:load-http"
    LAST_REASON="Request batch failed for $profile"
    echo "FAIL $profile request_batch class=$LAST_FAILURE_CLASS reason=$LAST_REASON" >> "$CHECKS_PATH"
    record_profile_failure "$profile" "$gating" "$request_count" "$concurrency" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON"
    return 1
  fi

  prepare_request_ids "$responses_path" "$request_ids_path"
  if ! wait_for_processed_requests "$request_ids_path" "$MAX_RECOVERY_SECONDS" "$pg_container" "$pg_user" "$pg_pass" >/dev/null; then
    stop_queue_sampler "$stop_flag"
    LAST_FAILURE_CLASS="fail:load-success-rate"
    LAST_REASON="$profile requests did not all reach processed state within recovery window"
    echo "FAIL $profile recovery_timeout maxRecoverySeconds=$MAX_RECOVERY_SECONDS" >> "$CHECKS_PATH"
    record_profile_failure "$profile" "$gating" "$request_count" "$concurrency" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON"
    return 1
  fi

  stop_queue_sampler "$stop_flag"
  export_request_metrics "$profile" "$request_ids_path" "$pg_container" "$pg_user" "$pg_pass"
  compute_latency_breakdown "$profile" "$responses_path" "$scenario_csv"
  breakdown_json="$(cat "$EVIDENCE_DIR/${profile}-latency-breakdown.json")"
  latency_json="$(compute_latency_metrics "$scenario_csv")"
  p50="$(printf '%s' "$latency_json" | jq -r '.p50')"
  p95="$(printf '%s' "$latency_json" | jq -r '.p95')"
  p99="$(printf '%s' "$latency_json" | jq -r '.p99')"
  api_to_dispatch_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.api_to_dispatch_ms.p95')"
  dispatch_to_ledger_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.dispatch_to_ledger_ms.p95')"
  handler_duration_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.handler_duration_ms.p95')"
  queue_processing_gap_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.queue_processing_gap_ms.p95')"
  accepted_to_processed_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.accepted_to_processed_ms.p95')"
  dominant_latency_stage="$(printf '%s' "$breakdown_json" | jq -r '.dominant_stage')"
  total_count="$(wc -l < "$responses_path" | tr -d ' ')"
  success_count="$(python3 - "$scenario_csv" <<'PY'
import csv, sys
count = 0
with open(sys.argv[1], newline="") as handle:
    for row in csv.DictReader(handle):
        if row["ledger_status"] == "processed":
            count += 1
print(count)
PY
)"
  success_rate="$(python3 - "$success_count" "$total_count" <<'PY'
import sys
succ = float(sys.argv[1]); total = float(sys.argv[2])
print(f"{(succ / total) if total else 0:.6f}")
PY
)"
  duplicate_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from (select request_id from compliance_ledger.events where request_id = any(array[$(request_ids_to_sql_array "$request_ids_path")]) group by request_id having count(*) > 1) d;")"
  max_queue_depth="$(max_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 3)"
  max_unacked="$(max_for_scenario "$RABBITMQ_TIMELINE_PATH" "$profile" 5)"
  consumers_max="$(max_for_scenario "$RABBITMQ_TIMELINE_PATH" "$profile" 6)"
  capacity_observed="$(consumer_capacity_for_scenario "$RABBITMQ_TIMELINE_PATH" "$profile")"
  peak_outbox_pending="$(max_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 7)"
  peak_inbox_growth="$(growth_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 8)"
  peak_dispatch_records="$(max_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 9)"
  peak_inbox_count="$(max_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 8)"

  {
    echo "${profile}_success_rate=$success_rate"
    echo "${profile}_p50_ms=$p50"
    echo "${profile}_p95_ms=$p95"
    echo "${profile}_p99_ms=$p99"
    echo "${profile}_duplicate_count=$duplicate_count"
    echo "${profile}_max_queue_depth=$max_queue_depth"
    echo "${profile}_max_unacked=$max_unacked"
    echo "${profile}_peak_outbox_pending=$peak_outbox_pending"
    echo "${profile}_peak_inbox_growth=$peak_inbox_growth"
    echo "${profile}_peak_dispatch_records=$peak_dispatch_records"
    echo "${profile}_peak_inbox_count=$peak_inbox_count"
    echo "${profile}_consumer_capacity_observed=$capacity_observed"
    echo "${profile}_api_to_dispatch_p95_ms=$api_to_dispatch_p95"
    echo "${profile}_dispatch_to_ledger_p95_ms=$dispatch_to_ledger_p95"
    echo "${profile}_handler_duration_p95_ms=$handler_duration_p95"
    echo "${profile}_queue_processing_gap_p95_ms=$queue_processing_gap_p95"
    echo "${profile}_accepted_to_processed_p95_ms=$accepted_to_processed_p95"
    echo "${profile}_dominant_latency_stage=$dominant_latency_stage"
  } >> "$SQL_OUT_PATH"

  if ! assert_numeric_threshold "$success_rate" ">=" "$(python3 - "$MAX_ACCEPTABLE_FAILURE_RATE" <<'PY'
import sys
rate = float(sys.argv[1])
print(f"{1.0 - rate:.6f}")
PY
)"; then
    LAST_FAILURE_CLASS="fail:load-success-rate"
    LAST_REASON="$profile success rate fell below threshold"
    echo "FAIL $profile success_rate=$success_rate threshold=$(python3 - "$MAX_ACCEPTABLE_FAILURE_RATE" <<'PY'
import sys
rate = float(sys.argv[1])
print(f"{1.0 - rate:.6f}")
PY
)" >> "$CHECKS_PATH"
    record_profile_failure "$profile" "$gating" "$request_count" "$concurrency" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON" "$success_rate" "$duplicate_count" "$p50" "$p95" "$p99" "$max_queue_depth" "$max_unacked" 0 0 false 0 "$capacity_observed" "$consumers_max" "$peak_outbox_pending" "$peak_inbox_growth" "$peak_dispatch_records" "$peak_inbox_count" "$api_to_dispatch_p95" "$dispatch_to_ledger_p95" "$handler_duration_p95" "$queue_processing_gap_p95" "$accepted_to_processed_p95" "$dominant_latency_stage"
    return 1
  fi

  if [[ "$duplicate_count" -ne 0 ]]; then
    LAST_FAILURE_CLASS="fail:duplicate-under-load"
    LAST_REASON="Duplicate ledger effects detected during $profile"
    echo "FAIL $profile duplicate_count=$duplicate_count" >> "$CHECKS_PATH"
    record_profile_failure "$profile" "$gating" "$request_count" "$concurrency" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON" "$success_rate" "$duplicate_count" "$p50" "$p95" "$p99" "$max_queue_depth" "$max_unacked" 0 0 false 0 "$capacity_observed" "$consumers_max" "$peak_outbox_pending" "$peak_inbox_growth" "$peak_dispatch_records" "$peak_inbox_count" "$api_to_dispatch_p95" "$dispatch_to_ledger_p95" "$handler_duration_p95" "$queue_processing_gap_p95" "$accepted_to_processed_p95" "$dominant_latency_stage"
    return 1
  fi

  if [[ "$enforce_latency" == "true" ]]; then
    if ! assert_numeric_threshold "$p95" "<=" "$P95_LEDGER_LATENCY_MS" || ! assert_numeric_threshold "$p99" "<=" "$P99_LEDGER_LATENCY_MS"; then
      LAST_FAILURE_CLASS="fail:latency-slo"
      LAST_REASON="$profile latency exceeded threshold"
      echo "FAIL $profile latency p95=$p95 p99=$p99 thresholdP95=$P95_LEDGER_LATENCY_MS thresholdP99=$P99_LEDGER_LATENCY_MS" >> "$CHECKS_PATH"
      record_profile_failure "$profile" "$gating" "$request_count" "$concurrency" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON" "$success_rate" "$duplicate_count" "$p50" "$p95" "$p99" "$max_queue_depth" "$max_unacked" 0 0 false 0 "$capacity_observed" "$consumers_max" "$peak_outbox_pending" "$peak_inbox_growth" "$peak_dispatch_records" "$peak_inbox_count" "$api_to_dispatch_p95" "$dispatch_to_ledger_p95" "$handler_duration_p95" "$queue_processing_gap_p95" "$accepted_to_processed_p95" "$dominant_latency_stage"
      return 1
    fi

    if ! assert_numeric_threshold "$max_queue_depth" "<=" "$MAX_QUEUE_DEPTH"; then
      LAST_FAILURE_CLASS="fail:queue-depth"
      LAST_REASON="$profile queue depth exceeded threshold"
      echo "FAIL $profile max_queue_depth=$max_queue_depth threshold=$MAX_QUEUE_DEPTH" >> "$CHECKS_PATH"
      record_profile_failure "$profile" "$gating" "$request_count" "$concurrency" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON" "$success_rate" "$duplicate_count" "$p50" "$p95" "$p99" "$max_queue_depth" "$max_unacked" 0 0 false 0 "$capacity_observed" "$consumers_max" "$peak_outbox_pending" "$peak_inbox_growth" "$peak_dispatch_records" "$peak_inbox_count" "$api_to_dispatch_p95" "$dispatch_to_ledger_p95" "$handler_duration_p95" "$queue_processing_gap_p95" "$accepted_to_processed_p95" "$dominant_latency_stage"
      return 1
    fi
  fi

  echo "PASS $profile success_rate=$success_rate p50=$p50 p95=$p95 p99=$p99 max_queue_depth=$max_queue_depth max_unacked=$max_unacked peak_outbox_pending=$peak_outbox_pending peak_inbox_growth=$peak_inbox_growth peak_dispatch_records=$peak_dispatch_records peak_inbox_count=$peak_inbox_count dominant_latency_stage=$dominant_latency_stage api_to_dispatch_p95_ms=$api_to_dispatch_p95 dispatch_to_ledger_p95_ms=$dispatch_to_ledger_p95 handler_duration_p95_ms=$handler_duration_p95 queue_processing_gap_p95_ms=$queue_processing_gap_p95 accepted_to_processed_p95_ms=$accepted_to_processed_p95" >> "$CHECKS_PATH"
  record_profile_success "$profile" "$gating" "$request_count" "$concurrency" "pass" "pass" "all assertions passed" "$success_rate" "$duplicate_count" "$p50" "$p95" "$p99" "$max_queue_depth" "$max_unacked" 0 0 false 0 "$capacity_observed" "$consumers_max" "$peak_outbox_pending" "$peak_inbox_growth" "$peak_dispatch_records" "$peak_inbox_count" "$api_to_dispatch_p95" "$dispatch_to_ledger_p95" "$handler_duration_p95" "$queue_processing_gap_p95" "$accepted_to_processed_p95" "$dominant_latency_stage"
}

run_backlog_recovery() {
  local pg_container="$1"
  local pg_user="$2"
  local pg_pass="$3"
  local rabbit_container="$4"
  local profile="release-backlog-recovery"
  local stop_flag="$EVIDENCE_DIR/${profile}.stop"
  local responses_path="$EVIDENCE_DIR/${profile}-responses.jsonl"
  local request_ids_path="$EVIDENCE_DIR/${profile}-request-ids.txt"
  local scenario_csv="$EVIDENCE_DIR/${profile}-samples.csv"
  local duplicate_count max_queue_depth max_unacked capacity_observed consumers_max latency_json p50 p95 p99
  local peak_outbox_pending peak_inbox_growth peak_dispatch_records peak_inbox_count breakdown_json dominant_latency_stage
  local api_to_dispatch_p95 dispatch_to_ledger_p95 handler_duration_p95 queue_processing_gap_p95 accepted_to_processed_p95

  rm -f "$stop_flag"
  init_scenario_request_artifacts "$profile"
  echo "timestamp_utc,scenario,second,compliance_messages,outbox_pending,processed_count" > "$DRAIN_TIMELINE_PATH"
  start_queue_sampler "$profile" "phase4-backlog" "$stop_flag" "$pg_container" "$pg_user" "$pg_pass" "$rabbit_container"

  if ! append_request_batch "$profile" 1 "$BACKLOG_REQUEST_COUNT" "$BACKLOG_CONCURRENCY" "phase4-backlog" "phase4-backlog"; then
    stop_queue_sampler "$stop_flag"
    LAST_FAILURE_CLASS="fail:load-http"
    LAST_REASON="Backlog request batch failed"
    echo "FAIL $profile request_batch class=$LAST_FAILURE_CLASS reason=$LAST_REASON" >> "$CHECKS_PATH"
    record_profile_failure "$profile" true "$BACKLOG_REQUEST_COUNT" "$BACKLOG_CONCURRENCY" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON"
    return 1
  fi

  prepare_request_ids "$responses_path" "$request_ids_path"
  local processed_count compliance_messages outbox_pending total_expected
  total_expected="$(wc -l < "$request_ids_path" | tr -d ' ')"
  local recovered="false"
  local sec
  for sec in $(seq 1 "$MAX_DRAIN_SECONDS"); do
    processed_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from compliance_ledger.events where request_id = any(array[$(request_ids_to_sql_array "$request_ids_path")]) and status='processed';")"
    compliance_messages="$(extract_queue_field "$(extract_queue_line "$(docker exec "$rabbit_container" rabbitmqctl list_queues -q name messages messages_ready messages_unacknowledged consumers consumer_capacity 2>/dev/null || true)" "compliance")" 2)"
    outbox_pending="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from masstransit.outbox_message;")"
    printf '%s,%s,%s,%s,%s,%s\n' "$(date -u +%FT%TZ)" "$profile" "$sec" "$compliance_messages" "$outbox_pending" "$processed_count" >> "$DRAIN_TIMELINE_PATH"
    if [[ "$processed_count" -ge "$total_expected" && "$compliance_messages" -eq 0 && "$outbox_pending" -eq 0 ]]; then
      recovered="true"
      break
    fi
    sleep 1
  done

  stop_queue_sampler "$stop_flag"
  if [[ "$recovered" != "true" ]]; then
    LAST_FAILURE_CLASS="fail:drain-timeout"
    LAST_REASON="Backlog did not drain within threshold"
    echo "FAIL $profile drain_timeout threshold=$MAX_DRAIN_SECONDS" >> "$CHECKS_PATH"
    record_profile_failure "$profile" true "$BACKLOG_REQUEST_COUNT" "$BACKLOG_CONCURRENCY" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON"
    return 1
  fi

  export_request_metrics "$profile" "$request_ids_path" "$pg_container" "$pg_user" "$pg_pass"
  compute_latency_breakdown "$profile" "$responses_path" "$scenario_csv"
  breakdown_json="$(cat "$EVIDENCE_DIR/${profile}-latency-breakdown.json")"
  latency_json="$(compute_latency_metrics "$scenario_csv")"
  p50="$(printf '%s' "$latency_json" | jq -r '.p50')"
  p95="$(printf '%s' "$latency_json" | jq -r '.p95')"
  p99="$(printf '%s' "$latency_json" | jq -r '.p99')"
  api_to_dispatch_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.api_to_dispatch_ms.p95')"
  dispatch_to_ledger_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.dispatch_to_ledger_ms.p95')"
  handler_duration_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.handler_duration_ms.p95')"
  queue_processing_gap_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.queue_processing_gap_ms.p95')"
  accepted_to_processed_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.accepted_to_processed_ms.p95')"
  dominant_latency_stage="$(printf '%s' "$breakdown_json" | jq -r '.dominant_stage')"
  duplicate_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from (select request_id from compliance_ledger.events where request_id = any(array[$(request_ids_to_sql_array "$request_ids_path")]) group by request_id having count(*) > 1) d;")"
  max_queue_depth="$(max_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 3)"
  max_unacked="$(max_for_scenario "$RABBITMQ_TIMELINE_PATH" "$profile" 5)"
  consumers_max="$(max_for_scenario "$RABBITMQ_TIMELINE_PATH" "$profile" 6)"
  capacity_observed="$(consumer_capacity_for_scenario "$RABBITMQ_TIMELINE_PATH" "$profile")"
  peak_outbox_pending="$(max_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 7)"
  peak_inbox_growth="$(growth_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 8)"
  peak_dispatch_records="$(max_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 9)"
  peak_inbox_count="$(max_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 8)"

  {
    echo "${profile}_drain_seconds=$sec"
    echo "${profile}_duplicate_count=$duplicate_count"
    echo "${profile}_max_queue_depth=$max_queue_depth"
    echo "${profile}_max_unacked=$max_unacked"
    echo "${profile}_peak_outbox_pending=$peak_outbox_pending"
    echo "${profile}_peak_inbox_growth=$peak_inbox_growth"
    echo "${profile}_peak_dispatch_records=$peak_dispatch_records"
    echo "${profile}_peak_inbox_count=$peak_inbox_count"
    echo "${profile}_consumer_capacity_observed=$capacity_observed"
    echo "${profile}_api_to_dispatch_p95_ms=$api_to_dispatch_p95"
    echo "${profile}_dispatch_to_ledger_p95_ms=$dispatch_to_ledger_p95"
    echo "${profile}_handler_duration_p95_ms=$handler_duration_p95"
    echo "${profile}_queue_processing_gap_p95_ms=$queue_processing_gap_p95"
    echo "${profile}_accepted_to_processed_p95_ms=$accepted_to_processed_p95"
    echo "${profile}_dominant_latency_stage=$dominant_latency_stage"
  } >> "$SQL_OUT_PATH"

  if [[ "$duplicate_count" -ne 0 ]]; then
    LAST_FAILURE_CLASS="fail:duplicate-under-load"
    LAST_REASON="Duplicate ledger effects detected during backlog recovery"
    echo "FAIL $profile duplicate_count=$duplicate_count" >> "$CHECKS_PATH"
    record_profile_failure "$profile" true "$BACKLOG_REQUEST_COUNT" "$BACKLOG_CONCURRENCY" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON" 1 "$duplicate_count" "$p50" "$p95" "$p99" "$max_queue_depth" "$max_unacked" "$sec" 0 false 0 "$capacity_observed" "$consumers_max" "$peak_outbox_pending" "$peak_inbox_growth" "$peak_dispatch_records" "$peak_inbox_count" "$api_to_dispatch_p95" "$dispatch_to_ledger_p95" "$handler_duration_p95" "$queue_processing_gap_p95" "$accepted_to_processed_p95" "$dominant_latency_stage"
    return 1
  fi

  if ! assert_numeric_threshold "$sec" "<=" "$MAX_DRAIN_SECONDS"; then
    LAST_FAILURE_CLASS="fail:drain-timeout"
    LAST_REASON="Backlog drain time exceeded threshold"
    echo "FAIL $profile drain_seconds=$sec threshold=$MAX_DRAIN_SECONDS" >> "$CHECKS_PATH"
    record_profile_failure "$profile" true "$BACKLOG_REQUEST_COUNT" "$BACKLOG_CONCURRENCY" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON" 1 "$duplicate_count" "$p50" "$p95" "$p99" "$max_queue_depth" "$max_unacked" "$sec" 0 false 0 "$capacity_observed" "$consumers_max" "$peak_outbox_pending" "$peak_inbox_growth" "$peak_dispatch_records" "$peak_inbox_count" "$api_to_dispatch_p95" "$dispatch_to_ledger_p95" "$handler_duration_p95" "$queue_processing_gap_p95" "$accepted_to_processed_p95" "$dominant_latency_stage"
    return 1
  fi

  echo "PASS $profile drain_seconds=$sec max_queue_depth=$max_queue_depth max_unacked=$max_unacked peak_outbox_pending=$peak_outbox_pending peak_inbox_growth=$peak_inbox_growth peak_dispatch_records=$peak_dispatch_records peak_inbox_count=$peak_inbox_count dominant_latency_stage=$dominant_latency_stage api_to_dispatch_p95_ms=$api_to_dispatch_p95 dispatch_to_ledger_p95_ms=$dispatch_to_ledger_p95 handler_duration_p95_ms=$handler_duration_p95 queue_processing_gap_p95_ms=$queue_processing_gap_p95 accepted_to_processed_p95_ms=$accepted_to_processed_p95" >> "$CHECKS_PATH"
  record_profile_success "$profile" true "$BACKLOG_REQUEST_COUNT" "$BACKLOG_CONCURRENCY" "pass" "pass" "all assertions passed" 1 "$duplicate_count" "$p50" "$p95" "$p99" "$max_queue_depth" "$max_unacked" "$sec" 0 false 0 "$capacity_observed" "$consumers_max" "$peak_outbox_pending" "$peak_inbox_growth" "$peak_dispatch_records" "$peak_inbox_count" "$api_to_dispatch_p95" "$dispatch_to_ledger_p95" "$handler_duration_p95" "$queue_processing_gap_p95" "$accepted_to_processed_p95" "$dominant_latency_stage"
}

run_terminal_failure() {
  local gating="$1"
  local pg_container="$2"
  local pg_user="$3"
  local pg_pass="$4"
  local rabbit_container="$5"
  local profile="release-terminal-failure"
  local failure_json="$EVIDENCE_DIR/forced-failure.json"
  local http_code request_id message_id failed_count failed_status terminal_rows error_queue_messages recovery_seconds
  local payload='{"content":"phase4-force-failure","source":"diagnostics-force-failure"}'
  local start_epoch

  capture_rabbitmq_snapshot "${profile}-pre" "$rabbit_container"
  start_epoch="$(date +%s)"
  http_code="$(curl -sS --max-time 20 -o "$failure_json" -w "%{http_code}" \
    -X POST "$ATTEMPT_API_URL/api/diagnostics/messaging/force-failure" \
    -H "Content-Type: application/json" \
    --data-binary "$payload" || true)"

  if [[ "$http_code" != "200" ]]; then
    LAST_FAILURE_CLASS="fail:terminal-failure-policy"
    LAST_REASON="Force failure endpoint returned HTTP $http_code"
    echo "FAIL $profile endpoint_http=$http_code" >> "$CHECKS_PATH"
    record_profile_failure "$profile" "$gating" 1 1 "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON"
    return 1
  fi

  request_id="$(jq -r '.requestId // empty' "$failure_json")"
  message_id="$(jq -r '.messageId // empty' "$failure_json")"
  for _ in $(seq 1 "$MAX_RECOVERY_SECONDS"); do
    failed_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from compliance_ledger.events where request_id='${request_id}'::uuid and status='failed';")"
    if [[ "$failed_count" -ge 1 ]]; then
      break
    fi
    sleep 1
  done

  recovery_seconds="$(( $(date +%s) - start_epoch ))"
  failed_status="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select status from compliance_ledger.events where request_id='${request_id}'::uuid order by processed_at_utc desc limit 1;")"
  terminal_rows="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from compliance_ledger.events where message_id='${message_id}'::uuid;")"
  error_queue_messages="$(extract_queue_field "$(extract_queue_line "$(docker exec "$rabbit_container" rabbitmqctl list_queues -q name messages messages_ready messages_unacknowledged consumers consumer_capacity 2>/dev/null || true)" "compliance_error")" 2)"
  capture_rabbitmq_snapshot "${profile}-post" "$rabbit_container"

  {
    echo "request_id=$request_id"
    echo "message_id=$message_id"
    echo "failed_status=$failed_status"
    echo "terminal_rows=$terminal_rows"
    echo "compliance_error_messages=$error_queue_messages"
    echo "recovery_seconds=$recovery_seconds"
  } > "$FAILURE_SUMMARY_PATH"

  {
    echo "${profile}_request_id=$request_id"
    echo "${profile}_message_id=$message_id"
    echo "${profile}_status=$failed_status"
    echo "${profile}_terminal_rows=$terminal_rows"
    echo "${profile}_error_queue_messages=$error_queue_messages"
    echo "${profile}_recovery_seconds=$recovery_seconds"
  } >> "$SQL_OUT_PATH"

  if [[ "$failed_status" != "failed" ]]; then
    LAST_FAILURE_CLASS="fail:terminal-failure-policy"
    LAST_REASON="Forced failure did not reach failed ledger state"
    echo "FAIL $profile status=$failed_status requestId=$request_id" >> "$CHECKS_PATH"
    record_profile_failure "$profile" "$gating" 1 1 "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON" 1 0 0 0 0 0 0 0 "$recovery_seconds" false "$error_queue_messages"
    return 1
  fi

  if [[ "$terminal_rows" -ne "$TERMINAL_FAILURE_ROWS_EXACT" ]]; then
    LAST_FAILURE_CLASS="fail:terminal-failure-duplication"
    LAST_REASON="Forced failure produced $terminal_rows terminal ledger rows"
    echo "FAIL $profile rows=$terminal_rows expected=$TERMINAL_FAILURE_ROWS_EXACT requestId=$request_id messageId=$message_id" >> "$CHECKS_PATH"
    record_profile_failure "$profile" "$gating" 1 1 "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON" 1 0 0 0 0 0 0 0 "$recovery_seconds" false "$error_queue_messages"
    return 1
  fi

  if [[ "$error_queue_messages" -lt 1 ]]; then
    LAST_FAILURE_CLASS="fail:terminal-failure-policy"
    LAST_REASON="Forced failure did not route to compliance_error queue"
    echo "FAIL $profile error_queue_messages=$error_queue_messages requestId=$request_id" >> "$CHECKS_PATH"
    record_profile_failure "$profile" "$gating" 1 1 "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON" 1 0 0 0 0 0 0 0 "$recovery_seconds" false "$error_queue_messages"
    return 1
  fi

  echo "PASS $profile requestId=$request_id messageId=$message_id error_queue_messages=$error_queue_messages recovery_seconds=$recovery_seconds" >> "$CHECKS_PATH"
  record_profile_success "$profile" "$gating" 1 1 "pass" "pass" "all assertions passed" 1 0 0 0 0 0 0 0 "$recovery_seconds" true "$error_queue_messages"
}

run_soak_profile() {
  local pg_container="$1"
  local pg_user="$2"
  local pg_pass="$3"
  local rabbit_container="$4"
  local profile="diagnostic-soak"
  local stop_flag="$EVIDENCE_DIR/${profile}.stop"
  local responses_path="$EVIDENCE_DIR/${profile}-responses.jsonl"
  local request_ids_path="$EVIDENCE_DIR/${profile}-request-ids.txt"
  local scenario_csv="$EVIDENCE_DIR/${profile}-samples.csv"
  local idx=1
  local batch_size=2
  local concurrency=2
  local deadline="$(( $(date +%s) + SOAK_SECONDS ))"
  local latency_json p50 p95 p99 success_rate duplicate_count max_queue_depth max_unacked consumers_max capacity_observed
  local peak_outbox_pending peak_inbox_growth peak_dispatch_records peak_inbox_count breakdown_json dominant_latency_stage
  local api_to_dispatch_p95 dispatch_to_ledger_p95 handler_duration_p95 queue_processing_gap_p95 accepted_to_processed_p95

  rm -f "$stop_flag"
  init_scenario_request_artifacts "$profile"
  start_queue_sampler "$profile" "phase4-soak" "$stop_flag" "$pg_container" "$pg_user" "$pg_pass" "$rabbit_container"
  while [[ "$(date +%s)" -lt "$deadline" ]]; do
    append_request_batch "$profile" "$idx" "$batch_size" "$concurrency" "phase4-soak" "phase4-soak" || {
      stop_queue_sampler "$stop_flag"
      LAST_FAILURE_CLASS="fail:load-http"
      LAST_REASON="Soak batch failed"
      echo "FAIL $profile request_batch class=$LAST_FAILURE_CLASS reason=$LAST_REASON" >> "$CHECKS_PATH"
      record_profile_failure "$profile" false 0 "$concurrency" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON"
      return 1
    }
    idx=$((idx + batch_size))
    sleep 1
  done

  prepare_request_ids "$responses_path" "$request_ids_path"
  if ! wait_for_processed_requests "$request_ids_path" "$MAX_RECOVERY_SECONDS" "$pg_container" "$pg_user" "$pg_pass" >/dev/null; then
    stop_queue_sampler "$stop_flag"
    LAST_FAILURE_CLASS="fail:load-success-rate"
    LAST_REASON="Soak requests did not all reach processed state within recovery window"
    echo "FAIL $profile recovery_timeout maxRecoverySeconds=$MAX_RECOVERY_SECONDS" >> "$CHECKS_PATH"
    record_profile_failure "$profile" false "$((idx - 1))" "$concurrency" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON"
    return 1
  fi

  stop_queue_sampler "$stop_flag"
  export_request_metrics "$profile" "$request_ids_path" "$pg_container" "$pg_user" "$pg_pass"
  compute_latency_breakdown "$profile" "$responses_path" "$scenario_csv"
  breakdown_json="$(cat "$EVIDENCE_DIR/${profile}-latency-breakdown.json")"
  latency_json="$(compute_latency_metrics "$scenario_csv")"
  p50="$(printf '%s' "$latency_json" | jq -r '.p50')"
  p95="$(printf '%s' "$latency_json" | jq -r '.p95')"
  p99="$(printf '%s' "$latency_json" | jq -r '.p99')"
  api_to_dispatch_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.api_to_dispatch_ms.p95')"
  dispatch_to_ledger_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.dispatch_to_ledger_ms.p95')"
  handler_duration_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.handler_duration_ms.p95')"
  queue_processing_gap_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.queue_processing_gap_ms.p95')"
  accepted_to_processed_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.accepted_to_processed_ms.p95')"
  dominant_latency_stage="$(printf '%s' "$breakdown_json" | jq -r '.dominant_stage')"
  success_rate="1.000000"
  duplicate_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from (select request_id from compliance_ledger.events where request_id = any(array[$(request_ids_to_sql_array "$request_ids_path")]) group by request_id having count(*) > 1) d;")"
  max_queue_depth="$(max_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 3)"
  max_unacked="$(max_for_scenario "$RABBITMQ_TIMELINE_PATH" "$profile" 5)"
  consumers_max="$(max_for_scenario "$RABBITMQ_TIMELINE_PATH" "$profile" 6)"
  capacity_observed="$(consumer_capacity_for_scenario "$RABBITMQ_TIMELINE_PATH" "$profile")"
  peak_outbox_pending="$(max_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 7)"
  peak_inbox_growth="$(growth_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 8)"
  peak_dispatch_records="$(max_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 9)"
  peak_inbox_count="$(max_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 8)"

  if [[ "$duplicate_count" -ne 0 ]]; then
    LAST_FAILURE_CLASS="fail:duplicate-under-load"
    LAST_REASON="Duplicate ledger effects detected during soak"
    echo "FAIL $profile duplicate_count=$duplicate_count" >> "$CHECKS_PATH"
    record_profile_failure "$profile" false "$((idx - 1))" "$concurrency" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON" "$success_rate" "$duplicate_count" "$p50" "$p95" "$p99" "$max_queue_depth" "$max_unacked" 0 0 false 0 "$capacity_observed" "$consumers_max" "$peak_outbox_pending" "$peak_inbox_growth" "$peak_dispatch_records" "$peak_inbox_count" "$api_to_dispatch_p95" "$dispatch_to_ledger_p95" "$handler_duration_p95" "$queue_processing_gap_p95" "$accepted_to_processed_p95" "$dominant_latency_stage"
    return 1
  fi

  echo "PASS $profile request_count=$((idx - 1)) p50=$p50 p95=$p95 p99=$p99 max_queue_depth=$max_queue_depth max_unacked=$max_unacked peak_outbox_pending=$peak_outbox_pending peak_inbox_growth=$peak_inbox_growth peak_dispatch_records=$peak_dispatch_records peak_inbox_count=$peak_inbox_count dominant_latency_stage=$dominant_latency_stage api_to_dispatch_p95_ms=$api_to_dispatch_p95 dispatch_to_ledger_p95_ms=$dispatch_to_ledger_p95 handler_duration_p95_ms=$handler_duration_p95 queue_processing_gap_p95_ms=$queue_processing_gap_p95 accepted_to_processed_p95_ms=$accepted_to_processed_p95" >> "$CHECKS_PATH"
  record_profile_success "$profile" false "$((idx - 1))" "$concurrency" "pass" "pass" "all assertions passed" "$success_rate" "$duplicate_count" "$p50" "$p95" "$p99" "$max_queue_depth" "$max_unacked" 0 0 false 0 "$capacity_observed" "$consumers_max" "$peak_outbox_pending" "$peak_inbox_growth" "$peak_dispatch_records" "$peak_inbox_count" "$api_to_dispatch_p95" "$dispatch_to_ledger_p95" "$handler_duration_p95" "$queue_processing_gap_p95" "$accepted_to_processed_p95" "$dominant_latency_stage"
}

run_chaos_load() {
  local pg_container="$1"
  local pg_user="$2"
  local pg_pass="$3"
  local rabbit_container="$4"
  local profile="diagnostic-chaos-load"
  local stop_flag="$EVIDENCE_DIR/${profile}.stop"
  local responses_path="$EVIDENCE_DIR/${profile}-responses.jsonl"
  local request_ids_path="$EVIDENCE_DIR/${profile}-request-ids.txt"
  local scenario_csv="$EVIDENCE_DIR/${profile}-samples.csv"
  local request_count="$STRESS_REQUEST_COUNT"
  local concurrency="$STRESS_CONCURRENCY"
  local outage_start_utc outage_end_utc
  local batch_pid batch_status="0" duplicate_count max_queue_depth max_unacked consumers_max capacity_observed recovery_seconds
  local latency_json p50 p95 p99 peak_outbox_pending peak_inbox_growth peak_dispatch_records peak_inbox_count breakdown_json dominant_latency_stage
  local api_to_dispatch_p95 dispatch_to_ledger_p95 handler_duration_p95 queue_processing_gap_p95 accepted_to_processed_p95
  local total_expected processed_count outbox_pending queue_depth drained="false" sec

  rm -f "$stop_flag"
  init_scenario_request_artifacts "$profile"
  capture_rabbitmq_snapshot "${profile}-pre" "$rabbit_container"
  start_queue_sampler "$profile" "phase4-chaos" "$stop_flag" "$pg_container" "$pg_user" "$pg_pass" "$rabbit_container"

  (
    append_request_batch "$profile" 1 "$request_count" "$concurrency" "phase4-chaos" "phase4-chaos"
  ) &
  batch_pid=$!

  sleep 1
  outage_start_utc="$(date -u +%FT%TZ)"
  if ! docker stop "$rabbit_container" >/dev/null 2>&1; then
    stop_queue_sampler "$stop_flag"
    LAST_FAILURE_CLASS="fail:broker-restart"
    LAST_REASON="Could not stop RabbitMQ for chaos-load"
    echo "FAIL $profile broker_stop_failed container=$rabbit_container" >> "$CHECKS_PATH"
    record_profile_failure "$profile" false "$request_count" "$concurrency" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON"
    return 1
  fi

  sleep "$CHAOS_BROKER_STOP_SECONDS"
  if ! docker start "$rabbit_container" >/dev/null 2>&1; then
    stop_queue_sampler "$stop_flag"
    LAST_FAILURE_CLASS="fail:broker-restart"
    LAST_REASON="Could not restart RabbitMQ for chaos-load"
    echo "FAIL $profile broker_restart_failed container=$rabbit_container" >> "$CHECKS_PATH"
    record_profile_failure "$profile" false "$request_count" "$concurrency" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON"
    return 1
  fi

  if ! wait_for_rabbit_ready "$rabbit_container" 90; then
    stop_queue_sampler "$stop_flag"
    LAST_FAILURE_CLASS="fail:broker-recovery-timeout"
    LAST_REASON="RabbitMQ did not become ready during chaos-load"
    echo "FAIL $profile broker_ready_timeout container=$rabbit_container" >> "$CHECKS_PATH"
    record_profile_failure "$profile" false "$request_count" "$concurrency" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON"
    return 1
  fi
  outage_end_utc="$(date -u +%FT%TZ)"

  wait "$batch_pid" || batch_status="$?"
  if [[ "$batch_status" != "0" ]]; then
    stop_queue_sampler "$stop_flag"
    LAST_FAILURE_CLASS="fail:load-http"
    LAST_REASON="Chaos-load request batch failed"
    echo "FAIL $profile request_batch_exit=$batch_status" >> "$CHECKS_PATH"
    record_profile_failure "$profile" false "$request_count" "$concurrency" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON"
    return 1
  fi

  prepare_request_ids "$responses_path" "$request_ids_path"
  total_expected="$(wc -l < "$request_ids_path" | tr -d ' ')"
  local recovery_start_epoch recovery_end_epoch
  recovery_start_epoch="$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$outage_end_utc" "+%s" 2>/dev/null || date +%s)"
  for sec in $(seq 1 "$MAX_RECOVERY_SECONDS"); do
    processed_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from compliance_ledger.events where request_id = any(array[$(request_ids_to_sql_array "$request_ids_path")]) and status='processed';")"
    queue_depth="$(extract_queue_field "$(extract_queue_line "$(docker exec "$rabbit_container" rabbitmqctl list_queues -q name messages messages_ready messages_unacknowledged consumers consumer_capacity 2>/dev/null || true)" "compliance")" 2)"
    outbox_pending="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from masstransit.outbox_message;")"
    printf '%s,%s,%s,%s,%s,%s\n' "$(date -u +%FT%TZ)" "$profile" "$sec" "$queue_depth" "$outbox_pending" "$processed_count" >> "$DRAIN_TIMELINE_PATH"
    if [[ "$processed_count" -ge "$total_expected" && "$queue_depth" -eq 0 && "$outbox_pending" -eq 0 ]]; then
      drained="true"
      break
    fi
    sleep 1
  done
  recovery_end_epoch="$(date +%s)"
  recovery_seconds="$(( recovery_end_epoch - recovery_start_epoch ))"

  stop_queue_sampler "$stop_flag"
  capture_rabbitmq_snapshot "${profile}-post" "$rabbit_container"

  if [[ "$drained" != "true" ]]; then
    LAST_FAILURE_CLASS="fail:broker-recovery-timeout"
    LAST_REASON="Chaos-load did not drain after broker recovery"
    echo "FAIL $profile drain_timeout threshold=$MAX_RECOVERY_SECONDS" >> "$CHECKS_PATH"
    record_profile_failure "$profile" false "$request_count" "$concurrency" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON" 0 0 0 0 0 0 0 0 "$recovery_seconds" false 0
    return 1
  fi

  export_request_metrics "$profile" "$request_ids_path" "$pg_container" "$pg_user" "$pg_pass"
  compute_latency_breakdown "$profile" "$responses_path" "$scenario_csv"
  breakdown_json="$(cat "$EVIDENCE_DIR/${profile}-latency-breakdown.json")"
  latency_json="$(compute_latency_metrics "$scenario_csv")"
  p50="$(printf '%s' "$latency_json" | jq -r '.p50')"
  p95="$(printf '%s' "$latency_json" | jq -r '.p95')"
  p99="$(printf '%s' "$latency_json" | jq -r '.p99')"
  api_to_dispatch_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.api_to_dispatch_ms.p95')"
  dispatch_to_ledger_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.dispatch_to_ledger_ms.p95')"
  handler_duration_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.handler_duration_ms.p95')"
  queue_processing_gap_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.queue_processing_gap_ms.p95')"
  accepted_to_processed_p95="$(printf '%s' "$breakdown_json" | jq -r '.stages.accepted_to_processed_ms.p95')"
  dominant_latency_stage="$(printf '%s' "$breakdown_json" | jq -r '.dominant_stage')"
  duplicate_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from (select request_id from compliance_ledger.events where request_id = any(array[$(request_ids_to_sql_array "$request_ids_path")]) group by request_id having count(*) > 1) d;")"
  max_queue_depth="$(max_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 3)"
  max_unacked="$(max_for_scenario "$RABBITMQ_TIMELINE_PATH" "$profile" 5)"
  consumers_max="$(max_for_scenario "$RABBITMQ_TIMELINE_PATH" "$profile" 6)"
  capacity_observed="$(consumer_capacity_for_scenario "$RABBITMQ_TIMELINE_PATH" "$profile")"
  peak_outbox_pending="$(max_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 7)"
  peak_inbox_growth="$(growth_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 8)"
  peak_dispatch_records="$(max_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 9)"
  peak_inbox_count="$(max_for_scenario "$QUEUE_TIMELINE_PATH" "$profile" 8)"

  python3 - "$responses_path" "$scenario_csv" "$CHAOS_CLASSIFICATION_PATH" "$outage_start_utc" "$outage_end_utc" <<'PY'
import csv, json, sys
from datetime import datetime

responses = {}
with open(sys.argv[1], encoding="ascii") as handle:
    for line in handle:
        row = json.loads(line)
        responses[row["checkId"]] = row

ledger = {}
with open(sys.argv[2], newline="") as handle:
    for row in csv.DictReader(handle):
        ledger[row["request_id"]] = row

outage_start = datetime.fromisoformat(sys.argv[4].replace("Z", "+00:00"))
outage_end = datetime.fromisoformat(sys.argv[5].replace("Z", "+00:00"))

with open(sys.argv[3], "w", newline="", encoding="ascii") as handle:
    writer = csv.writer(handle)
    writer.writerow(["request_id", "http_status", "accepted_utc", "outage_bucket", "ledger_status", "ledger_latency_ms"])
    for request_id, response in sorted(responses.items()):
        accepted = datetime.fromisoformat(response["accepted_utc"].replace("Z", "+00:00"))
        if accepted < outage_start:
            bucket = "before_outage"
        elif accepted <= outage_end:
            bucket = "during_outage"
        else:
            bucket = "after_recovery"
        ledger_row = ledger.get(request_id, {})
        writer.writerow([
            request_id,
            response.get("httpCode", ""),
            response.get("accepted_utc", ""),
            bucket,
            ledger_row.get("ledger_status", "missing"),
            ledger_row.get("ledger_latency_ms", "0"),
        ])
PY

  if [[ "$duplicate_count" -ne 0 ]]; then
    LAST_FAILURE_CLASS="fail:duplicate-under-load"
    LAST_REASON="Duplicate ledger effects detected during chaos-load"
    echo "FAIL $profile duplicate_count=$duplicate_count" >> "$CHECKS_PATH"
    record_profile_failure "$profile" false "$request_count" "$concurrency" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON" 1 "$duplicate_count" "$p50" "$p95" "$p99" "$max_queue_depth" "$max_unacked" 0 "$recovery_seconds" false 0 "$capacity_observed" "$consumers_max" "$peak_outbox_pending" "$peak_inbox_growth" "$peak_dispatch_records" "$peak_inbox_count" "$api_to_dispatch_p95" "$dispatch_to_ledger_p95" "$handler_duration_p95" "$queue_processing_gap_p95" "$accepted_to_processed_p95" "$dominant_latency_stage"
    return 1
  fi

  if ! assert_numeric_threshold "$recovery_seconds" "<=" "$MAX_OUTAGE_RECOVERY_SECONDS"; then
    LAST_FAILURE_CLASS="fail:broker-recovery-timeout"
    LAST_REASON="Chaos-load recovery exceeded diagnostic threshold"
    echo "FAIL $profile recovery_seconds=$recovery_seconds threshold=$MAX_OUTAGE_RECOVERY_SECONDS" >> "$CHECKS_PATH"
    record_profile_failure "$profile" false "$request_count" "$concurrency" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON" 1 "$duplicate_count" "$p50" "$p95" "$p99" "$max_queue_depth" "$max_unacked" 0 "$recovery_seconds" false 0 "$capacity_observed" "$consumers_max" "$peak_outbox_pending" "$peak_inbox_growth" "$peak_dispatch_records" "$peak_inbox_count" "$api_to_dispatch_p95" "$dispatch_to_ledger_p95" "$handler_duration_p95" "$queue_processing_gap_p95" "$accepted_to_processed_p95" "$dominant_latency_stage"
    return 1
  fi

  echo "PASS $profile recovery_seconds=$recovery_seconds max_queue_depth=$max_queue_depth max_unacked=$max_unacked peak_outbox_pending=$peak_outbox_pending peak_inbox_growth=$peak_inbox_growth peak_dispatch_records=$peak_dispatch_records peak_inbox_count=$peak_inbox_count dominant_latency_stage=$dominant_latency_stage api_to_dispatch_p95_ms=$api_to_dispatch_p95 dispatch_to_ledger_p95_ms=$dispatch_to_ledger_p95 handler_duration_p95_ms=$handler_duration_p95 queue_processing_gap_p95_ms=$queue_processing_gap_p95 accepted_to_processed_p95_ms=$accepted_to_processed_p95 outage_start=$outage_start_utc outage_end=$outage_end_utc" >> "$CHECKS_PATH"
  record_profile_success "$profile" false "$request_count" "$concurrency" "pass" "pass" "all assertions passed" 1 "$duplicate_count" "$p50" "$p95" "$p99" "$max_queue_depth" "$max_unacked" 0 "$recovery_seconds" false 0 "$capacity_observed" "$consumers_max" "$peak_outbox_pending" "$peak_inbox_growth" "$peak_dispatch_records" "$peak_inbox_count" "$api_to_dispatch_p95" "$dispatch_to_ledger_p95" "$handler_duration_p95" "$queue_processing_gap_p95" "$accepted_to_processed_p95" "$dominant_latency_stage"
}

run_profile() {
  local profile="$1"
  local pg_container="$2"
  local pg_user="$3"
  local pg_pass="$4"
  local rabbit_container="$5"

  case "$profile" in
    release-bounded-load)
      run_load_scenario "$profile" "$LOAD_REQUEST_COUNT" "$LOAD_CONCURRENCY" "phase4-load" "phase4-bounded-load" true true "$pg_container" "$pg_user" "$pg_pass" "$rabbit_container"
      ;;
    release-backlog-recovery)
      run_backlog_recovery "$pg_container" "$pg_user" "$pg_pass" "$rabbit_container"
      ;;
    release-terminal-failure)
      run_terminal_failure true "$pg_container" "$pg_user" "$pg_pass" "$rabbit_container"
      ;;
    diagnostic-stress)
      run_load_scenario "$profile" "$STRESS_REQUEST_COUNT" "$STRESS_CONCURRENCY" "phase4-stress" "phase4-stress" false false "$pg_container" "$pg_user" "$pg_pass" "$rabbit_container"
      ;;
    diagnostic-soak)
      run_soak_profile "$pg_container" "$pg_user" "$pg_pass" "$rabbit_container"
      ;;
    diagnostic-chaos-load)
      run_chaos_load "$pg_container" "$pg_user" "$pg_pass" "$rabbit_container"
      ;;
    *)
      LAST_FAILURE_CLASS="fail:startup"
      LAST_REASON="Unknown PHASE4_PROFILE=$profile"
      return 1
      ;;
  esac
}

selected_profiles() {
  if [[ -z "$PHASE4_PROFILE" ]]; then
    printf '%s\n' \
      "release-bounded-load" \
      "release-backlog-recovery" \
      "release-terminal-failure"
    return
  fi

  case "$PHASE4_PROFILE" in
    release-bounded-load|release-backlog-recovery|release-terminal-failure|diagnostic-stress|diagnostic-soak|diagnostic-chaos-load)
      printf '%s\n' "$PHASE4_PROFILE"
      ;;
    *)
      return 1
      ;;
  esac
}

write_summary() {
  local status="$1"
  python3 - "$PROFILE_RESULTS_PATH" "$SUMMARY_PATH" "$status" "$PROFILE_LABEL" "$BASELINE_VERSION" "$ATTEMPT_GATE_ELIGIBLE" "$EVIDENCE_DIR" "$LAST_FAILURE_CLASS" "$LAST_REASON" <<'PY'
import json, sys

results = []
with open(sys.argv[1], encoding="ascii") as handle:
    for line in handle:
        line = line.strip()
        if line:
            results.append(json.loads(line))

def emit_key(name):
    return name.replace("-", "_")

with open(sys.argv[2], "w", encoding="ascii") as handle:
    handle.write(f"result={sys.argv[3]}\n")
    handle.write(f"profile={sys.argv[4]}\n")
    handle.write(f"baseline_version={sys.argv[5]}\n")
    handle.write(f"gate_eligible={sys.argv[6]}\n")
    handle.write(f"failure_class={sys.argv[8]}\n")
    handle.write(f"reason={sys.argv[9]}\n")
    handle.write(f"profiles_run={','.join(r['profile'] for r in results)}\n")
    for result in results:
        prefix = emit_key(result["profile"])
        handle.write(f"{prefix}_result={result['result']}\n")
        handle.write(f"{prefix}_success_rate={result['success_rate']}\n")
        handle.write(f"{prefix}_duplicate_count={result['duplicate_count']}\n")
        handle.write(f"{prefix}_p50_latency_ms={result['p50_latency_ms']}\n")
        handle.write(f"{prefix}_p95_latency_ms={result['p95_latency_ms']}\n")
        handle.write(f"{prefix}_p99_latency_ms={result['p99_latency_ms']}\n")
        handle.write(f"{prefix}_max_queue_depth={result['max_queue_depth']}\n")
        handle.write(f"{prefix}_max_unacked={result['max_unacked']}\n")
        handle.write(f"{prefix}_drain_seconds={result['drain_seconds']}\n")
        handle.write(f"{prefix}_recovery_seconds={result['recovery_seconds']}\n")
        handle.write(f"{prefix}_terminal_failure_verified={str(result['terminal_failure_verified']).lower()}\n")
        handle.write(f"{prefix}_error_queue_messages={result['error_queue_messages']}\n")
        handle.write(f"{prefix}_consumer_capacity_observed={result['consumer_capacity_observed']}\n")
        handle.write(f"{prefix}_peak_outbox_pending={result['peak_outbox_pending']}\n")
        handle.write(f"{prefix}_peak_inbox_growth={result['peak_inbox_growth']}\n")
        handle.write(f"{prefix}_peak_dispatch_records={result['peak_dispatch_records']}\n")
        handle.write(f"{prefix}_peak_inbox_count={result['peak_inbox_count']}\n")
        handle.write(f"{prefix}_api_to_dispatch_p95_ms={result['api_to_dispatch_p95_ms']}\n")
        handle.write(f"{prefix}_dispatch_to_ledger_p95_ms={result['dispatch_to_ledger_p95_ms']}\n")
        handle.write(f"{prefix}_handler_duration_p95_ms={result['handler_duration_p95_ms']}\n")
        handle.write(f"{prefix}_queue_processing_gap_p95_ms={result['queue_processing_gap_p95_ms']}\n")
        handle.write(f"{prefix}_accepted_to_processed_p95_ms={result['accepted_to_processed_p95_ms']}\n")
        handle.write(f"{prefix}_dominant_latency_stage={result['dominant_latency_stage']}\n")
    handle.write(f"evidence_dir={sys.argv[7]}\n")
PY
}

write_manifest() {
  local status="$1"
  python3 - "$PROFILE_RESULTS_PATH" "$MANIFEST_PATH" "$status" "$PROFILE_LABEL" "$PHASE4_MODE" "$ORCHESTRATION_MODE" "$ATTEMPT_STARTUP_MODE" "$ATTEMPT_GATE_ELIGIBLE" "$BASELINE_VERSION" "$BASELINE_FILE" "$BASELINE_ENVIRONMENT" "$LAST_FAILURE_CLASS" "$LAST_REASON" "$EVIDENCE_DIR" "$MAX_ACCEPTABLE_FAILURE_RATE" "$P95_LEDGER_LATENCY_MS" "$P99_LEDGER_LATENCY_MS" "$MAX_QUEUE_DEPTH" "$MAX_DRAIN_SECONDS" "$MAX_OUTAGE_RECOVERY_SECONDS" "$TERMINAL_FAILURE_ROWS_EXACT" <<'PY'
import json, sys

results = []
with open(sys.argv[1], encoding="ascii") as handle:
    for line in handle:
        line = line.strip()
        if line:
            results.append(json.loads(line))

manifest = {
    "generated_utc": __import__("datetime").datetime.utcnow().replace(microsecond=0).isoformat() + "Z",
    "profile": sys.argv[4],
    "phase4_mode": sys.argv[5],
    "orchestration_mode": sys.argv[6],
    "startup_mode": sys.argv[7],
    "gate_eligible": sys.argv[8] == "true",
    "baseline_version": sys.argv[9],
    "baseline_file": sys.argv[10],
    "environment": sys.argv[11],
    "profiles_run": [r["profile"] for r in results],
    "profile_results": results,
    "thresholds": {
        "max_acceptable_failure_rate": float(sys.argv[15]),
        "bounded_load_p95_latency_ms": float(sys.argv[16]),
        "bounded_load_p99_latency_ms": float(sys.argv[17]),
        "max_queue_depth_release": float(sys.argv[18]),
        "backlog_drain_seconds": float(sys.argv[19]),
        "outage_recovery_seconds": float(sys.argv[20]),
        "terminal_failure_rows_exact": float(sys.argv[21]),
    },
    "publish_confirm_observed": "metric_unavailable",
    "result": sys.argv[3],
    "failure_class": sys.argv[12],
    "reason": sys.argv[13],
    "evidence_dir": sys.argv[14],
}

with open(sys.argv[2], "w", encoding="ascii") as handle:
    json.dump(manifest, handle, indent=2)
PY
}

main() {
  preflight
  load_baseline

  if [[ "$PHASE4_MODE" != "release" && "$PHASE4_MODE" != "diagnostic" ]]; then
    echo "Invalid PHASE4_MODE: $PHASE4_MODE (expected release|diagnostic)"
    exit 1
  fi
  if [[ "$ORCHESTRATION_MODE" != "apphost" && "$ORCHESTRATION_MODE" != "direct" ]]; then
    echo "Invalid ORCHESTRATION_MODE: $ORCHESTRATION_MODE (expected apphost|direct)"
    exit 1
  fi
  if ! profiles="$(selected_profiles)"; then
    echo "Invalid PHASE4_PROFILE: $PHASE4_PROFILE"
    exit 1
  fi

  if [[ -n "$PHASE4_PROFILE" ]]; then
    PROFILE_LABEL="$PHASE4_PROFILE"
  fi

  echo "timestamp_utc,scenario,compliance_messages,compliance_ready,compliance_unacked,compliance_error_messages,outbox_pending,inbox_count,dispatch_count" > "$QUEUE_TIMELINE_PATH"
  echo "timestamp_utc,scenario,compliance_messages,compliance_ready,compliance_unacked,consumers,consumer_capacity,error_queue_messages" > "$RABBITMQ_TIMELINE_PATH"
  echo "timestamp_utc,scenario,source_filter,outbox_pending,inbox_count,dispatch_count,ledger_count" > "$PERSISTENCE_TIMELINE_PATH"
  echo "timestamp_utc,scenario,second,compliance_messages,outbox_pending,processed_count" > "$DRAIN_TIMELINE_PATH"
  echo "scenario,request_id,send_mode,dispatch_created_at_utc,processed_at_utc,ledger_status,ledger_latency_ms,message_id,handler_duration_ms" > "$LOAD_SAMPLES_PATH"

  log "Starting Phase 4 verification"
  if ! start_runtime; then
    write_summary "fail"
    write_manifest "fail"
    record_attempt "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON"
    exit 1
  fi

  local pg_container pg_user pg_pass rabbit_container
  pg_container="$(resolve_postgres_container || true)"
  rabbit_container="$(resolve_rabbit_container || true)"
  if [[ -z "$pg_container" || -z "$rabbit_container" ]]; then
    LAST_FAILURE_CLASS="fail:startup"
    LAST_REASON="Required RabbitMQ/Postgres containers were not found"
    write_summary "fail"
    write_manifest "fail"
    record_attempt "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON"
    cleanup_runtime
    exit 1
  fi

  pg_user="$(docker exec "$pg_container" printenv POSTGRES_USER)"
  pg_pass="$(docker exec "$pg_container" printenv POSTGRES_PASSWORD)"

  local profile
  while IFS= read -r profile; do
    [[ -n "$profile" ]] || continue
    if ! run_profile "$profile" "$pg_container" "$pg_user" "$pg_pass" "$rabbit_container"; then
      write_latency_summary
      write_latency_breakdown_summary
      write_summary "fail"
      write_manifest "fail"
      record_attempt "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON"
      capture_live_aspire_artifacts
      cleanup_runtime
      exit 1
    fi
  done <<< "$profiles"

  write_latency_summary
  write_latency_breakdown_summary
  capture_live_aspire_artifacts
  LAST_FAILURE_CLASS="pass"
  LAST_REASON="all assertions passed"
  write_summary "pass"
  write_manifest "pass"
  record_attempt "pass" "pass" "all assertions passed"
  cleanup_runtime
  log "Phase 4 verification passed"
}

main "$@"
