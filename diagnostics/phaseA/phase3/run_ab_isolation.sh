#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VERIFY_SCRIPT="$ROOT_DIR/diagnostics/phaseA/phase3/verify_phase3.sh"
EVIDENCE_BASE="$ROOT_DIR/diagnostics/phaseA/phase3/evidence"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${1:-$ROOT_DIR/diagnostics/phaseA/phase3/ab-isolation/$STAMP}"
mkdir -p "$OUT_DIR"

GLOBAL_MAX_ATTEMPTS="${GLOBAL_MAX_ATTEMPTS:-30}"
LANE_MAX_ATTEMPTS="${LANE_MAX_ATTEMPTS:-3}"
TARGET_MT_VERSION="${TARGET_MT_VERSION:-9.0.1}"
VERIFY_TIMEOUT_SECONDS="${VERIFY_TIMEOUT_SECONDS:-900}"
APPROVAL_GATE="${APPROVAL_GATE:-blockers-only}"

LEDGER_CSV="$OUT_DIR/lane-results.csv"
SUMMARY_TXT="$OUT_DIR/summary.txt"
DECISION_JSON="$OUT_DIR/decision.json"
CONTROL_COMPARISON_CSV="$OUT_DIR/control-comparison.csv"

MT_FILES=(
  "$ROOT_DIR/Sentinel.Api/Sentinel.Api.csproj"
  "$ROOT_DIR/Sentinel.Worker/Sentinel.Worker.csproj"
  "$ROOT_DIR/Sentinel.Shared/Sentinel.Shared.csproj"
)

GLOBAL_ATTEMPTS_USED=0
LAST_AUTO_REPLAN_REASON="initial"
STOP_REASON=""
DECISION="upstream_repro"
DECISION_REASON="All strict isolation lanes preserved the blocker signature or failed to produce reproducible strict pass."
MT_BACKUP_DIR=""
MT_MODIFIED="false"

log() {
  printf "[%s] %s\n" "$(date -u +%FT%TZ)" "$*"
}

cleanup_runtime() {
  pkill -f "diagnostics/phaseA/phase3/verify_phase3.sh" 2>/dev/null || true
  pkill -f "Sentinel.AppHost" 2>/dev/null || true
  pkill -f "Sentinel.Api" 2>/dev/null || true
  pkill -f "Sentinel.Worker" 2>/dev/null || true
  pkill -f "dotnet run --project $ROOT_DIR/Sentinel" 2>/dev/null || true
  sleep 2
}

cleanup_on_exit() {
  if [[ "$MT_MODIFIED" == "true" && -n "$MT_BACKUP_DIR" && -d "$MT_BACKUP_DIR" ]]; then
    restore_mt_files "$MT_BACKUP_DIR" || true
    dotnet build "$ROOT_DIR/Sentinel.sln" > "$OUT_DIR/build-restore-on-exit.log" 2>&1 || true
  fi
  cleanup_runtime
}

trap cleanup_on_exit EXIT

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    STOP_REASON="blocked"
    DECISION="blocked"
    DECISION_REASON="Blocked: missing required command '$cmd'."
    write_blocked_artifacts
    echo "Missing required command: $cmd"
    exit 2
  fi
}

