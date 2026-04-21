#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VERIFY_SCRIPT="$ROOT_DIR/diagnostics/phaseA/phase3/verify_phase3.sh"
FACT_ROOT="$ROOT_DIR/diagnostics/phaseA/phase3/fact-bundles"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${1:-$FACT_ROOT/$STAMP}"

RUN_VERIFY="${RUN_VERIFY:-1}"
VERIFY_MODE="${VERIFY_MODE:-strict}"
VERIFY_STABILITY_RUNS="${VERIFY_STABILITY_RUNS:-1}"
VERIFY_MAX_ATTEMPTS="${VERIFY_MAX_ATTEMPTS:-1}"

mkdir -p "$OUT_DIR"

log() {
  printf "[%s] %s\n" "$(date -u +%FT%TZ)" "$*"
}

require_cmd() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "Missing required command: $name"
    return 1
  fi
}

capture_command() {
  local out_path="$1"
  shift
  {
    echo "$ $*"
    "$@"
  } >"$out_path" 2>&1 || true
}

find_latest_complete_evidence() {
  local base="$ROOT_DIR/diagnostics/phaseA/phase3/evidence"
  local candidate
  for candidate in $(ls -td "$base"/* 2>/dev/null || true); do
    if [[ -d "$candidate" && -f "$candidate/summary.txt" && -f "$candidate/manifest.json" ]]; then
      printf "%s\n" "$candidate"
      return 0
    fi
  done
  return 1
}

extract_line() {
  local key="$1"
  local summary_path="$2"
  grep -E "^${key}=" "$summary_path" 2>/dev/null | tail -n1 | cut -d'=' -f2- || true
}

copy_if_exists() {
  local source_path="$1"
  local dest_path="$2"
  if [[ -f "$source_path" ]]; then
    cp "$source_path" "$dest_path"
  fi
}

main() {
  require_cmd dotnet
  require_cmd rg
  require_cmd jq
  require_cmd docker
  require_cmd curl

  log "Collecting static facts"
  capture_command "$OUT_DIR/git-status.txt" git -C "$ROOT_DIR" status --short --branch
  capture_command "$OUT_DIR/dotnet-info.txt" dotnet --info

  capture_command "$OUT_DIR/packages-api.txt" dotnet list "$ROOT_DIR/Sentinel.Api/Sentinel.Api.csproj" package
  capture_command "$OUT_DIR/packages-worker.txt" dotnet list "$ROOT_DIR/Sentinel.Worker/Sentinel.Worker.csproj" package
  capture_command "$OUT_DIR/packages-apphost.txt" dotnet list "$ROOT_DIR/Sentinel.AppHost/Sentinel.AppHost.csproj" package
  if [[ -f "$ROOT_DIR/Sentinel.Shared/Sentinel.Shared.csproj" ]]; then
    capture_command "$OUT_DIR/packages-shared.txt" dotnet list "$ROOT_DIR/Sentinel.Shared/Sentinel.Shared.csproj" package
  fi

  capture_command "$OUT_DIR/apphost-rabbit-config.txt" rg -n "rabbit|messaging|WithImage|4\\.2|3\\.13|WaitFor" "$ROOT_DIR/Sentinel.AppHost/Program.cs"
  capture_command "$OUT_DIR/api-masstransit-config.txt" rg -n "MassTransit|Outbox|QueryDelay|QueryMessageLimit|MessageDelivery|Heartbeat|RequestedConnectionTimeout|ContinuationTimeout|WaitUntilStarted|StartTimeout" "$ROOT_DIR/Sentinel.Api/Program.cs"
  capture_command "$OUT_DIR/worker-masstransit-config.txt" rg -n "MassTransit|Outbox|QueryDelay|QueryMessageLimit|MessageDelivery|Heartbeat|RequestedConnectionTimeout|ContinuationTimeout|WaitUntilStarted|StartTimeout" "$ROOT_DIR/Sentinel.Worker/Program.cs"

  local verify_exit=0
  local verify_started_utc
  verify_started_utc="$(date -u +%FT%TZ)"
  if [[ "$RUN_VERIFY" == "1" ]]; then
    log "Running strict Phase 3 verify (single attempt)"
    set +e
    PHASE3_MODE="$VERIFY_MODE" \
      STABILITY_RUNS="$VERIFY_STABILITY_RUNS" \
      MAX_ATTEMPTS="$VERIFY_MAX_ATTEMPTS" \
      "$VERIFY_SCRIPT" >"$OUT_DIR/verify-run.log" 2>&1
    verify_exit=$?
    set -e
  else
    log "Skipping verify run because RUN_VERIFY=$RUN_VERIFY"
    echo "verify skipped (RUN_VERIFY=$RUN_VERIFY)" >"$OUT_DIR/verify-run.log"
  fi
  local verify_finished_utc
  verify_finished_utc="$(date -u +%FT%TZ)"
  printf "%s\n" "$verify_exit" >"$OUT_DIR/verify-exit-code.txt"

  log "Resolving latest complete evidence folder"
  local latest_evidence=""
  latest_evidence="$(find_latest_complete_evidence || true)"

  if [[ -n "$latest_evidence" ]]; then
    mkdir -p "$OUT_DIR/latest-evidence"
    copy_if_exists "$latest_evidence/summary.txt" "$OUT_DIR/latest-evidence/summary.txt"
    copy_if_exists "$latest_evidence/manifest.json" "$OUT_DIR/latest-evidence/manifest.json"
    copy_if_exists "$latest_evidence/checks.txt" "$OUT_DIR/latest-evidence/checks.txt"
    copy_if_exists "$latest_evidence/verification.sql.out" "$OUT_DIR/latest-evidence/verification.sql.out"
    copy_if_exists "$latest_evidence/attempts.log" "$OUT_DIR/latest-evidence/attempts.log"
    copy_if_exists "$latest_evidence/attempt-1/verification.sql.out" "$OUT_DIR/latest-evidence/attempt-1-verification.sql.out"
    copy_if_exists "$latest_evidence/attempt-1/outbox_lock_timeline.csv" "$OUT_DIR/latest-evidence/attempt-1-outbox_lock_timeline.csv"
    copy_if_exists "$latest_evidence/attempt-1/checks.txt" "$OUT_DIR/latest-evidence/attempt-1-checks.txt"
  fi

  local result="unknown"
  local failure_class="unknown"
  local outage_classification="unknown"
  local telemetry_complete="unknown"
  local mode="unknown"
  local startup_mode="unknown"
  local gate_eligible="unknown"

  if [[ -f "$OUT_DIR/latest-evidence/summary.txt" ]]; then
    result="$(extract_line "result" "$OUT_DIR/latest-evidence/summary.txt")"
    failure_class="$(extract_line "failure_class" "$OUT_DIR/latest-evidence/summary.txt")"
    outage_classification="$(extract_line "outage_classification" "$OUT_DIR/latest-evidence/summary.txt")"
    telemetry_complete="$(extract_line "telemetry_complete" "$OUT_DIR/latest-evidence/summary.txt")"
    mode="$(extract_line "mode" "$OUT_DIR/latest-evidence/summary.txt")"
    startup_mode="$(extract_line "startup_mode" "$OUT_DIR/latest-evidence/summary.txt")"
    gate_eligible="$(extract_line "gate_eligible" "$OUT_DIR/latest-evidence/summary.txt")"
  fi

  cat >"$OUT_DIR/report.md" <<EOF
# Phase 3 one-shot facts

- generated_utc: $(date -u +%FT%TZ)
- run_verify: $RUN_VERIFY
- verify_command: PHASE3_MODE=$VERIFY_MODE STABILITY_RUNS=$VERIFY_STABILITY_RUNS MAX_ATTEMPTS=$VERIFY_MAX_ATTEMPTS $VERIFY_SCRIPT
- verify_started_utc: $verify_started_utc
- verify_finished_utc: $verify_finished_utc
- verify_exit_code: $verify_exit
- latest_complete_evidence: ${latest_evidence:-none}

## Latest evidence summary

- result: $result
- mode: $mode
- startup_mode: $startup_mode
- gate_eligible: $gate_eligible
- telemetry_complete: $telemetry_complete
- outage_classification: $outage_classification
- failure_class: $failure_class

## Files in this bundle

- \`git-status.txt\`
- \`dotnet-info.txt\`
- \`packages-api.txt\`
- \`packages-worker.txt\`
- \`packages-apphost.txt\`
- \`packages-shared.txt\` (if project exists)
- \`apphost-rabbit-config.txt\`
- \`api-masstransit-config.txt\`
- \`worker-masstransit-config.txt\`
- \`verify-run.log\`
- \`verify-exit-code.txt\`
- \`latest-evidence/summary.txt\` (if available)
- \`latest-evidence/manifest.json\` (if available)
- \`latest-evidence/checks.txt\` (if available)
- \`latest-evidence/verification.sql.out\` (if available)
- \`latest-evidence/attempt-1-outbox_lock_timeline.csv\` (if available)
EOF

  cat >"$OUT_DIR/collect-command.txt" <<EOF
RUN_VERIFY=$RUN_VERIFY VERIFY_MODE=$VERIFY_MODE VERIFY_STABILITY_RUNS=$VERIFY_STABILITY_RUNS VERIFY_MAX_ATTEMPTS=$VERIFY_MAX_ATTEMPTS $ROOT_DIR/diagnostics/phaseA/phase3/collect_phase3_facts.sh $OUT_DIR
EOF

  log "Done. Facts bundle:"
  log "$OUT_DIR"
  log "Open report:"
  log "$OUT_DIR/report.md"
}

main "$@"
