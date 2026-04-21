#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
SNAPSHOT_DIR="${1:-$ROOT_DIR/diagnostics/phaseA/phase4/snapshots/$STAMP}"
API_URL="${API_URL:-http://localhost:5022}"
BASELINE_FILE="${BASELINE_FILE:-$ROOT_DIR/diagnostics/phaseA/phase4/operational-baseline.v1.json}"

mkdir -p "$SNAPSHOT_DIR"

log() {
  printf "[%s] %s\n" "$(date -u +%FT%TZ)" "$*"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

find_container() {
  local pattern="$1"
  docker ps --format '{{.Names}}' | grep -E "$pattern" | head -n1 || true
}

latest_summary_for_profile() {
  local profile="$1"
  python3 - "$ROOT_DIR" "$profile" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1]) / "diagnostics" / "phaseA" / "phase4" / "evidence"
profile = sys.argv[2]
matches = []
for summary in root.glob("*/summary.txt"):
    text = summary.read_text()
    if f"profile={profile}" in text:
        matches.append(summary)

if matches:
    print(sorted(matches)[-1])
PY
}

summary_value() {
  local file="$1"
  local key="$2"
  [[ -f "$file" ]] || return 0
  grep -E "^${key}=" "$file" | tail -n1 | cut -d= -f2- || true
}

fetch_json() {
  local url="$1"
  local output="$2"
  if curl -fsS --max-time 10 "$url" >"$output"; then
    return 0
  fi

  printf '{"error":"unavailable","url":"%s","utc":"%s"}\n' \
    "$url" \
    "$(date -u +%FT%TZ)" >"$output"
  return 1
}

capture_db_snapshot() {
  local pg_container="$1"
  [[ -n "$pg_container" ]] || return 0

  local pg_user
  local pg_pass
  pg_user="$(docker exec "$pg_container" printenv POSTGRES_USER)"
  pg_pass="$(docker exec "$pg_container" printenv POSTGRES_PASSWORD)"

  docker exec -e PGPASSWORD="$pg_pass" "$pg_container" psql -U "$pg_user" -d compliancedb -Atc "
select 'outbox_pending=' || count(*) from masstransit.outbox_message
union all
select 'inbox_count=' || count(*) from masstransit.inbox_state
union all
select 'dispatch_record_count=' || count(*) from masstransit.dispatch_records;
" >"$SNAPSHOT_DIR/db_counts.txt"

  docker exec -e PGPASSWORD="$pg_pass" "$pg_container" psql -U "$pg_user" -d compliancedb -F',' -Atc "
select status, count(*)
from compliance_ledger.events
group by status
order by status;
" >"$SNAPSHOT_DIR/ledger_status_counts.csv"

  docker exec -e PGPASSWORD="$pg_pass" "$pg_container" psql -U "$pg_user" -d compliancedb -F',' -Atc "
select request_id, status, processed_at_utc, coalesce(trace_id, ''), coalesce(error_code, '')
from compliance_ledger.events
order by processed_at_utc desc
limit 20;
" >"$SNAPSHOT_DIR/recent_ledger_rows.csv"
}

capture_queue_snapshot() {
  local rabbit_container="$1"
  [[ -n "$rabbit_container" ]] || return 0

  docker exec "$rabbit_container" rabbitmqctl list_queues -q name messages messages_ready messages_unacknowledged consumers consumer_capacity \
    >"$SNAPSHOT_DIR/queue_snapshot.tsv" 2>"$SNAPSHOT_DIR/queue_snapshot.stderr" || true
}

write_operational_snapshot() {
  python3 - "$SNAPSHOT_DIR" <<'PY'
import json
import pathlib
import sys

snapshot_dir = pathlib.Path(sys.argv[1])

def load_json(name):
    path = snapshot_dir / name
    if not path.exists():
        return {"error": "missing"}
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        return {"error": "invalid_json", "path": str(path)}

def load_key_values(name):
    path = snapshot_dir / name
    if not path.exists():
        return {}
    values = {}
    for line in path.read_text().splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            values[key] = value
    return values

payload = {
    "utc": __import__("datetime").datetime.utcnow().isoformat() + "Z",
    "readiness": load_json("readiness.json"),
    "sender": load_json("sender.json"),
    "db_counts": load_key_values("db_counts.txt"),
    "artifacts": {
        "queue_snapshot": "queue_snapshot.tsv",
        "ledger_status_counts": "ledger_status_counts.csv",
        "recent_ledger_rows": "recent_ledger_rows.csv"
    }
}

(snapshot_dir / "operational_snapshot.json").write_text(json.dumps(payload, indent=2) + "\n")
PY
}