write_blocked_artifacts() {
  mkdir -p "$OUT_DIR"
  {
    echo "decision=$DECISION"
    echo "reason=$DECISION_REASON"
    echo "stop_reason=$STOP_REASON"
    echo "approval_gate=$APPROVAL_GATE"
    echo "global_max_attempts=$GLOBAL_MAX_ATTEMPTS"
    echo "global_attempts_used=$GLOBAL_ATTEMPTS_USED"
    echo "global_attempts_remaining=$GLOBAL_MAX_ATTEMPTS"
    echo "global_attempt=$GLOBAL_ATTEMPTS_USED"
    echo "auto_replan_reason=$LAST_AUTO_REPLAN_REASON"
    echo "ledger_csv=$LEDGER_CSV"
    echo "run_dir=$OUT_DIR"
  } > "$SUMMARY_TXT"

  cat > "$DECISION_JSON" <<JSON
{
  "generated_utc": "$(date -u +%FT%TZ)",
  "decision": "$DECISION",
  "reason": "$(printf "%s" "$DECISION_REASON" | sed 's/"/\\"/g')",
  "stop_reason": "$STOP_REASON",
  "approval_gate": "$APPROVAL_GATE",
  "global_max_attempts": $GLOBAL_MAX_ATTEMPTS,
  "global_attempts_used": $GLOBAL_ATTEMPTS_USED,
  "global_attempts_remaining": $GLOBAL_MAX_ATTEMPTS,
  "global_attempt": $GLOBAL_ATTEMPTS_USED,
  "auto_replan_reason": "$(printf "%s" "$LAST_AUTO_REPLAN_REASON" | sed 's/"/\\"/g')",
  "ledger_csv": "$LEDGER_CSV",
  "run_dir": "$OUT_DIR"
}
JSON
}

extract_key() {
  local key="$1"
  local file="$2"
  grep -E "^${key}=" "$file" 2>/dev/null | tail -n1 | cut -d'=' -f2- || true
}

