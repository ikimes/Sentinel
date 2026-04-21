# Phase 4 Verification

Phase 4 is Sentinel's backend operational gate. It extends the correctness and outage recovery checks from Phases 2 and 3 with bounded non-functional verification for the API, MassTransit outbox/inbox flow, PostgreSQL ledger, and RabbitMQ transport.

## Profiles

- `release-bounded-load`
  - Sends a moderate concurrent batch through `POST /api/compliance/check`.
  - Verifies success rate, dispatch-to-ledger latency, duplicate suppression, queue depth, and queue/unacked peaks.
- `release-backlog-recovery`
  - Sends a short burst larger than the worker immediately drains.
  - Verifies backlog creation, drain-to-zero, duplicate suppression, and measured drain time.
- `release-terminal-failure`
  - Uses the diagnostics-only forced-failure path.
  - Verifies exactly one terminal `failed` ledger row and message routing to `compliance_error`.
- `diagnostic-stress`
  - Runs a higher-concurrency burst for exploratory capacity evidence.
  - Produces evidence but is never release-gating.
- `diagnostic-soak`
  - Runs sustained low-to-moderate traffic for a configurable duration.
  - Produces trend data for latency, backlog, and queue drift.
- `diagnostic-chaos-load`
  - Stops RabbitMQ briefly while load is in flight.
  - Verifies accepted requests are not lost, duplicate effects remain zero, and backlog eventually drains.

## Entry Points

Canonical release gate:

```bash
diagnostics/phaseA/phase4/verify_phase4.sh
```

Companion PostgreSQL restart verifier:

```bash
diagnostics/phaseA/phase4/verify_db_restart.sh
```

It proves:

- readiness degrades when PostgreSQL is stopped
- readiness returns healthy after PostgreSQL restarts
- a fresh compliance request still reaches `processed` after recovery
- recovery evidence is inspectable through status, recent, history, and ledger artifacts

Companion live read smoke:

```bash
diagnostics/phaseA/phase4/smoke_recent_history.sh
```

This smoke script assumes the stack is already running, submits one real request, waits for a terminal `processed` read state, then verifies:

- `GET /api/compliance/check/recent` includes the request
- `GET /api/compliance/check/{requestId}/history` returns an accepted-to-processed timeline
- neither response exposes the original request content

Specific profile:

```bash
PHASE4_PROFILE=diagnostic-chaos-load diagnostics/phaseA/phase4/verify_phase4.sh
```

Important inputs:

- `BASELINE_FILE`
- `PHASE4_PROFILE`
- `SOAK_SECONDS`
- `STRESS_REQUEST_COUNT`
- `STRESS_CONCURRENCY`
- `CHAOS_BROKER_STOP_SECONDS`
- `Sentinel__WorkerPrefetchCount`
- `Sentinel__WorkerConcurrentMessageLimit`
- `Sentinel__WorkerOutboxQueryDelayMs`
- `Sentinel__WorkerOutboxQueryMessageLimit`

## Read-Only Operational Surfaces

- `GET /api/compliance/check/{requestId}`
  - Returns `404` for unknown requests.
  - Returns `in_flight` while a dispatch record exists but no terminal ledger row exists yet.
  - Returns terminal `processed` or `failed` from `compliance_ledger.events`.
- `GET /api/diagnostics/readiness`
  - Returns operator-grade readiness details for API, PostgreSQL, RabbitMQ, outbox/inbox counts, dispatch count, error queue depth, and latest persisted worker signal timestamps.

Canonical backend lifecycle logs retained by this phase:

- `COMPLIANCE_API_RECEIVED`
- `COMPLIANCE_API_DISPATCHED`
- `COMPLIANCE_API_OUTBOX_PENDING`
- `COMPLIANCE_API_STATUS_READ`
- `COMPLIANCE_WORKER_RECEIVED`
- `COMPLIANCE_WORKER_PROCESSED`
- `COMPLIANCE_LEDGER_WRITTEN`
- `COMPLIANCE_WORKER_FAILED`
- `COMPLIANCE_DUPLICATE_SKIPPED`
- `COMPLIANCE_DIAGNOSTICS_READINESS`

## Evidence

Each run writes to:

`diagnostics/phaseA/phase4/evidence/<utc-stamp>/`

The PostgreSQL restart verifier writes to:

`diagnostics/phaseA/phase4/evidence/<utc-stamp>-db-restart/`

Core evidence contract:

- `summary.txt`
- `manifest.json`
- `checks.txt`
- `load_samples.csv`
- `latency_summary.json`
- `latency_breakdown_summary.json`
- `queue_depth_timeline.csv`
- `rabbitmq_timeline.csv`
- `persistence_timeline.csv`
- `drain_timeline.csv`
- `verification.sql.out`
- copied Aspire resource logs

Additional profile-specific evidence may include:

- `failure_injection_summary.txt`
- `chaos_load_classification.csv`
- RabbitMQ connection/channel snapshots

The PostgreSQL restart verifier also captures:

- `outage-readiness.json`
- `recovery-readiness.json`
- `baseline-post.json`
- `baseline-status.json`
- `recovery-post.json`
- `recovery-status.json`
- `recovery-recent.json`
- `recovery-history.json`
- `request-ledger.csv`
- `db-counts.txt`

The recent/history smoke writes a compact evidence bundle under:

`diagnostics/phaseA/phase4/evidence/<utc-stamp>/recent-history-smoke/`

Smoke artifacts include:

- `summary.txt`
- `manifest.json`
- `checks.txt`
- `post-response.json`
- `status-response.json`
- `recent-response.json`
- `history-response.json`

Operational snapshots can also be captured without running a verifier:

```bash
diagnostics/phaseA/phase4/capture_operational_snapshot.sh
```

Snapshot artifacts are read-only and include:

- `readiness.json`
- `sender.json`
- `operational_snapshot.json`
- `queue_snapshot.tsv`
- `db_counts.txt`
- `ledger_status_counts.csv`
- `recent_ledger_rows.csv`
- `baseline_comparison.txt`

## Gating Rules

- Release-gating profiles are controlled by `diagnostics/baselines/backend-sli-baseline.v1.json`.
- Diagnostic profiles always record `gate_eligible=false`.
- Missing RabbitMQ metrics must be recorded as `metric_unavailable`, not inferred.
