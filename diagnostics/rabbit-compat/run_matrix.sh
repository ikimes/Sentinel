#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_ROOT="${1:-$ROOT_DIR/diagnostics/rabbit-compat/evidence/$STAMP}"
mkdir -p "$EVIDENCE_ROOT"
MANIFEST_PATH="$EVIDENCE_ROOT/manifest.json"

API_URL="http://localhost:5022"
API_PROJECT="$ROOT_DIR/Sentinel.Api/Sentinel.Api.csproj"
WORKER_PROJECT="$ROOT_DIR/Sentinel.Worker/Sentinel.Worker.csproj"
APPHOST_PROJECT="$ROOT_DIR/Sentinel.AppHost/Sentinel.AppHost.csproj"

DIRECT_RABBIT_USER="${DIRECT_RABBIT_USER:-diag}"
DIRECT_RABBIT_PASS="${DIRECT_RABBIT_PASS:-example-rabbit-password}"
DIRECT_PG_USER="${DIRECT_PG_USER:-postgres}"
DIRECT_PG_PASS="${DIRECT_PG_PASS:-example-postgres-password}"
DIRECT_DB="compliancedb"

log() {
  printf "[%s] %s\n" "$(date -u +%FT%TZ)" "$*"
}

cleanup_dotnet() {
  pkill -f "Sentinel.AppHost" 2>/dev/null || true
  pkill -f "Sentinel.Api" 2>/dev/null || true
  pkill -f "Sentinel.Worker" 2>/dev/null || true
  pkill -f "dotnet run --project $ROOT_DIR/Sentinel" 2>/dev/null || true
  sleep 2
}