latest_complete_evidence_since() {
  local start_epoch="$1"
  local candidate
  for candidate in $(ls -td "$EVIDENCE_BASE"/* 2>/dev/null || true); do
    [[ -d "$candidate" ]] || continue
    [[ -f "$candidate/summary.txt" && -f "$candidate/manifest.json" ]] || continue
    if [[ "$(stat -f %m "$candidate")" -ge "$start_epoch" ]]; then
      printf "%s\n" "$candidate"
      return 0
    fi
  done
  for candidate in $(ls -td "$EVIDENCE_BASE"/* 2>/dev/null || true); do
    if [[ -d "$candidate" && -f "$candidate/summary.txt" && -f "$candidate/manifest.json" ]]; then
      printf "%s\n" "$candidate"
      return 0
    fi
  done
  return 1
}

copy_if_exists() {
  local src="$1"
  local dst="$2"
  [[ -f "$src" ]] && cp "$src" "$dst"
}

sanitize_csv() {
  local value="${1:-}"
  value="${value//$'\n'/ }"
  value="${value//$'\r'/ }"
  value="${value//,/;}"
  printf "%s" "$value"
}

append_ledger_row() {
  local global_attempt="$1"
  local lane="$2"
  local label="$3"
  local runner="$4"
  local attempt="$5"
  local rc="$6"
  local result="$7"
  local failure_class="$8"
  local outage_class="$9"
  local decision_lane="${10}"
  local startup_mode="${11}"
  local gate_eligible="${12}"
  local telemetry_complete="${13}"
  local probe_applied="${14}"
  local probe_recovered="${15}"
  local outbox_pending="${16}"
  local last_sequence="${17}"
  local evidence_dir="${18}"
  local auto_replan_reason="${19}"
  local reason="${20}"

  {
    printf "%s," "$(date -u +%FT%TZ)"
    printf "%s,%s,%s,%s,%s,%s," \
      "$(sanitize_csv "$global_attempt")" \
      "$(sanitize_csv "$lane")" \
      "$(sanitize_csv "$label")" \
      "$(sanitize_csv "$runner")" \
      "$(sanitize_csv "$attempt")" \
      "$(sanitize_csv "$rc")"
    printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
      "$(sanitize_csv "$result")" \
      "$(sanitize_csv "$failure_class")" \
      "$(sanitize_csv "$outage_class")" \
      "$(sanitize_csv "$decision_lane")" \
      "$(sanitize_csv "$startup_mode")" \
      "$(sanitize_csv "$gate_eligible")" \
      "$(sanitize_csv "$telemetry_complete")" \
      "$(sanitize_csv "$probe_applied")" \
      "$(sanitize_csv "$probe_recovered")" \
      "$(sanitize_csv "$outbox_pending")" \
      "$(sanitize_csv "$last_sequence")" \
      "$(sanitize_csv "$evidence_dir")" \
      "$(sanitize_csv "$auto_replan_reason")" \
      "$(sanitize_csv "$reason")"
  } >> "$LEDGER_CSV"
}

global_cap_reached() {
  [[ "$GLOBAL_ATTEMPTS_USED" -ge "$GLOBAL_MAX_ATTEMPTS" ]]
}

last_verify_signature() {
  awk -F',' '$5=="verify_phase3" {sig=$9"|"$10"|"$17"|"$18"|"$11} END {print sig}' "$LEDGER_CSV"
}

repeated_no_signal_signature() {
  local rows
  rows="$(awk -F',' '$5=="verify_phase3" && $8=="fail" {print $9"|"$10"|"$17"|"$18"|"$11}' "$LEDGER_CSV" | tail -n 3)"
  local count
  count="$(printf "%s\n" "$rows" | sed '/^$/d' | wc -l | tr -d ' ')"
  [[ "$count" -eq 3 ]] || return 1
  local first second third
  first="$(printf "%s\n" "$rows" | sed -n '1p')"
  second="$(printf "%s\n" "$rows" | sed -n '2p')"
  third="$(printf "%s\n" "$rows" | sed -n '3p')"
  [[ -n "$first" && "$first" == "$second" && "$second" == "$third" ]]
}

run_verify_attempt() {
  local lane="$1"
  local label="$2"
  local lane_attempt="$3"
  local auto_replan_reason="$4"
  shift 4

  if global_cap_reached; then
    STOP_REASON="global_cap_exhausted"
    return 2
  fi

  GLOBAL_ATTEMPTS_USED=$((GLOBAL_ATTEMPTS_USED + 1))
  local global_attempt="$GLOBAL_ATTEMPTS_USED"

  local lane_dir="$OUT_DIR/$lane/$label/attempt-$lane_attempt"
  mkdir -p "$lane_dir"

  local start_epoch
  start_epoch="$(date +%s)"

  cleanup_runtime

  env "$@" PHASE3_MODE=strict STABILITY_RUNS=1 MAX_ATTEMPTS=1 "$VERIFY_SCRIPT" > "$lane_dir/verify.log" 2>&1 &
  local verify_pid=$!
  echo "$verify_pid" > "$lane_dir/verify.pid"

  local elapsed=0
  while kill -0 "$verify_pid" 2>/dev/null; do
    if [[ "$elapsed" -ge "$VERIFY_TIMEOUT_SECONDS" ]]; then
      log "Lane=$lane label=$label global_attempt=$global_attempt timed out after ${VERIFY_TIMEOUT_SECONDS}s"
      kill "$verify_pid" 2>/dev/null || true
      sleep 2
      kill -9 "$verify_pid" 2>/dev/null || true
      break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  set +e
  wait "$verify_pid"
  local rc=$?
  set -e

  local evidence_dir=""
  evidence_dir="$(latest_complete_evidence_since "$start_epoch" || true)"
  if [[ -n "$evidence_dir" ]]; then
    mkdir -p "$lane_dir/evidence"
    copy_if_exists "$evidence_dir/summary.txt" "$lane_dir/evidence/summary.txt"
    copy_if_exists "$evidence_dir/manifest.json" "$lane_dir/evidence/manifest.json"
    copy_if_exists "$evidence_dir/checks.txt" "$lane_dir/evidence/checks.txt"
    copy_if_exists "$evidence_dir/verification.sql.out" "$lane_dir/evidence/verification.sql.out"
    copy_if_exists "$evidence_dir/attempt-1/checks.txt" "$lane_dir/evidence/attempt-1-checks.txt"
    copy_if_exists "$evidence_dir/attempt-1/verification.sql.out" "$lane_dir/evidence/attempt-1-verification.sql.out"
  fi

  local result="unknown"
  local failure_class="unknown"
  local outage_class="unknown"
  local decision_lane="unknown"
  local startup_mode="unknown"
  local gate_eligible="unknown"
  local telemetry_complete="unknown"
  local probe_applied="false"
  local probe_recovered="false"
  local reason="no-summary"
  local outbox_pending=""
  local last_sequence=""

  if [[ -f "$lane_dir/evidence/summary.txt" ]]; then
    result="$(extract_key result "$lane_dir/evidence/summary.txt")"
    failure_class="$(extract_key failure_class "$lane_dir/evidence/summary.txt")"
    outage_class="$(extract_key outage_classification "$lane_dir/evidence/summary.txt")"
    decision_lane="$(extract_key decision_lane "$lane_dir/evidence/summary.txt")"
    startup_mode="$(extract_key startup_mode "$lane_dir/evidence/summary.txt")"
    gate_eligible="$(extract_key gate_eligible "$lane_dir/evidence/summary.txt")"
    telemetry_complete="$(extract_key telemetry_complete "$lane_dir/evidence/summary.txt")"
    probe_applied="$(extract_key probe_applied "$lane_dir/evidence/summary.txt")"
    probe_recovered="$(extract_key probe_recovered "$lane_dir/evidence/summary.txt")"
    reason="$(extract_key reason "$lane_dir/evidence/summary.txt")"
  fi

  if [[ -f "$lane_dir/evidence/attempt-1-checks.txt" ]]; then
    outbox_pending="$(grep -o 'outbox_pending=[^ ]*' "$lane_dir/evidence/attempt-1-checks.txt" | tail -n1 | cut -d= -f2 || true)"
    last_sequence="$(grep -o 'state_last_sequence=[^ ]*' "$lane_dir/evidence/attempt-1-checks.txt" | tail -n1 | cut -d= -f2 || true)"
  fi

  if [[ "$elapsed" -ge "$VERIFY_TIMEOUT_SECONDS" && ! -f "$lane_dir/evidence/summary.txt" ]]; then
    result="fail"
    failure_class="fail:verification-timeout"
    outage_class="unknown"
    decision_lane="unknown"
    startup_mode="unknown"
    gate_eligible="unknown"
    telemetry_complete="unknown"
    probe_applied="false"
    probe_recovered="false"
    reason="verify_phase3 timed out after ${VERIFY_TIMEOUT_SECONDS}s"
  fi

  append_ledger_row \
    "$global_attempt" "$lane" "$label" "verify_phase3" "$lane_attempt" "$rc" "$result" "$failure_class" "$outage_class" \
    "$decision_lane" "$startup_mode" "$gate_eligible" "$telemetry_complete" "$probe_applied" "$probe_recovered" \
    "$outbox_pending" "$last_sequence" "$evidence_dir" "$auto_replan_reason" "$reason"

  if [[ "$result" == "pass" ]]; then
    return 0
  fi
  return 1
}

run_verify_lane() {
  local lane="$1"
  local label="$2"
  local auto_replan_reason="$3"
  shift 3

  LAST_AUTO_REPLAN_REASON="$auto_replan_reason"
  local lane_attempt
  local last_failure=""
  local repeated=0

  for lane_attempt in $(seq 1 "$LANE_MAX_ATTEMPTS"); do
    if global_cap_reached; then
      STOP_REASON="global_cap_exhausted"
      return 2
    fi

    log "Lane=$lane label=$label lane_attempt=$lane_attempt/$LANE_MAX_ATTEMPTS global_attempt=$((GLOBAL_ATTEMPTS_USED + 1))/$GLOBAL_MAX_ATTEMPTS"

    set +e
    run_verify_attempt "$lane" "$label" "$lane_attempt" "$auto_replan_reason" "$@"
    local attempt_rc=$?
    set -e

    if [[ "$attempt_rc" -eq 0 ]]; then
      return 0
    fi
    if [[ "$attempt_rc" -eq 2 ]]; then
      return 2
    fi

    local row
    row="$(tail -n1 "$LEDGER_CSV")"
    local failure_class
    failure_class="$(printf "%s" "$row" | awk -F',' '{print $9}')"

    if [[ "$failure_class" == "$last_failure" ]]; then
      repeated=$((repeated + 1))
    else
      repeated=1
      last_failure="$failure_class"
    fi

    if [[ "$repeated" -ge 3 ]]; then
      log "Lane=$lane label=$label stopping lane after repeated failure_class=$failure_class"
      break
    fi
  done

  return 1
}

backup_mt_files() {
  local backup_dir="$1"
  mkdir -p "$backup_dir"
  local file
  for file in "${MT_FILES[@]}"; do
    cp "$file" "$backup_dir/$(basename "$file").orig"
  done
}

restore_mt_files() {
  local backup_dir="$1"
  local file
  for file in "${MT_FILES[@]}"; do
    cp "$backup_dir/$(basename "$file").orig" "$file"
  done
  MT_MODIFIED="false"
}

set_mt_version() {
  local target_version="$1"
  local file
  for file in "${MT_FILES[@]}"; do
    sed -E -i '' "s#(<PackageReference Include=\"MassTransit(\\.EntityFrameworkCore|\\.RabbitMQ)?\" Version=\")[^\"]+(\"\\s*/>)#\\1${target_version}\\3#g" "$file"
  done
  MT_MODIFIED="true"
}

