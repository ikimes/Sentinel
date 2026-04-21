# Compliance Messaging Pattern
## Phase A Backbone Runbook

This document is the canonical technical runbook for Sentinel's trusted backbone foundation.

It describes the operational message flow and the verifier lanes that prove `Phase A`, not the forward product roadmap.

## Goal

When `POST /api/compliance/check` is called:
1. API creates `AnalyzeComplianceRequest`.
2. API persists durable dispatch through the MassTransit transactional bus outbox in PostgreSQL.
3. MassTransit dispatches to RabbitMQ queue `compliance`.
4. `sentinel-worker` consumes the message, enforces idempotency by `MessageId`, and writes an append-only ledger event.

## Current Flow

1. Client calls `POST /api/compliance/check`.
2. API maps request to `AnalyzeComplianceRequest`.
3. API sends to `queue:compliance`.
4. API writes a `dispatch_records` row and commits `SaveChangesAsync()`.
5. MassTransit bus outbox persists and dispatches via RabbitMQ.
6. Worker receives from queue `compliance` and executes `ComplianceHandler`.
7. Worker checks `compliance_ledger.events` for duplicate `message_id`.
8. Worker writes `status=processed` ledger evidence on success.
9. If retries exhaust, worker writes exactly one terminal `status=failed` ledger row.

## Foundation Verification Lanes

Sentinel uses `phaseA/phase2`, `phaseA/phase3`, and `phaseA/phase4` as the trusted backbone verification lanes:

| Legacy lane | Phase A meaning | Entry point | Status |
|---|---|---|---|
| `phase2` | `Foundation.A2 Correctness` | `diagnostics/phaseA/phase2/verify_backbone.sh` | canonical |
| `phase3` | `Foundation.A3 Resilience` | `diagnostics/phaseA/phase3/verify_phase3.sh` | canonical |
| `phase4` | `Foundation.A4 Operational Confidence` | `diagnostics/phaseA/phase4/verify_phase4.sh` | canonical |
| `rabbit-compat` | historical transport migration evidence | `diagnostics/rabbit-compat/README.md` | historical |

## Source of Truth

- API dispatch:
  - `Sentinel.Api/features/compliance/CheckText.cs`
- API transport/persistence:
  - `Sentinel.Api/Program.cs`
- Worker transport/persistence:
  - `Sentinel.Worker/Program.cs`
- Worker consumer:
  - `Sentinel.Worker/ComplianceHandler.cs`
- Shared contracts/persistence:
  - `Sentinel.Shared/Contracts.cs`
  - `Sentinel.Shared/Messaging/MessagingDbContext.cs`
- AppHost wiring:
  - `Sentinel.AppHost/Program.cs`

## Runtime Surfaces

Write path:
- `POST /api/compliance/check`

Read-only operational surfaces:
- `GET /api/compliance/check/{requestId}`
- `GET /api/diagnostics/readiness`

Diagnostic-only surfaces:
- `GET /api/diagnostics/messaging/sender`
- `POST /api/diagnostics/messaging/replay-duplicate`
- `POST /api/diagnostics/messaging/force-failure`

## Validation Checklist

After startup:
1. API is reachable.
2. Worker is connected to queue `compliance`.
3. PostgreSQL persistence is available.
4. RabbitMQ transport is available.
5. A POST results in:
   - API dispatch evidence
   - worker receive evidence
   - ledger evidence

Expected backbone lifecycle logs include:
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

## Verification Commands

Build:

```bash
dotnet build Sentinel.sln
```

Foundation.A2 correctness:

```bash
diagnostics/phaseA/phase2/verify_backbone.sh
```

Foundation.A3 resilience:

```bash
diagnostics/phaseA/phase3/verify_phase3.sh
```

Phase A3 support tooling:

```bash
diagnostics/phaseA/phase3/collect_phase3_facts.sh
diagnostics/phaseA/phase3/run_ab_isolation.sh
```

Foundation.A4 operational confidence:

```bash
diagnostics/phaseA/phase4/verify_phase4.sh
```

Operational snapshot:

```bash
diagnostics/phaseA/phase4/capture_operational_snapshot.sh
```

## Persistence Inspection Queries

Run against `compliancedb`:

```sql
select count(*) from masstransit.dispatch_records;
select count(*) from masstransit.outbox_message;
select count(*) from masstransit.outbox_state;
select count(*) from masstransit.inbox_state;

select *
from masstransit.dispatch_records
order by created_at_utc desc
limit 20;

select id, request_id, message_id, correlation_id, status, handler_duration_ms, processed_at_utc
from compliance_ledger.events
order by processed_at_utc desc
limit 20;
```

Duplicate verification query:

```sql
select message_id, count(*) as row_count
from compliance_ledger.events
group by message_id
having count(*) > 1;
```

## Operational Notes

- `Sentinel:DbSchemaBootstrapMode` now defaults to `auto`: use EF migrations when they exist, otherwise fall back to `EnsureCreated()` for local/dev bootstrap.
- Full migrations cutover remains a `Phase B` hardening item.
- This runbook is canonical for the trusted backbone foundation only. Forward roadmap planning belongs in `docs/product/compliance-orchstration-engagement-layer-mvp.md`.
