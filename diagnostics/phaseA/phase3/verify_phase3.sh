#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_DIR="${1:-$ROOT_DIR/diagnostics/phaseA/phase3/evidence/$STAMP}"
API_URL="${API_URL:-http://localhost:5022}"
FALLBACK_API_URL="${FALLBACK_API_URL:-http://localhost:5033}"
REQUEST_COUNT="${REQUEST_COUNT:-2}"
DIAGNOSTIC_REPLAY_COUNT="${DIAGNOSTIC_REPLAY_COUNT:-2}"
STABILITY_RUNS="${STABILITY_RUNS:-1}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"
PHASE3_MODE="${PHASE3_MODE:-strict}"
ORCHESTRATION_MODE="${ORCHESTRATION_MODE:-apphost}"
PHASE3_PROFILE="${PHASE3_PROFILE:-release-resilience}"
BASELINE_VERSION="${BASELINE_VERSION:-backend-sli-baseline.v1}"
STRICT_STARTUP_WAIT_SECONDS="${STRICT_STARTUP_WAIT_SECONDS:-90}"
HYBRID_STARTUP_WAIT_SECONDS="${HYBRID_STARTUP_WAIT_SECONDS:-20}"
STRICT_WORKER_WAIT_SECONDS="${STRICT_WORKER_WAIT_SECONDS:-120}"
BROKER_READY_WAIT_SECONDS="${BROKER_READY_WAIT_SECONDS:-45}"
BROKER_RECOVERY_POLL_SECONDS="${BROKER_RECOVERY_POLL_SECONDS:-240}"
OUTBOX_LOCK_RELEASE_PROBE="${OUTBOX_LOCK_RELEASE_PROBE:-false}"

LAST_FAILURE_CLASS="unknown"
LAST_REASON=""
FINAL_ATTEMPT=0
SUCCESS_STREAK=0
ATTEMPT_API_URL="$API_URL"
ATTEMPT_STARTUP_MODE="aspire"
ATTEMPT_GATE_ELIGIBLE="true"
ATTEMPT_TELEMETRY_COMPLETE="true"
LAST_REPEAT_FAILURE_CLASS=""
REPEAT_FAILURE_COUNT=0
LAST_OUTAGE_CLASSIFICATION="unknown"
LAST_DECISION_LANE="runtime-patch"
ACTIVE_RABBIT_CONTAINER=""
ACTIVE_PG_CONTAINER=""
ATTEMPT_API_LOG=""
ATTEMPT_WORKER_LOG=""
DIRECT_RABBIT_USER="${DIRECT_RABBIT_USER:-diag}"
DIRECT_RABBIT_PASS="${DIRECT_RABBIT_PASS:-example-rabbit-password}"
DIRECT_PG_USER="${DIRECT_PG_USER:-postgres}"
DIRECT_PG_PASS="${DIRECT_PG_PASS:-example-postgres-password}"
DIRECT_DB="${DIRECT_DB:-compliancedb}"
DIRECT_RABBIT_URI=""
DIRECT_PG_CONN=""
PROBE_APPLIED="false"
PROBE_RECOVERED="false"
PROBE_OWNER_PID=""
PROBE_NOTE="not-run"

mkdir -p "$EVIDENCE_DIR"
ATTEMPTS_LOG="$EVIDENCE_DIR/attempts.log"
SUMMARY_PATH="$EVIDENCE_DIR/summary.txt"
MANIFEST_PATH="$EVIDENCE_DIR/manifest.json"

log() {
  printf "[%s] %s\n" "$(date -u +%FT%TZ)" "$*"
}

record_attempt() {
  local attempt="$1"
  local status="$2"
  local klass="$3"
  local reason="$4"
  local streak="$5"
  printf "%s|attempt=%s|status=%s|class=%s|streak=%s|reason=%s\n" \
    "$(date -u +%FT%TZ)" "$attempt" "$status" "$klass" "$streak" "$reason" >> "$ATTEMPTS_LOG"
}

sanitize_csv_value() {
  local value="${1:-}"
  value="${value//$'\n'/ }"
  value="${value//$'\r'/ }"
  value="${value//,/;}"
  printf '%s' "$value"
}