control_signature() {
  awk -F',' '$3=="CONTROL" && $4=="apphost-pinned" && $5=="verify_phase3" {sig=$9"|"$10"|"$17"|"$18"|"$11} END {print sig}' "$LEDGER_CSV"
}

has_strict_pass_candidate() {
  awk -F',' '$5=="verify_phase3" && $8=="pass" && $13=="true" && $15!="true" {found=1} END {exit(found?0:1)}' "$LEDGER_CSV"
}

first_strict_pass_label() {
  awk -F',' '$5=="verify_phase3" && $8=="pass" && $13=="true" && $15!="true" {print $4; exit}' "$LEDGER_CSV"
}

run_reproducibility_check() {
  local lane="$1"
  local label="$2"
  local auto_replan_reason="$3"
  shift 3
  log "Repro check for lane=$lane label=$label"
  run_verify_lane "$lane" "${label}-repro" "$auto_replan_reason" "$@"
}

write_control_comparison() {
  {
    echo "failure_class,outage_classification,outbox_pending,state_last_sequence,telemetry_complete,decision_lane,startup_mode"
    awk -F',' '$3=="CONTROL" && $5=="verify_phase3" {print $9 "," $10 "," $17 "," $18 "," $14 "," $11 "," $12}' "$LEDGER_CSV"
  } > "$CONTROL_COMPARISON_CSV"
}