compare_against_baseline() {
  python3 - "$SNAPSHOT_DIR" "$BASELINE_FILE" "$(latest_summary_for_profile release-suite)" "$(latest_summary_for_profile diagnostic-stress)" "$(latest_summary_for_profile diagnostic-soak)" <<'PY'
import json
import pathlib
import sys

snapshot_dir = pathlib.Path(sys.argv[1])
baseline_file = pathlib.Path(sys.argv[2])
summary_paths = {
    "release-suite": pathlib.Path(sys.argv[3]) if sys.argv[3] else None,
    "diagnostic-stress": pathlib.Path(sys.argv[4]) if sys.argv[4] else None,
    "diagnostic-soak": pathlib.Path(sys.argv[5]) if sys.argv[5] else None,
}

def parse_summary(path):
    if not path or not path.exists():
        return {}
    data = {}
    for line in path.read_text().splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            data[key] = value
    return data

baseline = json.loads(baseline_file.read_text())
retained = baseline["retained_expectations"]
thresholds = baseline["regression_thresholds"]
multiplier = float(thresholds["latency_regression_multiplier"])
drain_threshold = float(thresholds["drain_seconds_regression"])

release = parse_summary(summary_paths["release-suite"])
stress = parse_summary(summary_paths["diagnostic-stress"])
soak = parse_summary(summary_paths["diagnostic-soak"])

lines = []

def compare_latency(label, current_key, expected_value, source):
    if current_key not in source:
        lines.append(f"WARN {label} missing")
        return
    current = float(source[current_key])
    status = "PASS" if current <= expected_value * multiplier else "WARN"
    lines.append(f"{status} {label} current={current:.3f} baseline={expected_value:.3f} allowed={expected_value * multiplier:.3f}")

compare_latency(
    "release_bounded_load_p95_latency_ms",
    "release_bounded_load_p95_latency_ms",
    float(retained["release_bounded_load_p95_latency_ms"]),
    release,
)
compare_latency(
    "diagnostic_stress_p95_latency_ms",
    "diagnostic_stress_p95_latency_ms",
    float(retained["diagnostic_stress_p95_latency_ms"]),
    stress,
)
compare_latency(
    "diagnostic_stress_p99_latency_ms",
    "diagnostic_stress_p99_latency_ms",
    float(retained["diagnostic_stress_p99_latency_ms"]),
    stress,
)
compare_latency(
    "diagnostic_soak_p95_latency_ms",
    "diagnostic_soak_p95_latency_ms",
    float(retained["diagnostic_soak_p95_latency_ms"]),
    soak,
)

if "release_backlog_recovery_drain_seconds" in release:
    current_drain = float(release["release_backlog_recovery_drain_seconds"])
    baseline_drain = float(retained["release_backlog_recovery_drain_seconds"])
    status = "PASS" if current_drain <= baseline_drain + drain_threshold else "WARN"
    lines.append(
        f"{status} release_backlog_recovery_drain_seconds current={current_drain:.3f} baseline={baseline_drain:.3f} allowed={baseline_drain + drain_threshold:.3f}"
    )
else:
    lines.append("WARN release_backlog_recovery_drain_seconds missing")

terminal_value = release.get("release_terminal_failure_terminal_failure_verified")
if terminal_value is None:
    lines.append("WARN release_terminal_failure_terminal_failure_verified missing")
else:
    required = bool(retained["release_terminal_failure_verified"])
    current = terminal_value.lower() == "true"
    status = "PASS" if current == required else "WARN"
    lines.append(f"{status} release_terminal_failure_terminal_failure_verified current={current} baseline={required}")

(snapshot_dir / "baseline_comparison.txt").write_text("\n".join(lines) + "\n")
PY
}

require_cmd curl
require_cmd docker
require_cmd jq
require_cmd python3

log "Capturing readiness and sender diagnostics from $API_URL"
fetch_json "${API_URL%/}/api/diagnostics/readiness" "$SNAPSHOT_DIR/readiness.json" || true
fetch_json "${API_URL%/}/api/diagnostics/messaging/sender" "$SNAPSHOT_DIR/sender.json" || true

rabbit_container="$(find_container '^messaging-')"
pg_container="$(find_container '^postgres-')"

capture_queue_snapshot "$rabbit_container"
capture_db_snapshot "$pg_container"
write_operational_snapshot
compare_against_baseline

printf "snapshot_dir=%s\n" "$SNAPSHOT_DIR" >"$SNAPSHOT_DIR/summary.txt"
printf "api_url=%s\n" "$API_URL" >>"$SNAPSHOT_DIR/summary.txt"
printf "baseline_file=%s\n" "$BASELINE_FILE" >>"$SNAPSHOT_DIR/summary.txt"

log "Operational snapshot captured at $SNAPSHOT_DIR"