classify_lock_timeline() {
  local timeline_path="$1"
  local observer_dump="$2"

  if [[ ! -f "$timeline_path" ]]; then
    echo "unknown"
    return
  fi

  local sample_count unique_pid_count any_sequence_progress fault_signal
  sample_count="$(awk -F, 'NR>1 {c++} END {print c+0}' "$timeline_path")"
  unique_pid_count="$(awk -F, 'NR>1 && $12 != "null" && $12 != "" {seen[$12]=1} END {print length(seen)+0}' "$timeline_path")"
  any_sequence_progress="$(awk -F, 'NR>1 && $10 != "null" && $10 != "" {print 1; exit} END {print 0}' "$timeline_path")"
  fault_signal=0
  if [[ -f "$observer_dump" ]] && rg -q "MT_OBSERVER_(SEND|PUBLISH)_FAULT|MT_OBSERVER_BUS_START_FAULTED|MT_OBSERVER_BUS_STOP_FAULTED" "$observer_dump"; then
    fault_signal=1
  fi

  if [[ "$sample_count" -eq 0 ]]; then
    echo "unknown"
    return
  fi

  if [[ "$any_sequence_progress" -eq 0 && "$unique_pid_count" -eq 1 ]]; then
    echo "dispatcher-stuck-lock-holder"
    return
  fi

  if [[ "$any_sequence_progress" -eq 0 && "$unique_pid_count" -gt 1 ]]; then
    echo "lock-owner-churn-no-progress"
    return
  fi

  if [[ "$fault_signal" -eq 1 ]]; then
    echo "reconnect-fault-loop"
    return
  fi

  echo "unknown"
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
      if [[ -f "$EVIDENCE_DIR/attempt-$FINAL_ATTEMPT/worker-direct.pid" ]]; then
        local worker_pid
        worker_pid="$(cat "$EVIDENCE_DIR/attempt-$FINAL_ATTEMPT/worker-direct.pid" 2>/dev/null || true)"
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

capture_aspire_startup_artifacts() {
  local attempt_dir="$1"
  local aspire_dir="$2"
  local snapshot="$attempt_dir/startup-snapshot.txt"

  {
    echo "timestamp_utc=$(date -u +%FT%TZ)"
    echo "aspire_run_dir=$aspire_dir"
    echo "api_url=$ATTEMPT_API_URL"
    echo "phase3_mode=$PHASE3_MODE"
    echo "---- pgrep ----"
    pgrep -fal "Sentinel.AppHost|Sentinel.Api|Sentinel.Worker|/Sentinel.Api/bin/|/Sentinel.Worker/bin/" || true
    echo "---- docker ----"
    docker ps --format '{{.Names}}\t{{.Status}}' | grep -E 'messaging-|postgres-' || true
    echo "---- lsof:5022 ----"
    lsof -nP -iTCP:5022 -sTCP:LISTEN || true
  } > "$snapshot"

  if [[ -n "$aspire_dir" && -d "$aspire_dir" ]]; then
    mkdir -p "$attempt_dir/aspire-resource-logs"
    find "$aspire_dir" -maxdepth 1 -type f \
      \( -name 'sentinel-api-*' -o -name 'sentinel-worker-*' -o -name 'resource-*' \) \
      -exec cp {} "$attempt_dir/aspire-resource-logs/" \; 2>/dev/null || true
  fi
}

capture_live_aspire_artifacts() {
  local attempt_dir="$1"
  local aspire_dir_hint="$2"
  local live_dir=""

  live_dir="$(resolve_latest_aspire_run_dir || true)"
  if [[ -n "$live_dir" ]]; then
    capture_aspire_startup_artifacts "$attempt_dir" "$live_dir"
  else
    capture_aspire_startup_artifacts "$attempt_dir" "$aspire_dir_hint"
  fi
}

has_signal() {
  local pattern="$1"
  local primary_log="$2"
  local resource_dir="$3"

  if [[ -f "$primary_log" ]] && grep -Fq "$pattern" "$primary_log"; then
    return 0
  fi

  if [[ -d "$resource_dir" ]] && rg -Fq "$pattern" "$resource_dir"; then
    return 0
  fi

  if [[ -n "${ATTEMPT_API_LOG:-}" && -f "$ATTEMPT_API_LOG" ]] && grep -Fq "$pattern" "$ATTEMPT_API_LOG"; then
    return 0
  fi

  if [[ -n "${ATTEMPT_WORKER_LOG:-}" && -f "$ATTEMPT_WORKER_LOG" ]] && grep -Fq "$pattern" "$ATTEMPT_WORKER_LOG"; then
    return 0
  fi

  return 1
}

capture_runtime_observer_dump() {
  local attempt_dir="$1"
  local sql_out_path="$2"
  local aspire_dir="${3:-}"
  local observer_dump="$attempt_dir/observer-events.log"
  : > "$observer_dump"

  if [[ -f "$attempt_dir/apphost.log" ]]; then
    rg "MT_OBSERVER_|COMPLIANCE_" \
      "$attempt_dir/apphost.log" >> "$observer_dump" 2>/dev/null || true
  fi

  if [[ -d "$attempt_dir/aspire-resource-logs" ]]; then
    rg "MT_OBSERVER_|COMPLIANCE_" \
      "$attempt_dir/aspire-resource-logs"/* >> "$observer_dump" 2>/dev/null || true
  fi

  if [[ -n "${ATTEMPT_API_LOG:-}" && -f "$ATTEMPT_API_LOG" ]]; then
    rg "MT_OBSERVER_|COMPLIANCE_" "$ATTEMPT_API_LOG" >> "$observer_dump" 2>/dev/null || true
  fi

  if [[ -n "${ATTEMPT_WORKER_LOG:-}" && -f "$ATTEMPT_WORKER_LOG" ]]; then
    rg "MT_OBSERVER_|COMPLIANCE_" "$ATTEMPT_WORKER_LOG" >> "$observer_dump" 2>/dev/null || true
  fi

  if [[ -n "$aspire_dir" && -d "$aspire_dir" ]]; then
    rg "MT_OBSERVER_|COMPLIANCE_" "$aspire_dir" \
      -g 'sentinel-api-*_out_*' \
      -g 'sentinel-worker-*_out_*' \
      -g 'sentinel-api-*_err_*' \
      -g 'sentinel-worker-*_err_*' >> "$observer_dump" 2>/dev/null || true
  fi

  {
    echo "observer_dump_start"
    cat "$observer_dump" 2>/dev/null || true
    echo "observer_dump_end"
  } >> "$sql_out_path"

  if rg -q "MT_OBSERVER_|COMPLIANCE_" "$observer_dump" 2>/dev/null; then
    echo "observer_signal_present=true" >> "$sql_out_path"
  else
    ATTEMPT_TELEMETRY_COMPLETE="false"
    echo "observer_signal_present=false" >> "$sql_out_path"
  fi
}

detect_startup_failure_kind() {
  local attempt_dir="$1"
  if [[ "$ORCHESTRATION_MODE" == "direct" ]]; then
    local api_pid worker_pid
    api_pid="$(cat "$attempt_dir/api-direct.pid" 2>/dev/null || true)"
    worker_pid="$(cat "$attempt_dir/worker-direct.pid" 2>/dev/null || true)"
    if [[ -n "$api_pid" ]] && ! kill -0 "$api_pid" 2>/dev/null; then
      echo "startup-crash"
      return
    fi
    if [[ -n "$worker_pid" ]] && ! kill -0 "$worker_pid" 2>/dev/null; then
      echo "startup-crash"
      return
    fi
    echo "startup-timeout"
    return
  fi

  if find "$attempt_dir/aspire-resource-logs" -type f -name 'sentinel-api-*_err_*' -size +0c 2>/dev/null | grep -q .; then
    echo "startup-crash"
    return
  fi

  if find "$attempt_dir/aspire-resource-logs" -type f -name 'sentinel-worker-*_err_*' -size +0c 2>/dev/null | grep -q .; then
    echo "startup-crash"
    return
  fi

  echo "startup-timeout"
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

resolve_rabbit_image_tag() {
  local tag="${Sentinel__RabbitImageTag:-4.2-management}"
  if [[ -z "$tag" ]]; then
    tag="4.2-management"
  fi
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

db_query() {
  local pg_container="$1"
  local pg_user="$2"
  local pg_pass="$3"
  local sql="$4"
  docker exec -e PGPASSWORD="$pg_pass" "$pg_container" psql -U "$pg_user" -d compliancedb -Atc "$sql"
}

resolve_container_port() {
  local container="$1"
  local internal_port="$2"
  docker port "$container" "$internal_port" | head -n1 | awk -F: '{print $NF}'
}

wait_for_rabbit_ready() {
  local rabbit_container="$1"
  local max_seconds="$2"
  local rabbit_port=""
  rabbit_port="$(resolve_container_port "$rabbit_container" "5672/tcp" || true)"

  for _ in $(seq 1 "$max_seconds"); do
    local running="false"
    running="$(docker inspect -f '{{.State.Running}}' "$rabbit_container" 2>/dev/null || echo "false")"

    if [[ "$running" == "true" ]]; then
      if docker exec "$rabbit_container" rabbitmq-diagnostics -q ping >/dev/null 2>&1; then
        if [[ -n "$rabbit_port" ]] && curl -sS -m 2 "http://localhost:${rabbit_port}" >/dev/null 2>&1; then
          return 0
        fi

        # AMQP port is not HTTP, but successful ping still means broker is ready.
        if [[ -n "$rabbit_port" ]]; then
          return 0
        fi
      fi
    fi

    sleep 1
  done

  return 1
}

append_outbox_snapshot() {
  local sql_out_path="$1"
  local pg_container="$2"
  local pg_user="$3"
  local pg_pass="$4"
  local prefix="$5"

  local outbox_count outbox_state_count inbox_state_count
  outbox_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from masstransit.outbox_message;")"
  outbox_state_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from masstransit.outbox_state;")"
  inbox_state_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from masstransit.inbox_state;")"

  {
    echo "${prefix}_outbox_message_count=${outbox_count}"
    echo "${prefix}_outbox_state_count=${outbox_state_count}"
    echo "${prefix}_inbox_state_count=${inbox_state_count}"
    echo "${prefix}_outbox_state_top5_start"
    db_query "$pg_container" "$pg_user" "$pg_pass" "select coalesce(outbox_id::text,'null') || '|' || coalesce(created::text,'null') || '|' || coalesce(delivered::text,'null') || '|' || coalesce(last_sequence_number::text,'null') || '|' || coalesce(lock_id::text,'null') from masstransit.outbox_state order by created desc limit 5;" || true
    echo "${prefix}_outbox_state_top5_end"
    echo "${prefix}_outbox_message_top5_start"
    db_query "$pg_container" "$pg_user" "$pg_pass" "select coalesce(message_id::text,'null') || '|' || coalesce(enqueue_time::text,'null') || '|' || coalesce(sequence_number::text,'null') from masstransit.outbox_message order by enqueue_time desc limit 5;" || true
    echo "${prefix}_outbox_message_top5_end"
  } >> "$sql_out_path"
}

append_outbox_lock_snapshot() {
  local sql_out_path="$1"
  local pg_container="$2"
  local pg_user="$3"
  local pg_pass="$4"
  local prefix="$5"

  {
    echo "${prefix}_outbox_locks_start"
    db_query "$pg_container" "$pg_user" "$pg_pass" "
      select
        coalesce(a.pid::text,'null') || '|' ||
        coalesce(a.application_name,'null') || '|' ||
        coalesce(a.state,'null') || '|' ||
        coalesce(a.xact_start::text,'null') || '|' ||
        coalesce(a.state_change::text,'null') || '|' ||
        coalesce(l.mode,'null') || '|' ||
        coalesce(l.granted::text,'null') || '|' ||
        coalesce(c.relname,'null')
      from pg_locks l
      join pg_stat_activity a on a.pid = l.pid
      left join pg_class c on c.oid = l.relation
      left join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'masstransit'
        and c.relname in ('outbox_state','outbox_message')
      order by a.pid, c.relname, l.mode;
    " || true
    echo "${prefix}_outbox_locks_end"

    echo "${prefix}_outbox_activity_start"
    db_query "$pg_container" "$pg_user" "$pg_pass" "
      select
        coalesce(pid::text,'null') || '|' ||
        coalesce(application_name,'null') || '|' ||
        coalesce(state,'null') || '|' ||
        coalesce(wait_event_type,'null') || '|' ||
        coalesce(wait_event,'null') || '|' ||
        coalesce(substr(query, 1, 160),'null')
      from pg_stat_activity
      where datname = 'compliancedb'
        and query ilike '%masstransit.outbox%'
      order by pid;
    " || true
    echo "${prefix}_outbox_activity_end"
  } >> "$sql_out_path"
}

run_fault_matrix_diagnostics() {
  local checks_path="$1"
  local sql_out_path="$2"
  local outage_check_id="$3"
  local pg_container="$4"
  local pg_user="$5"
  local pg_pass="$6"

  local api_pid worker_pid api_recovery worker_recovery

  api_pid="$(pgrep -f "/Sentinel.Api/bin/" | head -n1 || true)"
  if [[ -n "$api_pid" ]]; then
    kill "$api_pid" 2>/dev/null || true
    sleep 6
    api_recovery="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from compliance_ledger.events where request_id='${outage_check_id}'::uuid and status='processed';")"
    echo "MATRIX api_restart requestId=$outage_check_id processed_count=$api_recovery" >> "$checks_path"
    echo "fault_matrix_api_restart_processed_count=$api_recovery" >> "$sql_out_path"
  else
    echo "MATRIX api_restart requestId=$outage_check_id skipped=api_pid_missing" >> "$checks_path"
  fi

  worker_pid="$(pgrep -f "/Sentinel.Worker/bin/" | head -n1 || true)"
  if [[ -n "$worker_pid" ]]; then
    kill "$worker_pid" 2>/dev/null || true
    sleep 6
    worker_recovery="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from compliance_ledger.events where request_id='${outage_check_id}'::uuid and status='processed';")"
    echo "MATRIX worker_restart requestId=$outage_check_id processed_count=$worker_recovery" >> "$checks_path"
    echo "fault_matrix_worker_restart_processed_count=$worker_recovery" >> "$sql_out_path"
  else
    echo "MATRIX worker_restart requestId=$outage_check_id skipped=worker_pid_missing" >> "$checks_path"
  fi
}

start_api_fallback() {
  local attempt_dir="$1"
  local rabbit_container pg_container
  rabbit_container="$(resolve_rabbit_container || true)"
  pg_container="$(resolve_postgres_container || true)"

  if [[ -z "$rabbit_container" || -z "$pg_container" ]]; then
    return 1
  fi

  local rabbit_port rabbit_user rabbit_pass rabbit_uri
  rabbit_port="$(resolve_container_port "$rabbit_container" "5672/tcp")"
  rabbit_user="$(docker exec "$rabbit_container" printenv RABBITMQ_DEFAULT_USER)"
  rabbit_pass="$(docker exec "$rabbit_container" printenv RABBITMQ_DEFAULT_PASS)"
  rabbit_uri="amqp://${rabbit_user}:${rabbit_pass}@localhost:${rabbit_port}/"

  local pg_port pg_user pg_pass pg_conn
  pg_port="$(resolve_container_port "$pg_container" "5432/tcp")"
  pg_user="$(docker exec "$pg_container" printenv POSTGRES_USER)"
  pg_pass="$(docker exec "$pg_container" printenv POSTGRES_PASSWORD)"
  pg_conn="Host=localhost;Port=${pg_port};Database=compliancedb;Username=${pg_user};Password=${pg_pass};Application Name=sentinel-api-fallback"

  (
    cd "$ROOT_DIR"
    ASPNETCORE_URLS="$FALLBACK_API_URL" \
    ConnectionStrings__messaging="$rabbit_uri" \
      ConnectionStrings__compliancedb="$pg_conn" \
      ConnectionStrings__compliancedb_admin="$pg_conn" \
      Sentinel__DbAppRole="sentinel_app" \
      Sentinel__DbAppRolePassword="example-app-role-password" \
      Sentinel__EnableDiagnosticsEndpoints="true" \
      dotnet run --project Sentinel.Api --no-build --no-launch-profile > "$attempt_dir/api-fallback.log" 2>&1
  ) &
  echo "$!" > "$attempt_dir/api-fallback.pid"
  ATTEMPT_API_URL="$FALLBACK_API_URL"
  ATTEMPT_STARTUP_MODE="fallback"
  ATTEMPT_GATE_ELIGIBLE="false"
}

start_worker_fallback() {
  local attempt_dir="$1"
  local rabbit_container pg_container
  rabbit_container="$(resolve_rabbit_container || true)"
  pg_container="$(resolve_postgres_container || true)"

  if [[ -z "$rabbit_container" || -z "$pg_container" ]]; then
    return 1
  fi

  local rabbit_port rabbit_user rabbit_pass rabbit_uri
  rabbit_port="$(resolve_container_port "$rabbit_container" "5672/tcp")"
  rabbit_user="$(docker exec "$rabbit_container" printenv RABBITMQ_DEFAULT_USER)"
  rabbit_pass="$(docker exec "$rabbit_container" printenv RABBITMQ_DEFAULT_PASS)"
  rabbit_uri="amqp://${rabbit_user}:${rabbit_pass}@localhost:${rabbit_port}/"

  local pg_port pg_user pg_pass pg_conn
  pg_port="$(resolve_container_port "$pg_container" "5432/tcp")"
  pg_user="$(docker exec "$pg_container" printenv POSTGRES_USER)"
  pg_pass="$(docker exec "$pg_container" printenv POSTGRES_PASSWORD)"
  pg_conn="Host=localhost;Port=${pg_port};Database=compliancedb;Username=${pg_user};Password=${pg_pass};Application Name=sentinel-worker-fallback"

  (
    cd "$ROOT_DIR"
    ConnectionStrings__messaging="$rabbit_uri" \
      ConnectionStrings__compliancedb="$pg_conn" \
      ConnectionStrings__compliancedb_admin="$pg_conn" \
      Sentinel__DbAppRole="sentinel_app" \
      Sentinel__DbAppRolePassword="example-app-role-password" \
      dotnet run --project Sentinel.Worker --no-build --no-launch-profile > "$attempt_dir/worker-fallback.log" 2>&1
  ) &
  echo "$!" > "$attempt_dir/worker-fallback.pid"
  ATTEMPT_STARTUP_MODE="fallback"
  ATTEMPT_GATE_ELIGIBLE="false"
}

start_direct_infra() {
  local attempt_dir="$1"
  local rabbit_tag safe_tag suffix rabbit_port pg_port
  rabbit_tag="$(resolve_rabbit_image_tag)"
  safe_tag="$(echo "$rabbit_tag" | tr '.:' '__')"
  suffix="$(date -u +%s)-$RANDOM"

  ACTIVE_RABBIT_CONTAINER="sentinel-phase3-rabbit-${safe_tag}-${suffix}"
  ACTIVE_PG_CONTAINER="sentinel-phase3-pg-${suffix}"

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

  {
    echo "mode=direct"
    echo "rabbit_container=$ACTIVE_RABBIT_CONTAINER"
    echo "postgres_container=$ACTIVE_PG_CONTAINER"
    echo "rabbit_tag=$rabbit_tag"
    echo "rabbit_uri=$DIRECT_RABBIT_URI"
    echo "postgres_conn=$DIRECT_PG_CONN"
  } > "$attempt_dir/direct-runtime.txt"

  return 0
}

start_direct_runtime() {
  local attempt_dir="$1"
  ATTEMPT_API_URL="$API_URL"
  ATTEMPT_API_LOG="$attempt_dir/api-direct.log"
  ATTEMPT_WORKER_LOG="$attempt_dir/worker-direct.log"
  ATTEMPT_STARTUP_MODE="direct"
  ATTEMPT_GATE_ELIGIBLE="true"

  if ! start_direct_infra "$attempt_dir"; then
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
  echo "$!" > "$attempt_dir/worker-direct.pid"

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
  echo "$!" > "$attempt_dir/api-direct.pid"

  return 0
}

assert_trace_continuity() {
  local apphost_log="$1"
  local resource_logs_dir="$2"
  local request_ids_path="$3"
  local checks_path="$4"
  local sql_out_path="$5"
  local pg_container="$6"
  local pg_user="$7"
  local pg_pass="$8"

  local req_id
  while IFS= read -r req_id; do
    [[ -z "$req_id" ]] && continue

    local api_received api_dispatched worker_received worker_processed ledger_written
    api_received=0
    api_dispatched=0
    worker_received=0
    worker_processed=0
    ledger_written=0
    has_signal "COMPLIANCE_API_RECEIVED requestId=$req_id" "$apphost_log" "$resource_logs_dir" && api_received=1
    has_signal "COMPLIANCE_API_DISPATCHED requestId=$req_id" "$apphost_log" "$resource_logs_dir" && api_dispatched=1
    has_signal "COMPLIANCE_WORKER_RECEIVED requestId=$req_id" "$apphost_log" "$resource_logs_dir" && worker_received=1
    has_signal "COMPLIANCE_WORKER_PROCESSED requestId=$req_id" "$apphost_log" "$resource_logs_dir" && worker_processed=1
    has_signal "COMPLIANCE_LEDGER_WRITTEN requestId=$req_id" "$apphost_log" "$resource_logs_dir" && ledger_written=1

    local dispatch_count=0 ledger_status="" ledger_count=0 settled="false"
    for _ in $(seq 1 60); do
      dispatch_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from masstransit.dispatch_records where request_id='${req_id}'::uuid;")"
      ledger_status="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select status from compliance_ledger.events where request_id='${req_id}'::uuid order by processed_at_utc desc limit 1;")"
      ledger_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from compliance_ledger.events where request_id='${req_id}'::uuid;")"

      if [[ "$dispatch_count" -ge 1 && "$ledger_count" -ge 1 && "$ledger_status" == "processed" ]]; then
        settled="true"
        break
      fi

      sleep 1
    done

    {
      echo "trace_request_id=$req_id"
      echo "trace_dispatch_count=$dispatch_count"
      echo "trace_ledger_status=$ledger_status"
      echo "trace_ledger_count=$ledger_count"
      echo "---"
    } >> "$sql_out_path"

    if [[ "$settled" != "true" ]]; then
      LAST_FAILURE_CLASS="fail:trace-continuity"
      LAST_REASON="Trace continuity mismatch for requestId=$req_id"
      echo "FAIL trace-continuity requestId=$req_id dispatch_count=$dispatch_count ledger_count=$ledger_count ledger_status=$ledger_status" >> "$checks_path"
      return 1
    fi

    if [[ "$api_received" -lt 1 || "$api_dispatched" -lt 1 || "$worker_received" -lt 1 || "$worker_processed" -lt 1 || "$ledger_written" -lt 1 ]]; then
      echo "PASS trace-continuity-fallback requestId=$req_id reason=apphost-log-forwarding-missing api_received=$api_received api_dispatched=$api_dispatched worker_received=$worker_received worker_processed=$worker_processed ledger_written=$ledger_written" >> "$checks_path"
    else
      echo "PASS trace-continuity requestId=$req_id" >> "$checks_path"
    fi
  done < "$request_ids_path"
}

assert_idempotency() {
  local attempt="$1"
  local apphost_log="$2"
  local resource_logs_dir="$3"
  local attempt_dir="$4"
  local checks_path="$5"
  local sql_out_path="$6"
  local pg_container="$7"
  local pg_user="$8"
  local pg_pass="$9"
  local aspire_dir="${10:-}"

  local replay_payload replay_http replay_request_id replay_message_id replay_count
  replay_payload="$(jq -nc \
    --arg content "phase3-duplicate-replay-attempt-$attempt" \
    --arg source "phase3-script" \
    --argjson replayCount "$DIAGNOSTIC_REPLAY_COUNT" \
    '{content:$content,source:$source,replayCount:$replayCount}')"

  replay_http="$(curl -sS --max-time 20 -o "$attempt_dir/duplicate-replay.json" -w "%{http_code}" \
    -X POST "$ATTEMPT_API_URL/api/diagnostics/messaging/replay-duplicate" \
    -H "Content-Type: application/json" \
    --data-binary "$replay_payload" || true)"

  if [[ "$replay_http" != "200" ]]; then
    LAST_FAILURE_CLASS="fail:idempotency"
    LAST_REASON="Duplicate replay endpoint returned HTTP $replay_http"
    echo "FAIL idempotency replay_endpoint_http=$replay_http" >> "$checks_path"
    return 1
  fi

  replay_request_id="$(jq -r '.requestId // empty' "$attempt_dir/duplicate-replay.json")"
  replay_message_id="$(jq -r '.messageId // empty' "$attempt_dir/duplicate-replay.json")"
  replay_count="$(jq -r '.replayCount // 0' "$attempt_dir/duplicate-replay.json")"

  if [[ -z "$replay_request_id" || -z "$replay_message_id" || "$replay_count" -lt 2 ]]; then
    LAST_FAILURE_CLASS="fail:idempotency"
    LAST_REASON="Duplicate replay response missing request/message id or replayCount"
    echo "FAIL idempotency invalid_replay_response requestId=$replay_request_id messageId=$replay_message_id replayCount=$replay_count" >> "$checks_path"
    return 1
  fi

  sleep 5
  capture_live_aspire_artifacts "$attempt_dir" "$aspire_dir"

  local replay_dispatch_count replay_ledger_count replay_ledger_status duplicate_log_count duplicate_receive_count duplicate_handler_count
  replay_dispatch_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from masstransit.dispatch_records where request_id='${replay_request_id}'::uuid and send_mode='diagnostic-duplicate-replay';")"
  replay_ledger_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from compliance_ledger.events where message_id='${replay_message_id}'::uuid;")"
  replay_ledger_status="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select status from compliance_ledger.events where message_id='${replay_message_id}'::uuid order by processed_at_utc desc limit 1;")"
  duplicate_log_count=0
  has_signal "COMPLIANCE_DUPLICATE_SKIPPED requestId=$replay_request_id messageId=$replay_message_id" "$apphost_log" "$resource_logs_dir" && duplicate_log_count=1
  duplicate_receive_count="$({
    [[ -f "$apphost_log" ]] && grep -F -c "transportMessageId=$replay_message_id" "$apphost_log" 2>/dev/null || true
    if [[ -d "$resource_logs_dir" ]]; then
      rg -F -c "transportMessageId=$replay_message_id" "$resource_logs_dir" 2>/dev/null || true
    fi
    if [[ -n "${ATTEMPT_WORKER_LOG:-}" && -f "$ATTEMPT_WORKER_LOG" ]]; then
      grep -F -c "transportMessageId=$replay_message_id" "$ATTEMPT_WORKER_LOG" 2>/dev/null || true
    fi
  } | awk -F: '{sum += $NF} END {print sum+0}')"
  duplicate_handler_count="$({
    [[ -f "$apphost_log" ]] && grep -F -c "COMPLIANCE_WORKER_RECEIVED requestId=$replay_request_id" "$apphost_log" 2>/dev/null || true
    if [[ -d "$resource_logs_dir" ]]; then
      rg -F -c "COMPLIANCE_WORKER_RECEIVED requestId=$replay_request_id" "$resource_logs_dir" 2>/dev/null || true
    fi
    if [[ -n "${ATTEMPT_WORKER_LOG:-}" && -f "$ATTEMPT_WORKER_LOG" ]]; then
      grep -F -c "COMPLIANCE_WORKER_RECEIVED requestId=$replay_request_id" "$ATTEMPT_WORKER_LOG" 2>/dev/null || true
    fi
  } | awk -F: '{sum += $NF} END {print sum+0}')"

  {
    echo "idempotency_replay_request_id=$replay_request_id"
    echo "idempotency_replay_message_id=$replay_message_id"
    echo "idempotency_replay_count=$replay_count"
    echo "idempotency_dispatch_count=$replay_dispatch_count"
    echo "idempotency_ledger_count=$replay_ledger_count"
    echo "idempotency_ledger_status=$replay_ledger_status"
    echo "idempotency_duplicate_log_count=$duplicate_log_count"
    echo "idempotency_receive_pre_count=$duplicate_receive_count"
    echo "idempotency_handler_count=$duplicate_handler_count"
  } >> "$sql_out_path"

  if [[ "$replay_dispatch_count" -lt 2 ]]; then
    LAST_FAILURE_CLASS="fail:idempotency"
    LAST_REASON="Duplicate replay dispatch count too low: $replay_dispatch_count"
    echo "FAIL idempotency dispatch_count=$replay_dispatch_count requestId=$replay_request_id" >> "$checks_path"
    return 1
  fi

  if [[ "$replay_ledger_count" -ne 1 || "$replay_ledger_status" != "processed" ]]; then
    LAST_FAILURE_CLASS="fail:idempotency"
    LAST_REASON="Duplicate replay ledger assertion failed: count=$replay_ledger_count status=$replay_ledger_status"
    echo "FAIL idempotency ledger_count=$replay_ledger_count ledger_status=$replay_ledger_status messageId=$replay_message_id" >> "$checks_path"
    return 1
  fi

  if [[ "$duplicate_log_count" -lt 1 ]]; then
    if [[ "$duplicate_receive_count" -ge 2 && "$duplicate_handler_count" -eq 1 ]]; then
      echo "PASS idempotency-inbox requestId=$replay_request_id messageId=$replay_message_id receive_pre_count=$duplicate_receive_count handler_count=$duplicate_handler_count" >> "$checks_path"
    else
      echo "PASS idempotency-fallback requestId=$replay_request_id messageId=$replay_message_id reason=duplicate-suppression-log-missing receive_pre_count=$duplicate_receive_count handler_count=$duplicate_handler_count" >> "$checks_path"
    fi
  else
    echo "PASS idempotency requestId=$replay_request_id messageId=$replay_message_id duplicate_log_count=$duplicate_log_count" >> "$checks_path"
  fi
}

assert_broker_outage_recovery() {
  local attempt="$1"
  local attempt_dir="$2"
  local checks_path="$3"
  local sql_out_path="$4"
  local pg_container="$5"
  local pg_user="$6"
  local pg_pass="$7"

  local rabbit_container
  rabbit_container="$(resolve_rabbit_container || true)"
  if [[ -z "$rabbit_container" ]]; then
    LAST_FAILURE_CLASS="fail:broker-restart"
    LAST_REASON="Could not find messaging-* container"
    echo "FAIL broker-outage rabbit_container_missing" >> "$checks_path"
    return 1
  fi

  local outage_body outage_http outage_check_id
  outage_body="{\"content\":\"phase3-broker-outage-attempt-$attempt\",\"source\":\"phase3-outage\"}"
  local broker_stopped_utc broker_restart_utc broker_ready_utc=""
  broker_stopped_utc="$(date -u +%FT%TZ)"

  if ! docker stop "$rabbit_container" >/dev/null; then
    LAST_FAILURE_CLASS="fail:broker-restart"
    LAST_REASON="Failed stopping RabbitMQ container $rabbit_container"
    echo "FAIL broker-outage stop_failed container=$rabbit_container" >> "$checks_path"
    return 1
  fi

  local outage_ts
  outage_ts="$(date -u +%FT%TZ)"

  outage_http="$(curl -sS --max-time 20 -o "$EVIDENCE_DIR/attempt-$attempt/outage-post.json" -w "%{http_code}" \
    -X POST "$ATTEMPT_API_URL/api/compliance/check" \
    -H "Content-Type: application/json" \
    --data-binary "$outage_body" || true)"

  if [[ "$outage_http" != "200" ]]; then
    LAST_FAILURE_CLASS="fail:broker-outage-post"
    LAST_REASON="POST during broker outage returned HTTP $outage_http"
    echo "FAIL broker-outage-post http_code=$outage_http container=$rabbit_container" >> "$checks_path"
    docker start "$rabbit_container" >/dev/null 2>&1 || true
    return 1
  fi

  outage_check_id="$(jq -r '.checkId // empty' "$EVIDENCE_DIR/attempt-$attempt/outage-post.json")"
  if [[ -z "$outage_check_id" ]]; then
    LAST_FAILURE_CLASS="fail:broker-outage-post"
    LAST_REASON="Outage POST succeeded but missing checkId"
    echo "FAIL broker-outage-post missing_check_id" >> "$checks_path"
    docker start "$rabbit_container" >/dev/null 2>&1 || true
    return 1
  fi

  append_outbox_snapshot "$sql_out_path" "$pg_container" "$pg_user" "$pg_pass" "outage_pre_restart"
  append_outbox_lock_snapshot "$sql_out_path" "$pg_container" "$pg_user" "$pg_pass" "outage_pre_restart"

  broker_restart_utc="$(date -u +%FT%TZ)"
  if ! docker start "$rabbit_container" >/dev/null; then
    LAST_FAILURE_CLASS="fail:broker-restart"
    LAST_REASON="Failed to restart RabbitMQ container $rabbit_container"
    echo "FAIL broker-restart container=$rabbit_container" >> "$checks_path"
    return 1
  fi

  if ! wait_for_rabbit_ready "$rabbit_container" "$BROKER_READY_WAIT_SECONDS"; then
    LAST_FAILURE_CLASS="fail:broker-restart"
    LAST_REASON="RabbitMQ container restarted but broker did not become ready in ${BROKER_READY_WAIT_SECONDS}s"
    echo "FAIL broker-restart readiness_timeout container=$rabbit_container waitSeconds=$BROKER_READY_WAIT_SECONDS" >> "$checks_path"
    append_outbox_snapshot "$sql_out_path" "$pg_container" "$pg_user" "$pg_pass" "outage_broker_not_ready"
    return 1
  fi
  broker_ready_utc="$(date -u +%FT%TZ)"
  echo "PASS broker-restart ready container=$rabbit_container waitSeconds=$BROKER_READY_WAIT_SECONDS" >> "$checks_path"

  # Let transport reconnections settle before evaluating recovery.
  sleep 3

  local recovered="false"
  local dispatch_count ledger_count ledger_status outbox_pending restarted_dispatcher="false"
  local timeline_path="$attempt_dir/outbox_lock_timeline.csv"
  local sec_counter=0
  echo "timestamp_utc,second,outage_request_id,dispatch_count,ledger_count,ledger_status,outbox_pending,outbox_id,delivered,last_sequence_number,lock_id,owner_pid,owner_app,owner_state,owner_xact_start,owner_state_change,owner_lock_mode,owner_lock_granted,owner_query" > "$timeline_path"

  for _ in $(seq 1 "$BROKER_RECOVERY_POLL_SECONDS"); do
    sec_counter=$((sec_counter + 1))
    dispatch_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from masstransit.dispatch_records where request_id='${outage_check_id}'::uuid;")"
    ledger_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from compliance_ledger.events where request_id='${outage_check_id}'::uuid;")"
    ledger_status="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select status from compliance_ledger.events where request_id='${outage_check_id}'::uuid order by processed_at_utc desc limit 1;")"
    outbox_pending="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from masstransit.outbox_message;")"
    local outbox_state owner_row
    outbox_state="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select coalesce(outbox_id::text,'null') || '|' || coalesce(delivered::text,'null') || '|' || coalesce(last_sequence_number::text,'null') || '|' || coalesce(lock_id::text,'null') from masstransit.outbox_state order by created desc limit 1;")"
    owner_row="$(db_query "$pg_container" "$pg_user" "$pg_pass" "
      select
        coalesce(a.pid::text,'null') || '|' ||
        coalesce(a.application_name,'null') || '|' ||
        coalesce(a.state,'null') || '|' ||
        coalesce(a.xact_start::text,'null') || '|' ||
        coalesce(a.state_change::text,'null') || '|' ||
        coalesce(l.mode,'null') || '|' ||
        coalesce(l.granted::text,'null') || '|' ||
        coalesce(substr(a.query, 1, 160),'null')
      from pg_locks l
      join pg_stat_activity a on a.pid = l.pid
      left join pg_class c on c.oid = l.relation
      left join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'masstransit'
        and c.relname = 'outbox_state'
        and l.mode = 'RowExclusiveLock'
        and l.granted
      order by a.xact_start nulls last
      limit 1;
    ")"

    local outbox_id state_delivered state_last_sequence state_lock_id
    local owner_pid owner_app owner_state owner_xact_start owner_state_change owner_lock_mode owner_lock_granted owner_query
    IFS='|' read -r outbox_id state_delivered state_last_sequence state_lock_id <<< "$outbox_state"
    IFS='|' read -r owner_pid owner_app owner_state owner_xact_start owner_state_change owner_lock_mode owner_lock_granted owner_query <<< "$owner_row"
    owner_query="$(sanitize_csv_value "$owner_query")"
    ledger_status="$(sanitize_csv_value "$ledger_status")"
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
      "$(date -u +%FT%TZ)" "$sec_counter" "$outage_check_id" "$dispatch_count" "$ledger_count" "$ledger_status" "$outbox_pending" \
      "$outbox_id" "$state_delivered" "$state_last_sequence" "$state_lock_id" \
      "$owner_pid" "$(sanitize_csv_value "$owner_app")" "$(sanitize_csv_value "$owner_state")" "$(sanitize_csv_value "$owner_xact_start")" \
      "$(sanitize_csv_value "$owner_state_change")" "$(sanitize_csv_value "$owner_lock_mode")" "$(sanitize_csv_value "$owner_lock_granted")" "$owner_query" >> "$timeline_path"

    if [[ "$dispatch_count" -ge 1 && "$ledger_count" -ge 1 && "$ledger_status" == "processed" ]]; then
      recovered="true"
      break
    fi

    if [[ "$PHASE3_MODE" == "hybrid" && "$restarted_dispatcher" == "false" && "$outbox_pending" -gt 0 ]]; then
      echo "WARN broker-recovery pending_outbox_detected restarting_api_dispatcher" >> "$checks_path"
      pkill -f "dotnet run --project Sentinel.Api" 2>/dev/null || true
      pkill -f "/Sentinel.Api/bin/" 2>/dev/null || true
      pkill -f "dotnet run --project Sentinel.Worker" 2>/dev/null || true
      pkill -f "/Sentinel.Worker/bin/" 2>/dev/null || true
      if start_api_fallback "$attempt_dir"; then
        wait_for_http "$ATTEMPT_API_URL/" "$HYBRID_STARTUP_WAIT_SECONDS" || true
        start_worker_fallback "$attempt_dir" || true
        restarted_dispatcher="true"
      fi
    fi

    sleep 1
  done

  {
    echo "outage_timestamp_utc=$outage_ts"
    echo "outage_broker_stopped_utc=$broker_stopped_utc"
    echo "outage_broker_restart_utc=$broker_restart_utc"
    echo "outage_broker_ready_utc=$broker_ready_utc"
    echo "outage_request_id=$outage_check_id"
    echo "outage_dispatch_count=$dispatch_count"
    echo "outage_ledger_count=$ledger_count"
    echo "outage_ledger_status=$ledger_status"
    echo "outage_outbox_pending=$outbox_pending"
    echo "outage_restarted_dispatcher=$restarted_dispatcher"
    echo "outage_recovered=$recovered"
    echo "outage_broker_recovery_poll_seconds=$BROKER_RECOVERY_POLL_SECONDS"
    echo "outbox_lock_timeline_path=$timeline_path"
  } >> "$sql_out_path"

  append_outbox_snapshot "$sql_out_path" "$pg_container" "$pg_user" "$pg_pass" "outage_post_poll"
  append_outbox_lock_snapshot "$sql_out_path" "$pg_container" "$pg_user" "$pg_pass" "outage_post_poll"

  if [[ "$recovered" != "true" ]]; then
    local outbox_state_row state_delivered state_last_sequence state_lock_id
    outbox_state_row="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select coalesce(delivered::text,'null') || '|' || coalesce(last_sequence_number::text,'null') || '|' || coalesce(lock_id::text,'null') from masstransit.outbox_state order by created desc limit 1;")"
    IFS='|' read -r state_delivered state_last_sequence state_lock_id <<< "$outbox_state_row"
    LAST_OUTAGE_CLASSIFICATION="$(classify_lock_timeline "$timeline_path" "$attempt_dir/observer-events.log")"
    LAST_DECISION_LANE="runtime-patch"
    if [[ "$LAST_OUTAGE_CLASSIFICATION" == "reconnect-fault-loop" ]]; then
      LAST_DECISION_LANE="minimal-upstream-repro"
    fi

    {
      echo "outage_state_delivered=$state_delivered"
      echo "outage_state_last_sequence=$state_last_sequence"
      echo "outage_state_lock_id=$state_lock_id"
      echo "outage_classification=$LAST_OUTAGE_CLASSIFICATION"
      echo "decision_lane=$LAST_DECISION_LANE"
    } >> "$sql_out_path"
    echo "INFO outage-classification requestId=$outage_check_id classification=$LAST_OUTAGE_CLASSIFICATION decision_lane=$LAST_DECISION_LANE" >> "$checks_path"

    local worker_running="false"
    if pgrep -fal "/Sentinel.Worker/bin/" >/dev/null 2>&1; then
      worker_running="true"
    fi

    if [[ "$outbox_pending" -gt 0 ]]; then
      if [[ "$state_lock_id" != "null" && "$state_last_sequence" == "null" ]]; then
        LAST_FAILURE_CLASS="fail:outbox-lock-stalled"
        LAST_REASON="Outbox lock remained set with no sequence progression after broker recovery"
        echo "FAIL outbox-lock-stalled requestId=$outage_check_id dispatch_count=$dispatch_count ledger_count=$ledger_count ledger_status=$ledger_status outbox_pending=$outbox_pending worker_running=$worker_running state_lock_id=$state_lock_id state_last_sequence=$state_last_sequence" >> "$checks_path"
      elif [[ "$state_last_sequence" == "null" ]]; then
        LAST_FAILURE_CLASS="fail:outbox-no-dispatch-loop"
        LAST_REASON="Outbox remained pending with no delivery sequence progression after broker recovery"
        echo "FAIL outbox-no-dispatch-loop requestId=$outage_check_id dispatch_count=$dispatch_count ledger_count=$ledger_count ledger_status=$ledger_status outbox_pending=$outbox_pending worker_running=$worker_running state_lock_id=$state_lock_id state_last_sequence=$state_last_sequence" >> "$checks_path"
      else
        LAST_FAILURE_CLASS="fail:outbox-stalled"
        LAST_REASON="Outage request stayed in outbox after broker ready and ${BROKER_RECOVERY_POLL_SECONDS}s polling"
        echo "FAIL outbox-stalled requestId=$outage_check_id dispatch_count=$dispatch_count ledger_count=$ledger_count ledger_status=$ledger_status outbox_pending=$outbox_pending worker_running=$worker_running state_lock_id=$state_lock_id state_last_sequence=$state_last_sequence" >> "$checks_path"
      fi
    elif [[ "$dispatch_count" -ge 1 && "$ledger_count" -eq 0 && "$worker_running" == "true" ]]; then
      LAST_FAILURE_CLASS="fail:broker-accepted-no-consume"
      LAST_REASON="Dispatch record exists but no ledger processing while worker remained running"
      echo "FAIL broker-accepted-no-consume requestId=$outage_check_id dispatch_count=$dispatch_count ledger_count=$ledger_count ledger_status=$ledger_status outbox_pending=$outbox_pending worker_running=$worker_running" >> "$checks_path"
    elif [[ "$worker_running" != "true" ]]; then
      LAST_FAILURE_CLASS="fail:consumer-not-reacquired"
      LAST_REASON="Worker was not running/reacquired during outage recovery window"
      echo "FAIL consumer-not-reacquired requestId=$outage_check_id dispatch_count=$dispatch_count ledger_count=$ledger_count ledger_status=$ledger_status outbox_pending=$outbox_pending worker_running=$worker_running" >> "$checks_path"
    else
      LAST_FAILURE_CLASS="fail:broker-recovery-timeout"
      LAST_REASON="Outage request did not recover to processed state after broker readiness and ${BROKER_RECOVERY_POLL_SECONDS}s recovery polling"
      echo "FAIL broker-recovery-timeout requestId=$outage_check_id dispatch_count=$dispatch_count ledger_count=$ledger_count ledger_status=$ledger_status outbox_pending=$outbox_pending worker_running=$worker_running" >> "$checks_path"
    fi

    if [[ "$PHASE3_MODE" == "strict" && ( "$LAST_FAILURE_CLASS" == "fail:outbox-lock-stalled" || "$LAST_FAILURE_CLASS" == "fail:outbox-no-dispatch-loop" || "$LAST_FAILURE_CLASS" == "fail:outbox-stalled" ) ]]; then
      run_outbox_lock_release_probe "$timeline_path" "$checks_path" "$sql_out_path" "$pg_container" "$pg_user" "$pg_pass" "$outage_check_id"
    fi

    if [[ "$PHASE3_MODE" == "strict" ]]; then
      run_fault_matrix_diagnostics "$checks_path" "$sql_out_path" "$outage_check_id" "$pg_container" "$pg_user" "$pg_pass"
    fi

    return 1
  fi

  LAST_OUTAGE_CLASSIFICATION="unknown"
  LAST_DECISION_LANE="runtime-patch"
  echo "PASS broker-outage-recovery requestId=$outage_check_id" >> "$checks_path"
}

stop_pid_if_running() {
  local pid="${1:-}"
  if [[ -n "$pid" ]]; then
    kill "$pid" 2>/dev/null || true
  fi
}

run_outbox_lock_release_probe() {
  local timeline_path="$1"
  local checks_path="$2"
  local sql_out_path="$3"
  local pg_container="$4"
  local pg_user="$5"
  local pg_pass="$6"
  local outage_check_id="$7"

  if [[ "$OUTBOX_LOCK_RELEASE_PROBE" != "true" ]]; then
    PROBE_APPLIED="false"
    PROBE_RECOVERED="false"
    PROBE_OWNER_PID=""
    PROBE_NOTE="disabled"
    return 0
  fi

  PROBE_APPLIED="true"
  PROBE_RECOVERED="false"
  PROBE_NOTE="started"

  local owner_pid
  owner_pid="$(awk -F, 'NR>1 && $12 != "null" && $12 != "" {pid=$12} END {print pid}' "$timeline_path" 2>/dev/null || true)"
  PROBE_OWNER_PID="$owner_pid"

  if [[ -z "$owner_pid" ]]; then
    PROBE_NOTE="no-owner-pid"
    echo "INFO probe lock_release skipped reason=no_owner_pid" >> "$checks_path"
    {
      echo "probe_applied=$PROBE_APPLIED"
      echo "probe_recovered=$PROBE_RECOVERED"
      echo "probe_owner_pid=$PROBE_OWNER_PID"
      echo "probe_note=$PROBE_NOTE"
    } >> "$sql_out_path"
    return 0
  fi

  local terminated
  terminated="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select pg_terminate_backend(${owner_pid});" | tr -d '[:space:]' || true)"
  PROBE_NOTE="terminate_backend=${terminated:-unknown}"
  echo "INFO probe lock_release owner_pid=$owner_pid terminate_backend=${terminated:-unknown}" >> "$checks_path"

  local probe_dispatch_count probe_ledger_count probe_ledger_status probe_outbox_pending probe_state_last_sequence
  probe_dispatch_count=0
  probe_ledger_count=0
  probe_ledger_status=""
  probe_outbox_pending=0
  probe_state_last_sequence="null"
  for _ in $(seq 1 15); do
    probe_dispatch_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from masstransit.dispatch_records where request_id='${outage_check_id}'::uuid;")"
    probe_ledger_count="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from compliance_ledger.events where request_id='${outage_check_id}'::uuid;")"
    probe_ledger_status="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select status from compliance_ledger.events where request_id='${outage_check_id}'::uuid order by processed_at_utc desc limit 1;")"
    probe_outbox_pending="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select count(*) from masstransit.outbox_message;")"
    probe_state_last_sequence="$(db_query "$pg_container" "$pg_user" "$pg_pass" "select coalesce(last_sequence_number::text,'null') from masstransit.outbox_state order by created desc limit 1;")"

    if [[ "$probe_ledger_count" -ge 1 && "$probe_ledger_status" == "processed" ]]; then
      PROBE_RECOVERED="true"
      PROBE_NOTE="ledger-processed-after-release"
      break
    fi
    if [[ "$probe_state_last_sequence" != "null" ]]; then
      PROBE_RECOVERED="true"
      PROBE_NOTE="sequence-progressed-after-release"
      break
    fi
    sleep 1
  done

  {
    echo "probe_applied=$PROBE_APPLIED"
    echo "probe_recovered=$PROBE_RECOVERED"
    echo "probe_owner_pid=$PROBE_OWNER_PID"
    echo "probe_note=$PROBE_NOTE"
    echo "probe_dispatch_count=$probe_dispatch_count"
    echo "probe_ledger_count=$probe_ledger_count"
    echo "probe_ledger_status=$probe_ledger_status"
    echo "probe_outbox_pending=$probe_outbox_pending"
    echo "probe_state_last_sequence=$probe_state_last_sequence"
  } >> "$sql_out_path"

  echo "INFO probe result applied=$PROBE_APPLIED recovered=$PROBE_RECOVERED note=$PROBE_NOTE owner_pid=$PROBE_OWNER_PID" >> "$checks_path"
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
  ATTEMPT_TELEMETRY_COMPLETE="true"
  LAST_OUTAGE_CLASSIFICATION="unknown"
  LAST_DECISION_LANE="runtime-patch"
  PROBE_APPLIED="false"
  PROBE_RECOVERED="false"
  PROBE_OWNER_PID=""
  PROBE_NOTE="not-run"

  cleanup_runtime
  ATTEMPT_API_URL="$API_URL"
  ATTEMPT_STARTUP_MODE="$ORCHESTRATION_MODE"
  ATTEMPT_GATE_ELIGIBLE="true"
  local orchestrator_pid=""

  local attempt_aspire_dir=""
  if [[ "$ORCHESTRATION_MODE" == "apphost" ]]; then
    (
      cd "$ROOT_DIR"
      Sentinel__EnableDiagnosticsEndpoints=true dotnet run --project Sentinel.AppHost --no-build > "$apphost_log" 2>&1
    ) &
    orchestrator_pid=$!
    echo "$orchestrator_pid" > "$attempt_dir/apphost.pid"
    ATTEMPT_STARTUP_MODE="aspire"
    sleep 2
    attempt_aspire_dir="$(resolve_latest_aspire_run_dir || true)"
  else
    if ! start_direct_runtime "$attempt_dir"; then
      LAST_FAILURE_CLASS="fail:startup"
      [[ -n "$LAST_REASON" ]] || LAST_REASON="Direct mode startup initialization failed"
      echo "FAIL startup direct_runtime_init_failed mode=$ORCHESTRATION_MODE" >> "$checks_path"
      cleanup_runtime
      return 1
    fi
    echo "PASS startup direct_runtime_started mode=$ORCHESTRATION_MODE" >> "$checks_path"
  fi

  if ! wait_for_api_ready "$ATTEMPT_API_URL" "$STRICT_STARTUP_WAIT_SECONDS"; then
    if [[ "$PHASE3_MODE" == "strict" ]]; then
      capture_live_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"
      local startup_kind
      startup_kind="$(detect_startup_failure_kind "$attempt_dir")"
      LAST_FAILURE_CLASS="fail:strict-gate"
      LAST_REASON="Strict ${ORCHESTRATION_MODE} mode: API startup failed (${startup_kind}) at $ATTEMPT_API_URL"
      echo "FAIL strict-gate ${startup_kind} url=$ATTEMPT_API_URL mode=strict orchestration=$ORCHESTRATION_MODE" >> "$checks_path"
      capture_live_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"
      stop_pid_if_running "$orchestrator_pid"
      cleanup_runtime
      return 1
    else
      echo "WARN startup api_not_ready_on_apphost attempting_api_fallback mode=hybrid" >> "$checks_path"

      if ! start_api_fallback "$attempt_dir"; then
        LAST_FAILURE_CLASS="fail:startup"
        LAST_REASON="Hybrid mode: API fallback startup could not be initialized"
        echo "FAIL startup api_readiness_timeout_and_fallback_init_failed url=$ATTEMPT_API_URL mode=hybrid" >> "$checks_path"
        capture_live_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"
        stop_pid_if_running "$orchestrator_pid"
        cleanup_runtime
        return 1
      fi

      if ! wait_for_api_ready "$ATTEMPT_API_URL" "$HYBRID_STARTUP_WAIT_SECONDS"; then
        LAST_FAILURE_CLASS="fail:startup"
        LAST_REASON="Hybrid mode: API did not become ready at $ATTEMPT_API_URL after fallback startup"
        echo "FAIL startup api_readiness_timeout_after_fallback url=$ATTEMPT_API_URL mode=hybrid" >> "$checks_path"
        capture_live_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"
        stop_pid_if_running "$orchestrator_pid"
        cleanup_runtime
        return 1
      fi

      echo "PASS startup api_fallback_started mode=hybrid gate_eligible=false" >> "$checks_path"
    fi
  else
    echo "PASS startup api_ready url=$ATTEMPT_API_URL mode=$PHASE3_MODE orchestration=$ORCHESTRATION_MODE" >> "$checks_path"
  fi

  local worker_wait_seconds="$STRICT_WORKER_WAIT_SECONDS"
  if [[ "$PHASE3_MODE" == "hybrid" ]]; then
    worker_wait_seconds="$HYBRID_STARTUP_WAIT_SECONDS"
  fi

  if ! wait_for_worker_ready "$worker_wait_seconds"; then
    if [[ "$PHASE3_MODE" == "strict" ]]; then
      capture_live_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"
      local startup_kind
      startup_kind="$(detect_startup_failure_kind "$attempt_dir")"
      LAST_FAILURE_CLASS="fail:strict-gate"
      LAST_REASON="Strict ${ORCHESTRATION_MODE} mode: Worker startup failed (${startup_kind})"
      echo "FAIL strict-gate worker_missing ${startup_kind} mode=strict orchestration=$ORCHESTRATION_MODE" >> "$checks_path"
      capture_live_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"
      stop_pid_if_running "$orchestrator_pid"
      cleanup_runtime
      return 1
    else
      if start_worker_fallback "$attempt_dir"; then
        echo "PASS startup worker_fallback_started mode=hybrid gate_eligible=false" >> "$checks_path"
        sleep 2
      else
        LAST_FAILURE_CLASS="fail:startup"
        LAST_REASON="Hybrid mode: Worker did not start and fallback startup failed"
        echo "FAIL startup worker_missing_and_fallback_failed mode=hybrid" >> "$checks_path"
        capture_live_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"
        stop_pid_if_running "$orchestrator_pid"
        cleanup_runtime
        return 1
      fi
    fi
  fi

  local i
  for i in $(seq 1 "$REQUEST_COUNT"); do
    local body http_code check_id
    body="{\"content\":\"phase3-verify-attempt-$attempt-request-$i\",\"source\":\"phase3-script\"}"
    http_code="$(curl -sS --max-time 20 -o "$attempt_dir/post-$i.json" -w "%{http_code}" \
      -X POST "$ATTEMPT_API_URL/api/compliance/check" \
      -H "Content-Type: application/json" \
      --data-binary "$body" || true)"

    if [[ "$http_code" != "200" ]]; then
      LAST_FAILURE_CLASS="fail:trace-continuity"
      LAST_REASON="Baseline POST $i returned HTTP $http_code"
      echo "FAIL trace-continuity post-$i http_code=$http_code" >> "$checks_path"
      capture_live_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"
      stop_pid_if_running "$orchestrator_pid"
      cleanup_runtime
      return 1
    fi

    check_id="$(jq -r '.checkId // empty' "$attempt_dir/post-$i.json")"
    if [[ -z "$check_id" ]]; then
      LAST_FAILURE_CLASS="fail:trace-continuity"
      LAST_REASON="Baseline POST $i missing checkId"
      echo "FAIL trace-continuity post-$i missing_checkId" >> "$checks_path"
      capture_live_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"
      stop_pid_if_running "$orchestrator_pid"
      cleanup_runtime
      return 1
    fi

    jq -c --arg ts "$(date -u +%FT%TZ)" --argjson index "$i" '. + {timestamp_utc:$ts,index:$index}' \
      "$attempt_dir/post-$i.json" >> "$responses_path"
    echo "$check_id" >> "$request_ids_path"
    echo "PASS post-$i checkId=$check_id" >> "$checks_path"
  done

  sleep 3

  local pg_container pg_user pg_pass
  pg_container="$(resolve_postgres_container || true)"
  if [[ -z "$pg_container" ]]; then
    LAST_FAILURE_CLASS="fail:trace-continuity"
    LAST_REASON="Could not find postgres-* container"
    echo "FAIL trace-continuity postgres_container_missing" >> "$checks_path"
    capture_live_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"
    stop_pid_if_running "$orchestrator_pid"
    cleanup_runtime
    return 1
  fi

  pg_user="$(docker exec "$pg_container" printenv POSTGRES_USER)"
  pg_pass="$(docker exec "$pg_container" printenv POSTGRES_PASSWORD)"

  capture_live_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"

  if ! assert_trace_continuity "$apphost_log" "$resource_logs_dir" "$request_ids_path" "$checks_path" "$sql_out_path" "$pg_container" "$pg_user" "$pg_pass"; then
    capture_live_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"
    stop_pid_if_running "$orchestrator_pid"
    cleanup_runtime
    return 1
  fi

  capture_live_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"

  if ! assert_idempotency "$attempt" "$apphost_log" "$resource_logs_dir" "$attempt_dir" "$checks_path" "$sql_out_path" "$pg_container" "$pg_user" "$pg_pass" "$attempt_aspire_dir"; then
    capture_live_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"
    stop_pid_if_running "$orchestrator_pid"
    cleanup_runtime
    return 1
  fi

  if ! assert_broker_outage_recovery "$attempt" "$attempt_dir" "$checks_path" "$sql_out_path" "$pg_container" "$pg_user" "$pg_pass"; then
    capture_live_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"
    capture_runtime_observer_dump "$attempt_dir" "$sql_out_path" "$attempt_aspire_dir"
    stop_pid_if_running "$orchestrator_pid"
    cleanup_runtime
    return 1
  fi

  capture_live_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"
  capture_runtime_observer_dump "$attempt_dir" "$sql_out_path" "$attempt_aspire_dir"

  if [[ "$PHASE3_MODE" == "strict" && "$ATTEMPT_TELEMETRY_COMPLETE" != "true" ]]; then
    ATTEMPT_GATE_ELIGIBLE="false"
    echo "WARN strict-gate telemetry_incomplete gate_eligible=false" >> "$checks_path"
  fi

  capture_live_aspire_artifacts "$attempt_dir" "$attempt_aspire_dir"
  stop_pid_if_running "$orchestrator_pid"
  cleanup_runtime

  [[ -f "$apphost_log" ]] && cp "$apphost_log" "$EVIDENCE_DIR/apphost.log"
  [[ -n "${ATTEMPT_API_LOG:-}" && -f "$ATTEMPT_API_LOG" ]] && cp "$ATTEMPT_API_LOG" "$EVIDENCE_DIR/api.log"
  [[ -n "${ATTEMPT_WORKER_LOG:-}" && -f "$ATTEMPT_WORKER_LOG" ]] && cp "$ATTEMPT_WORKER_LOG" "$EVIDENCE_DIR/worker.log"
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
  "profile": "$PHASE3_PROFILE",
  "baseline_version": "$BASELINE_VERSION",
  "request_count": $REQUEST_COUNT,
  "stability_runs": $STABILITY_RUNS,
  "max_attempts": $MAX_ATTEMPTS,
  "mode": "$PHASE3_MODE",
  "orchestration_mode": "$ORCHESTRATION_MODE",
  "startup_mode": "$ATTEMPT_STARTUP_MODE",
  "gate_eligible": $ATTEMPT_GATE_ELIGIBLE,
  "telemetry_complete": $ATTEMPT_TELEMETRY_COMPLETE,
  "probe_enabled": $([[ "$OUTBOX_LOCK_RELEASE_PROBE" == "true" ]] && echo true || echo false),
  "probe_applied": $PROBE_APPLIED,
  "probe_recovered": $PROBE_RECOVERED,
  "probe_owner_pid": "$PROBE_OWNER_PID",
  "probe_note": "${PROBE_NOTE//\"/\\\"}",
  "outage_classification": "$LAST_OUTAGE_CLASSIFICATION",
  "decision_lane": "$LAST_DECISION_LANE",
  "final_attempt": $FINAL_ATTEMPT,
  "success_streak": $SUCCESS_STREAK,
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
profile=$PHASE3_PROFILE
baseline_version=$BASELINE_VERSION
final_attempt=$FINAL_ATTEMPT
success_streak=$SUCCESS_STREAK
stability_runs=$STABILITY_RUNS
mode=$PHASE3_MODE
orchestration_mode=$ORCHESTRATION_MODE
startup_mode=$ATTEMPT_STARTUP_MODE
gate_eligible=$ATTEMPT_GATE_ELIGIBLE
telemetry_complete=$ATTEMPT_TELEMETRY_COMPLETE
probe_enabled=$OUTBOX_LOCK_RELEASE_PROBE
probe_applied=$PROBE_APPLIED
probe_recovered=$PROBE_RECOVERED
probe_owner_pid=$PROBE_OWNER_PID
probe_note=$PROBE_NOTE
outage_classification=$LAST_OUTAGE_CLASSIFICATION
decision_lane=$LAST_DECISION_LANE
failure_class=$LAST_FAILURE_CLASS
reason=$LAST_REASON
evidence_dir=$EVIDENCE_DIR
TXT
}

promote_attempt_artifacts() {
  local attempt_dir="$EVIDENCE_DIR/attempt-$FINAL_ATTEMPT"
  [[ -d "$attempt_dir" ]] || return 0

  [[ -f "$attempt_dir/apphost.log" ]] && cp "$attempt_dir/apphost.log" "$EVIDENCE_DIR/apphost.log"
  [[ -f "$attempt_dir/post_responses.jsonl" ]] && cp "$attempt_dir/post_responses.jsonl" "$EVIDENCE_DIR/post_responses.jsonl"
  [[ -f "$attempt_dir/verification.sql.out" ]] && cp "$attempt_dir/verification.sql.out" "$EVIDENCE_DIR/verification.sql.out"
  [[ -f "$attempt_dir/checks.txt" ]] && cp "$attempt_dir/checks.txt" "$EVIDENCE_DIR/checks.txt"
}

main() {
  preflight
  if [[ "$PHASE3_MODE" != "strict" && "$PHASE3_MODE" != "hybrid" ]]; then
    echo "Invalid PHASE3_MODE: $PHASE3_MODE (expected strict|hybrid)"
    exit 1
  fi
  if [[ "$ORCHESTRATION_MODE" != "apphost" && "$ORCHESTRATION_MODE" != "direct" ]]; then
    echo "Invalid ORCHESTRATION_MODE: $ORCHESTRATION_MODE (expected apphost|direct)"
    exit 1
  fi

  local attempt
  for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
    FINAL_ATTEMPT="$attempt"
    log "Starting Phase 3 attempt $attempt/$MAX_ATTEMPTS (current streak: $SUCCESS_STREAK/$STABILITY_RUNS)"

    if run_attempt "$attempt"; then
      local startup_matches_mode="false"
      if [[ "$ORCHESTRATION_MODE" == "apphost" && "$ATTEMPT_STARTUP_MODE" == "aspire" ]]; then
        startup_matches_mode="true"
      fi
      if [[ "$ORCHESTRATION_MODE" == "direct" && "$ATTEMPT_STARTUP_MODE" == "direct" ]]; then
        startup_matches_mode="true"
      fi

      if [[ "$ATTEMPT_GATE_ELIGIBLE" == "true" && "$startup_matches_mode" == "true" ]]; then
        SUCCESS_STREAK=$((SUCCESS_STREAK + 1))
        record_attempt "$attempt" "pass" "pass" "all assertions passed" "$SUCCESS_STREAK"
        log "Attempt $attempt passed (strict-gate eligible). Success streak: $SUCCESS_STREAK/$STABILITY_RUNS"
      else
        record_attempt "$attempt" "pass" "pass" "passed but non-gating (fallback or startup mode mismatch)" "$SUCCESS_STREAK"
        log "Attempt $attempt passed but is non-gating (fallback or startup mode mismatch). Success streak unchanged: $SUCCESS_STREAK/$STABILITY_RUNS"
      fi

      if [[ "$SUCCESS_STREAK" -ge "$STABILITY_RUNS" ]]; then
        write_summary "pass"
        write_manifest "pass"
        log "Phase 3 verification passed with required stability streak"
        exit 0
      fi
    else
      record_attempt "$attempt" "fail" "$LAST_FAILURE_CLASS" "$LAST_REASON" "$SUCCESS_STREAK"
      SUCCESS_STREAK=0
      if [[ "$LAST_OUTAGE_CLASSIFICATION" == "reconnect-fault-loop" ]]; then
        LAST_DECISION_LANE="minimal-upstream-repro"
        LAST_REASON="Outage classification is reconnect-fault-loop. Move to upstream repro lane."
        write_summary "fail"
        write_manifest "fail"
        promote_attempt_artifacts
        log "$LAST_REASON"
        exit 1
      fi
      if [[ "$LAST_FAILURE_CLASS" == "$LAST_REPEAT_FAILURE_CLASS" ]]; then
        REPEAT_FAILURE_COUNT=$((REPEAT_FAILURE_COUNT + 1))
      else
        LAST_REPEAT_FAILURE_CLASS="$LAST_FAILURE_CLASS"
        REPEAT_FAILURE_COUNT=1
      fi
      log "Attempt $attempt failed with $LAST_FAILURE_CLASS: $LAST_REASON"
      if [[ "$REPEAT_FAILURE_COUNT" -ge 3 ]]; then
        LAST_FAILURE_CLASS="fail:stability-gate"
        LAST_REASON="Failure class '$LAST_REPEAT_FAILURE_CLASS' repeated 3 times with no new signal. Reclassification required before additional retries."
        LAST_DECISION_LANE="minimal-upstream-repro"
        write_summary "fail"
        write_manifest "fail"
        promote_attempt_artifacts
        log "$LAST_REASON"
        exit 1
      fi
      log "Running recovery routine (cleanup + retry)"
      cleanup_runtime
      sleep 2
    fi
  done

  if [[ "$LAST_FAILURE_CLASS" == "pass" ]]; then
    LAST_FAILURE_CLASS="fail:stability-gate"
    LAST_REASON="Did not achieve required consecutive pass streak of $STABILITY_RUNS within $MAX_ATTEMPTS attempts"
  fi

  write_summary "fail"
  write_manifest "fail"
  promote_attempt_artifacts
  log "Phase 3 verification failed after $MAX_ATTEMPTS attempts"
  exit 1
}

main "$@"