append_build_only_failure() {
  local label="$1"
  local build_rc="$2"
  local build_log="$3"
  local auto_replan_reason="$4"
  append_ledger_row \
    "$GLOBAL_ATTEMPTS_USED" "VERSION" "$label" "build-only" "1" "$build_rc" "fail" "fail:build" "n/a" "n/a" \
    "n/a" "n/a" "n/a" "false" "false" "n/a" "n/a" "$build_log" "$auto_replan_reason" "MassTransit version build failed"
}

main() {
  require_cmd dotnet
  require_cmd jq
  require_cmd sed
  require_cmd rg

  mkdir -p "$OUT_DIR"
  {
    echo "timestamp_utc,global_attempt,lane,label,runner,attempt,rc,result,failure_class,outage_classification,decision_lane,startup_mode,gate_eligible,telemetry_complete,probe_applied,probe_recovered,outbox_pending,state_last_sequence,evidence_dir,auto_replan_reason,reason"
  } > "$LEDGER_CSV"

  log "A/B isolation run dir: $OUT_DIR"
  log "Autonomous loop: approval_gate=$APPROVAL_GATE global_max_attempts=$GLOBAL_MAX_ATTEMPTS lane_max_attempts=$LANE_MAX_ATTEMPTS"

  # Lane 1: control parity
  run_verify_lane "CONTROL" "apphost-pinned" "baseline_control_parity" Sentinel__RabbitImageTag=4.2-management ORCHESTRATION_MODE=apphost || true
  run_verify_lane "CONTROL" "direct-pinned" "baseline_control_parity" Sentinel__RabbitImageTag=4.2-management ORCHESTRATION_MODE=direct || true

  write_control_comparison

  # Lane 2: diagnostics probe if control captured outbox-lock-stalled
  if [[ "$DECISION" != "global_cap_exhausted" ]] && awk -F',' '$3=="CONTROL" && $5=="verify_phase3" && $9=="fail:outbox-lock-stalled" {found=1} END {exit(found?0:1)}' "$LEDGER_CSV"; then
    run_verify_lane "PROBE" "apphost-pinned" "control_failed_outbox_lock_probe" Sentinel__RabbitImageTag=4.2-management ORCHESTRATION_MODE=apphost OUTBOX_LOCK_RELEASE_PROBE=true || true
    run_verify_lane "PROBE" "direct-pinned" "control_failed_outbox_lock_probe" Sentinel__RabbitImageTag=4.2-management ORCHESTRATION_MODE=direct OUTBOX_LOCK_RELEASE_PROBE=true || true
  fi

  # Lane 3: version isolation pinned
  if [[ "$DECISION" != "global_cap_exhausted" ]]; then
    run_verify_lane "VERSION" "pinned-apphost" "version_isolation_pinned" Sentinel__RabbitImageTag=4.2-management ORCHESTRATION_MODE=apphost || true
    run_verify_lane "VERSION" "pinned-direct" "version_isolation_pinned" Sentinel__RabbitImageTag=4.2-management ORCHESTRATION_MODE=direct || true
  fi

  # Lane 4: version isolation latest
  local latest_build_rc=0
  if [[ "$DECISION" != "global_cap_exhausted" ]]; then
    MT_BACKUP_DIR="$OUT_DIR/mt-backup"
    backup_mt_files "$MT_BACKUP_DIR"
    set_mt_version "$TARGET_MT_VERSION"

    mkdir -p "$OUT_DIR/VERSION/latest-${TARGET_MT_VERSION}"
    set +e
    dotnet build "$ROOT_DIR/Sentinel.sln" > "$OUT_DIR/VERSION/latest-${TARGET_MT_VERSION}/build.log" 2>&1
    latest_build_rc=$?
    set -e

    if [[ "$latest_build_rc" -eq 0 ]]; then
      run_verify_lane "VERSION" "latest-apphost" "version_isolation_latest" Sentinel__RabbitImageTag=4.2-management ORCHESTRATION_MODE=apphost || true
      run_verify_lane "VERSION" "latest-direct" "version_isolation_latest" Sentinel__RabbitImageTag=4.2-management ORCHESTRATION_MODE=direct || true
    else
      append_build_only_failure "latest-${TARGET_MT_VERSION}" "$latest_build_rc" "$OUT_DIR/VERSION/latest-${TARGET_MT_VERSION}/build.log" "version_isolation_latest_build_failed"
    fi

    restore_mt_files "$MT_BACKUP_DIR"
    dotnet build "$ROOT_DIR/Sentinel.sln" > "$OUT_DIR/build-restore.log" 2>&1 || true
  fi

  # Lane 5: targeted runtime confirmation only if a new signal appears relative to control
  local base_sig current_sig
  base_sig="$(control_signature)"
  current_sig="$(last_verify_signature)"

  if [[ "$DECISION" != "global_cap_exhausted" && -n "$base_sig" && -n "$current_sig" && "$base_sig" != "$current_sig" ]]; then
    run_verify_lane "RUNTIME" "signal-shift-apphost" "signal_shift_detected_runtime_confirmation" Sentinel__RabbitImageTag=4.2-management ORCHESTRATION_MODE=apphost || true
    run_verify_lane "RUNTIME" "signal-shift-direct" "signal_shift_detected_runtime_confirmation" Sentinel__RabbitImageTag=4.2-management ORCHESTRATION_MODE=direct || true
  fi

  if [[ "$DECISION" != "global_cap_exhausted" ]] && repeated_no_signal_signature && ! has_strict_pass_candidate; then
    DECISION="upstream_repro"
    DECISION_REASON="Same strict failure signature repeated 3 times with no new telemetry signal. Auto-replan reached deterministic upstream lane."
    STOP_REASON="repeated_no_signal"
  fi

  # Gate lane + final strict streak
  local winning_label=""
  local winning_env=()
  local final_streak_env=()
  local winning_requires_latest="false"

  if [[ "$DECISION" != "global_cap_exhausted" ]] && has_strict_pass_candidate; then
    winning_label="$(first_strict_pass_label)"
    case "$winning_label" in
      latest-apphost|latest-apphost-repro)
        winning_env=(Sentinel__RabbitImageTag=4.2-management ORCHESTRATION_MODE=apphost)
        final_streak_env=(Sentinel__RabbitImageTag=4.2-management ORCHESTRATION_MODE=apphost)
        winning_requires_latest="true"
        ;;
      latest-direct|latest-direct-repro)
        winning_env=(Sentinel__RabbitImageTag=4.2-management ORCHESTRATION_MODE=direct)
        final_streak_env=(Sentinel__RabbitImageTag=4.2-management ORCHESTRATION_MODE=apphost)
        winning_requires_latest="true"
        ;;
      *direct*)
        winning_env=(Sentinel__RabbitImageTag=4.2-management ORCHESTRATION_MODE=direct)
        final_streak_env=(Sentinel__RabbitImageTag=4.2-management ORCHESTRATION_MODE=apphost)
        ;;
      *)
        winning_env=(Sentinel__RabbitImageTag=4.2-management ORCHESTRATION_MODE=apphost)
        final_streak_env=(Sentinel__RabbitImageTag=4.2-management ORCHESTRATION_MODE=apphost)
        ;;
    esac

    if [[ "$winning_requires_latest" == "true" ]]; then
      MT_BACKUP_DIR="$OUT_DIR/mt-backup-gate"
      backup_mt_files "$MT_BACKUP_DIR"
      set_mt_version "$TARGET_MT_VERSION"
      set +e
      dotnet build "$ROOT_DIR/Sentinel.sln" > "$OUT_DIR/latest-winning-build.log" 2>&1
      local latest_winning_build_rc=$?
      set -e
      if [[ "$latest_winning_build_rc" -ne 0 ]]; then
        winning_label=""
      fi
    fi

    if [[ -n "$winning_label" ]]; then
      run_reproducibility_check "GATE" "$winning_label" "strict_pass_candidate_repro_check" "${winning_env[@]}" || true
    fi

    if [[ "$winning_requires_latest" == "true" ]]; then
      restore_mt_files "$MT_BACKUP_DIR"
      dotnet build "$ROOT_DIR/Sentinel.sln" > "$OUT_DIR/build-restore-after-latest-gate.log" 2>&1 || true
    fi

    local gate_row
    gate_row="$(grep ',GATE,' "$LEDGER_CSV" | awk -F',' '$8=="pass" {print $0}' | tail -n1 || true)"
    if [[ -n "$gate_row" ]]; then
      local gate_label
      gate_label="$(printf "%s" "$gate_row" | awk -F',' '{print $4}')"
      local streak_dir="$OUT_DIR/final-strict-streak"
      mkdir -p "$streak_dir"
      log "Running final strict streak for gate_label=$gate_label"
      set +e
      env "${final_streak_env[@]}" PHASE3_MODE=strict STABILITY_RUNS=3 MAX_ATTEMPTS=10 "$VERIFY_SCRIPT" > "$streak_dir/verify.log" 2>&1
      local streak_rc=$?
      set -e
      if [[ "$streak_rc" -eq 0 ]]; then
        DECISION="local_fix_proven"
        DECISION_REASON="Winning lane '${gate_label}' reproduced strict recovery and passed strict streak STABILITY_RUNS=3."
        STOP_REASON="local_fix_proven"
      else
        DECISION="upstream_repro"
        DECISION_REASON="Candidate lane '${gate_label}' reproduced single strict pass but did not pass strict streak STABILITY_RUNS=3."
        STOP_REASON="strict_streak_failed"
      fi
    fi
  fi

  if [[ "$DECISION" == "upstream_repro" && -z "$STOP_REASON" ]]; then
    STOP_REASON="upstream_repro"
  fi
  if [[ "$DECISION" == "global_cap_exhausted" || "$STOP_REASON" == "global_cap_exhausted" ]]; then
    DECISION="global_cap_exhausted"
    STOP_REASON="global_cap_exhausted"
    local cap_lane cap_label
    cap_lane="$(awk -F',' '$5=="verify_phase3" {lane=$3} END {print lane}' "$LEDGER_CSV")"
    cap_label="$(awk -F',' '$5=="verify_phase3" {label=$4} END {print label}' "$LEDGER_CSV")"
    DECISION_REASON="Global strict verify attempt cap exhausted at lane='${cap_lane:-unknown}' label='${cap_label:-unknown}'."
  fi

  local control_row control_failure control_outage
  control_row="$(grep ',CONTROL,apphost-pinned,' "$LEDGER_CSV" | tail -n1 || true)"
  control_failure="$(printf "%s" "$control_row" | awk -F',' '{print $9}')"
  control_outage="$(printf "%s" "$control_row" | awk -F',' '{print $10}')"

  local probe_used="false"
  local probe_recovered="false"
  if awk -F',' '$15=="true" {found=1} END {exit(found?0:1)}' "$LEDGER_CSV"; then
    probe_used="true"
  fi
  if awk -F',' '$16=="true" {found=1} END {exit(found?0:1)}' "$LEDGER_CSV"; then
    probe_recovered="true"
  fi

  local global_attempts_remaining
  global_attempts_remaining=$((GLOBAL_MAX_ATTEMPTS - GLOBAL_ATTEMPTS_USED))
  if [[ "$global_attempts_remaining" -lt 0 ]]; then
    global_attempts_remaining=0
  fi

  {
    echo "decision=$DECISION"
    echo "reason=$DECISION_REASON"
    echo "stop_reason=$STOP_REASON"
    echo "approval_gate=$APPROVAL_GATE"
    echo "control_failure_class=$control_failure"
    echo "control_outage_classification=$control_outage"
    echo "control_comparison_csv=$CONTROL_COMPARISON_CSV"
    echo "target_mt_version=$TARGET_MT_VERSION"
    echo "lane_max_attempts=$LANE_MAX_ATTEMPTS"
    echo "global_max_attempts=$GLOBAL_MAX_ATTEMPTS"
    echo "global_attempts_used=$GLOBAL_ATTEMPTS_USED"
    echo "global_attempts_remaining=$global_attempts_remaining"
    echo "global_attempt=$GLOBAL_ATTEMPTS_USED"
    echo "auto_replan_reason=$LAST_AUTO_REPLAN_REASON"
    echo "probe_used=$probe_used"
    echo "probe_recovered=$probe_recovered"
    echo "ledger_csv=$LEDGER_CSV"
    echo "run_dir=$OUT_DIR"
  } > "$SUMMARY_TXT"

  cat > "$DECISION_JSON" <<JSON
{
  "generated_utc": "$(date -u +%FT%TZ)",
  "decision": "$DECISION",
  "reason": "$(printf "%s" "$DECISION_REASON" | sed 's/"/\\"/g')",
  "stop_reason": "$STOP_REASON",
  "approval_gate": "$APPROVAL_GATE",
  "control_failure_class": "$control_failure",
  "control_outage_classification": "$control_outage",
  "control_comparison_csv": "$CONTROL_COMPARISON_CSV",
  "target_mt_version": "$TARGET_MT_VERSION",
  "lane_max_attempts": $LANE_MAX_ATTEMPTS,
  "global_max_attempts": $GLOBAL_MAX_ATTEMPTS,
  "global_attempts_used": $GLOBAL_ATTEMPTS_USED,
  "global_attempts_remaining": $global_attempts_remaining,
  "global_attempt": $GLOBAL_ATTEMPTS_USED,
  "auto_replan_reason": "$(printf "%s" "$LAST_AUTO_REPLAN_REASON" | sed 's/"/\\"/g')",
  "probe_used": $probe_used,
  "probe_recovered": $probe_recovered,
  "ledger_csv": "$LEDGER_CSV",
  "run_dir": "$OUT_DIR"
}
JSON

  log "A/B isolation complete."
  log "Summary: $SUMMARY_TXT"
  log "Decision JSON: $DECISION_JSON"
}

main "$@"