wait_for_http() {
  local url="$1"
  local retries="${2:-90}"
  for _ in $(seq 1 "$retries"); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

wait_for_rabbit_api() {
  local port="$1"
  local user="$2"
  local pass="$3"
  for _ in $(seq 1 90); do
    if curl -fsS -u "$user:$pass" "http://localhost:$port/api/overview" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

wait_for_postgres_ready() {
  local container="$1"
  local pass="$2"
  for _ in $(seq 1 90); do
    if docker exec -e PGPASSWORD="$pass" "$container" pg_isready -U "$DIRECT_PG_USER" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

db_query() {
  local container="$1"
  local pass="$2"
  local sql="$3"
  docker exec -e PGPASSWORD="$pass" "$container" psql -U "$DIRECT_PG_USER" -d "$DIRECT_DB" -Atc "$sql"
}

reset_mass_transit_tables() {
  local pg_container="$1"
  local pg_pass="$2"
  db_query "$pg_container" "$pg_pass" "TRUNCATE TABLE \
masstransit.outbox_message, \
masstransit.outbox_state, \
masstransit.inbox_state, \
masstransit.dispatch_records;"
}

configure_trace_queue() {
  local rabbit_port="$1"
  local rabbit_user="$2"
  local rabbit_pass="$3"
  local auth="$rabbit_user:$rabbit_pass"
  curl -fsS -u "$auth" -H "content-type: application/json" \
    -X PUT "http://localhost:$rabbit_port/api/queues/%2F/sentinel.trace" \
    -d '{"auto_delete":false,"durable":false,"arguments":{}}' >/dev/null
  curl -fsS -u "$auth" -H "content-type: application/json" \
    -X POST "http://localhost:$rabbit_port/api/bindings/%2F/e/amq.rabbitmq.trace/q/sentinel.trace" \
    -d '{"routing_key":"#","arguments":{}}' >/dev/null || true
  curl -fsS -u "$auth" -H "content-type: application/json" \
    -X DELETE "http://localhost:$rabbit_port/api/queues/%2F/sentinel.trace/contents" >/dev/null || true
}

collect_probe() {
  local pass_dir="$1"
  local pg_container="$2"
  local pg_pass="$3"
  local rabbit_port="$4"
  local rabbit_user="$5"
  local rabbit_pass="$6"
  local phase="$7"
  local rabbit_container="$8"
  local worker_log="$9"
  local auth="$rabbit_user:$rabbit_pass"

  reset_mass_transit_tables "$pg_container" "$pg_pass"
  configure_trace_queue "$rabbit_port" "$rabbit_user" "$rabbit_pass"

  db_query "$pg_container" "$pg_pass" \
    "select 'outbox_message|' || count(*) from masstransit.outbox_message
     union all select 'outbox_state|' || count(*) from masstransit.outbox_state
     union all select 'inbox_state|' || count(*) from masstransit.inbox_state
     union all select 'dispatch_records|' || count(*) from masstransit.dispatch_records;" \
    > "$pass_dir/pre_counts.txt"

  local payload_source="${phase}-$(date -u +%H%M%S)"
  local response
  response="$(curl -sS -H "content-type: application/json" \
    -d "{\"content\":\"compat-test\",\"source\":\"$payload_source\"}" \
    "$API_URL/api/compliance/check")"
  local request_id
  request_id="$(printf "%s" "$response" | sed -E 's/.*"checkId":"([^"]+)".*/\1/')"

  printf "post_timestamp=%s\nresponse=%s\nrequest_id=%s\n" \
    "$(date -u +%FT%TZ)" "$response" "$request_id" > "$pass_dir/post_response.txt"

  : > "$pass_dir/outbox_poll.txt"
  for _ in $(seq 1 15); do
    {
      printf "%s|" "$(date -u +%FT%TZ)"
      db_query "$pg_container" "$pg_pass" \
        "select coalesce(count(*)::text,'0') from masstransit.outbox_message;"
      db_query "$pg_container" "$pg_pass" \
        "select coalesce(count(*)::text,'0') from masstransit.outbox_state;"
      db_query "$pg_container" "$pg_pass" \
        "select coalesce(count(*)::text,'0') from masstransit.inbox_state;"
      db_query "$pg_container" "$pg_pass" \
        "select coalesce(count(*)::text,'0') from masstransit.dispatch_records;"
    } >> "$pass_dir/outbox_poll.txt"
    sleep 2
  done

  db_query "$pg_container" "$pg_pass" \
    "select row_to_json(t) from (select * from masstransit.inbox_state order by delivered desc limit 200) t;" > "$pass_dir/inbox_state.jsonl"
  db_query "$pg_container" "$pg_pass" \
    "select row_to_json(t) from (select * from masstransit.outbox_state order by delivered desc limit 200) t;" > "$pass_dir/outbox_state.jsonl"
  db_query "$pg_container" "$pg_pass" \
    "select row_to_json(t) from (select * from masstransit.outbox_message order by sequence_number desc limit 200) t;" > "$pass_dir/outbox_message.jsonl"

  curl -fsS -u "$auth" -H "content-type: application/json" \
    -X POST "http://localhost:$rabbit_port/api/queues/%2F/sentinel.trace/get" \
    -d '{"count":500,"ackmode":"ack_requeue_false","encoding":"auto","truncate":50000}' \
    > "$pass_dir/rabbit_trace.json"

  curl -fsS -u "$auth" "http://localhost:$rabbit_port/api/queues/%2F/compliance" \
    > "$pass_dir/compliance_queue.json"
  curl -fsS -u "$auth" "http://localhost:$rabbit_port/api/queues/%2F/compliance_error" \
    > "$pass_dir/compliance_error_queue.json" || true

  docker logs "$rabbit_container" > "$pass_dir/rabbit_container.log" 2>&1 || true

  local publish_count
  publish_count="$(grep -o 'publish\.' "$pass_dir/rabbit_trace.json" | wc -l | tr -d ' ')"
  local deliver_count
  deliver_count="$(grep -o 'deliver\.compliance' "$pass_dir/rabbit_trace.json" | wc -l | tr -d ' ')"
  local handled_count
  handled_count="$(grep -c "Processed compliance request $request_id" "$worker_log" || true)"
  local worker_dead_count
  worker_dead_count="$(grep -c 'compliance_error' "$pass_dir/rabbit_trace.json" || true)"

  local classification="still-unknown"
  if [[ "$handled_count" -gt 0 ]]; then
    classification="published+handled"
  elif [[ "$publish_count" -gt 0 && "$worker_dead_count" -gt 0 ]]; then
    classification="published+deadletter"
  elif [[ "$publish_count" -gt 0 ]]; then
    classification="published+no-handler"
  else
    classification="not-published"
  fi

  {
    echo "classification=$classification"
    echo "publish_count=$publish_count"
    echo "deliver_count=$deliver_count"
    echo "handled_count=$handled_count"
    echo "worker_dead_count=$worker_dead_count"
  } > "$pass_dir/classification.txt"
}

run_apphost_pass() {
  local rabbit_tag="$1"
  local pass_key="$2"
  local pass_dir="$EVIDENCE_ROOT/$pass_key"
  mkdir -p "$pass_dir"

  cleanup_dotnet
  log "Starting AppHost pass $pass_key with rabbitmq:$rabbit_tag"
  Sentinel__RabbitImageTag="$rabbit_tag" \
  Sentinel__EnableDiagnosticsEndpoints="true" \
  dotnet run --project "$APPHOST_PROJECT" \
    > "$pass_dir/apphost.log" 2>&1 &
  local apphost_pid=$!
  echo "$apphost_pid" > "$pass_dir/apphost.pid"

  wait_for_http "$API_URL/" || { log "API did not start for $pass_key"; return 1; }
  sleep 3

  local rabbit_container
  rabbit_container="$(docker ps --format '{{.Names}} {{.Image}}' | awk '$1 ~ /^messaging-/ {print $1; exit}')"
  local pg_container
  pg_container="$(docker ps --format '{{.Names}} {{.Image}}' | awk '$1 ~ /^postgres-/ {print $1; exit}')"

  if [[ -z "$rabbit_container" || -z "$pg_container" ]]; then
    log "Could not resolve AppHost containers for $pass_key"
    return 1
  fi

  local rabbit_api_port
  rabbit_api_port="$(docker port "$rabbit_container" 15672/tcp | awk -F: '{print $2}')"
  local rabbit_user
  rabbit_user="$(docker exec "$rabbit_container" env | awk -F= '/^RABBITMQ_DEFAULT_USER=/{print $2}')"
  local rabbit_pass
  rabbit_pass="$(docker exec "$rabbit_container" env | awk -F= '/^RABBITMQ_DEFAULT_PASS=/{print $2}')"
  local pg_pass
  pg_pass="$(docker exec "$pg_container" env | awk -F= '/^POSTGRES_PASSWORD=/{print $2}')"

  {
    echo "mode=apphost"
    echo "rabbit_tag=$rabbit_tag"
    echo "rabbit_container=$rabbit_container"
    echo "postgres_container=$pg_container"
    echo "rabbit_api_port=$rabbit_api_port"
  } > "$pass_dir/runtime.txt"

  docker exec "$rabbit_container" rabbitmqctl trace_on -p / >/dev/null || true
  wait_for_rabbit_api "$rabbit_api_port" "$rabbit_user" "$rabbit_pass" || true
  collect_probe "$pass_dir" "$pg_container" "$pg_pass" "$rabbit_api_port" "$rabbit_user" "$rabbit_pass" "apphost" "$rabbit_container" "$pass_dir/apphost.log"

  cleanup_dotnet
  docker rm -f "$rabbit_container" "$pg_container" >/dev/null 2>&1 || true
}

run_direct_pass() {
  local rabbit_tag="$1"
  local pass_key="$2"
  local pass_dir="$EVIDENCE_ROOT/$pass_key"
  mkdir -p "$pass_dir"

  cleanup_dotnet

  local safe_tag
  safe_tag="$(echo "$rabbit_tag" | tr '.:' '__')"
  local rabbit_container="sentinel-diag-rabbit-$safe_tag"
  local pg_container="sentinel-diag-postgres-$safe_tag"

  docker rm -f "$rabbit_container" "$pg_container" >/dev/null 2>&1 || true

  log "Starting direct pass $pass_key with rabbitmq:$rabbit_tag"
  docker run -d --name "$rabbit_container" \
    -e RABBITMQ_DEFAULT_USER="$DIRECT_RABBIT_USER" \
    -e RABBITMQ_DEFAULT_PASS="$DIRECT_RABBIT_PASS" \
    -p 0:5672 -p 0:15672 "rabbitmq:$rabbit_tag" >/dev/null

  docker run -d --name "$pg_container" \
    -e POSTGRES_USER="$DIRECT_PG_USER" \
    -e POSTGRES_PASSWORD="$DIRECT_PG_PASS" \
    -e POSTGRES_DB="$DIRECT_DB" \
    -p 0:5432 postgres:17.6 >/dev/null

  local rabbit_amqp_port
  rabbit_amqp_port="$(docker port "$rabbit_container" 5672/tcp | awk -F: '{print $2}')"
  local rabbit_api_port
  rabbit_api_port="$(docker port "$rabbit_container" 15672/tcp | awk -F: '{print $2}')"
  local pg_port
  pg_port="$(docker port "$pg_container" 5432/tcp | awk -F: '{print $2}')"

  wait_for_postgres_ready "$pg_container" "$DIRECT_PG_PASS"
  wait_for_rabbit_api "$rabbit_api_port" "$DIRECT_RABBIT_USER" "$DIRECT_RABBIT_PASS"

  local messaging_cs="amqp://$DIRECT_RABBIT_USER:$DIRECT_RABBIT_PASS@localhost:$rabbit_amqp_port"
  local pg_cs="Host=localhost;Port=$pg_port;Database=$DIRECT_DB;Username=$DIRECT_PG_USER;Password=$DIRECT_PG_PASS"

  ConnectionStrings__messaging="$messaging_cs" \
  ConnectionStrings__compliancedb="$pg_cs" \
  dotnet run --project "$WORKER_PROJECT" \
    > "$pass_dir/worker.log" 2>&1 &
  local worker_pid=$!

  ASPNETCORE_URLS="$API_URL" \
  Sentinel__EnableDiagnosticsEndpoints="true" \
  ConnectionStrings__messaging="$messaging_cs" \
  ConnectionStrings__compliancedb="$pg_cs" \
  dotnet run --project "$API_PROJECT" \
    > "$pass_dir/api.log" 2>&1 &
  local api_pid=$!

  echo "$worker_pid" > "$pass_dir/worker.pid"
  echo "$api_pid" > "$pass_dir/api.pid"

  wait_for_http "$API_URL/" || { log "API did not start for $pass_key"; return 1; }
  sleep 2

  {
    echo "mode=direct"
    echo "rabbit_tag=$rabbit_tag"
    echo "rabbit_container=$rabbit_container"
    echo "postgres_container=$pg_container"
    echo "rabbit_api_port=$rabbit_api_port"
    echo "rabbit_amqp_port=$rabbit_amqp_port"
    echo "postgres_port=$pg_port"
  } > "$pass_dir/runtime.txt"

  docker exec "$rabbit_container" rabbitmqctl trace_on -p / >/dev/null || true
  collect_probe "$pass_dir" "$pg_container" "$DIRECT_PG_PASS" "$rabbit_api_port" "$DIRECT_RABBIT_USER" "$DIRECT_RABBIT_PASS" "direct" "$rabbit_container" "$pass_dir/worker.log"

  cleanup_dotnet
  docker rm -f "$rabbit_container" "$pg_container" >/dev/null 2>&1 || true
}

run_pass() {
  local mode="$1"
  local tag="$2"
  local key="$3"
  if [[ "$mode" == "apphost" ]]; then
    run_apphost_pass "$tag" "$key"
  else
    run_direct_pass "$tag" "$key"
  fi
}

write_summary() {
  local summary="$EVIDENCE_ROOT/summary.txt"
  : > "$summary"

  for pass_dir in "$EVIDENCE_ROOT"/*; do
    [[ -d "$pass_dir" ]] || continue
    local key
    key="$(basename "$pass_dir")"
    local classification
    classification="$(awk -F= '/^classification=/{print $2}' "$pass_dir/classification.txt" 2>/dev/null || echo "error")"
    local publish_count
    publish_count="$(awk -F= '/^publish_count=/{print $2}' "$pass_dir/classification.txt" 2>/dev/null || echo "0")"
    local handled_count
    handled_count="$(awk -F= '/^handled_count=/{print $2}' "$pass_dir/classification.txt" 2>/dev/null || echo "0")"
    printf "%s classification=%s publish=%s handled=%s\n" \
      "$key" "$classification" "$publish_count" "$handled_count" >> "$summary"
  done

  local apphost42 apphost313 direct42 direct313 final_class
  apphost42="$(awk '/^apphost_4_2/{print $2}' "$summary" || true)"
  apphost313="$(awk '/^apphost_3_13/{print $2}' "$summary" || true)"
  direct42="$(awk '/^direct_4_2/{print $2}' "$summary" || true)"
  direct313="$(awk '/^direct_3_13/{print $2}' "$summary" || true)"
  final_class="still-unknown"

  if [[ "$apphost42" != "classification=published+handled" && "$direct42" != "classification=published+handled" \
        && "$apphost313" == "classification=published+handled" && "$direct313" == "classification=published+handled" ]]; then
    final_class="broker-compat"
  elif [[ "$apphost42" == "classification=published+handled" && "$direct42" == "classification=published+handled" \
        && "$apphost313" == "classification=published+handled" && "$direct313" == "classification=published+handled" ]]; then
    final_class="app-logic-resolved-or-nonrepro"
  elif [[ "$apphost42" != "classification=published+handled" && "$apphost313" != "classification=published+handled" \
        && "$direct42" != "classification=published+handled" && "$direct313" != "classification=published+handled" ]]; then
    final_class="app-logic"
  elif [[ "$direct42" == "classification=published+handled" && "$direct313" == "classification=published+handled" \
        && "$apphost42" != "classification=published+handled" && "$apphost313" != "classification=published+handled" ]]; then
    final_class="apphost-orchestration"
  fi

  echo "final_classification=$final_class" >> "$summary"
}

write_manifest() {
  local summary="$EVIDENCE_ROOT/summary.txt"
  local final_class
  final_class="$(awk -F= '/^final_classification=/{print $2}' "$summary" 2>/dev/null || echo "still-unknown")"

  {
    echo "{"
    echo "  \"generated_utc\": \"$(date -u +%FT%TZ)\"," 
    echo "  \"slice\": \"rabbit-compat\"," 
    echo "  \"evidence_root\": \"$EVIDENCE_ROOT\"," 
    echo "  \"final_classification\": \"$final_class\"," 
    echo "  \"passes\": ["
    local first=1
    for pass_dir in "$EVIDENCE_ROOT"/*; do
      [[ -d "$pass_dir" ]] || continue
      local key
      key="$(basename "$pass_dir")"
      local class
      class="$(awk -F= '/^classification=/{print $2}' "$pass_dir/classification.txt" 2>/dev/null || echo "error")"
      local publish_count
      publish_count="$(awk -F= '/^publish_count=/{print $2}' "$pass_dir/classification.txt" 2>/dev/null || echo "0")"
      local handled_count
      handled_count="$(awk -F= '/^handled_count=/{print $2}' "$pass_dir/classification.txt" 2>/dev/null || echo "0")"
      if [[ "$first" -eq 0 ]]; then
        echo ","
      fi
      first=0
      echo "    {\"key\":\"$key\",\"classification\":\"$class\",\"publish_count\":$publish_count,\"handled_count\":$handled_count}"
    done
    echo
    echo "  ]"
    echo "}"
  } > "$MANIFEST_PATH"
}

main() {
  log "Evidence root: $EVIDENCE_ROOT"
  mkdir -p "$EVIDENCE_ROOT"

  local failures=0
  run_pass apphost "4.2-management" "apphost_4_2" || failures=$((failures + 1))
  run_pass apphost "3.13-management" "apphost_3_13" || failures=$((failures + 1))
  run_pass direct "4.2-management" "direct_4_2" || failures=$((failures + 1))
  run_pass direct "3.13-management" "direct_3_13" || failures=$((failures + 1))

  write_summary
  write_manifest
  cleanup_dotnet

  log "Completed with failures=$failures"
  log "Summary: $EVIDENCE_ROOT/summary.txt"
  log "Manifest: $MANIFEST_PATH"
  if [[ "$failures" -gt 0 ]]; then
    return 1
  fi
}

main "$@"
