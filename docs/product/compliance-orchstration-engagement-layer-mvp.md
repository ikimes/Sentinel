# Compliance Orchestration & Engagement Layer (COEL)
## Phase A: Trusted Backbone Foundation
> Canonical roadmap foundation | Compatibility-first | Built to support later COEL phases

---

## Summary

Sentinel is no longer organized as a project that is still trying to prove its messaging backbone. The backbone is now the trusted foundation that later COEL phases will build on.

The canonical strategic model is:

- `Phase A: Trusted Backbone Foundation`
- `Phase B: Production Hardening`
- `Phase C: Engagement Layer MVP`
- `Phase D: Expanded COEL Experience`

Former `Phase 2`, `Phase 3`, and `Phase 4` remain in the repository as operational verifier lanes and evidence structures. They are no longer the forward roadmap. They are the proof layers inside `Phase A`.

> **North Star:** If a compliance signal is generated, it must reach the compliance ledger path reliably, observably, and replay-safely despite transient infrastructure failures.

---

## Current State

As of March 12, 2026, the trusted backbone foundation is implemented with verification tooling and retained local baseline expectations:

- RabbitMQ + PostgreSQL resources run under Aspire AppHost orchestration.
- API ingress persists durable dispatch through MassTransit transactional outbox.
- Worker consumption on queue `compliance` is replay-safe and ledger-backed.
- Append-only ledger writes and terminal failure handling are implemented.
- Foundation verification lanes exist for:
  - correctness
  - resilience
  - bounded operational confidence
- Read-only operational surfaces now exist for:
  - request status
  - recent requests
  - request history
  - readiness
  - operational snapshot capture

The backend also now has a UI-ready preparation slice in place:

- product-facing status vocabulary is normalized to `accepted | processed | failed`
- trusted internal actor metadata can be supplied by header and read back through the v0 read model
- a Shared-owned EF migration baseline now exists
- the default schema bootstrap posture is now migration-first via `Sentinel:DbSchemaBootstrapMode=migrate`
- `auto` and `ensurecreated` remain explicit compatibility modes for transition and local proof paths
- Postgres-backed API integration coverage exists for migration startup, status behavior, actor propagation, and recent/history reads

This means the backbone is treated as the base layer for the next COEL phases, while local verification still depends on running the documented diagnostics in an environment with the required .NET SDK and a running Docker engine.

---

## Phase Model

### Phase A — Trusted Backbone Foundation

Purpose:
- durable ingestion
- replay-safe processing
- append-only audit evidence
- deterministic operational verification

What is included:
- API ingress at `/api/compliance/check`
- PostgreSQL-backed MassTransit outbox/inbox persistence
- RabbitMQ transport on queue `compliance`
- Worker-side idempotency by `message_id`
- Append-only ledger in `compliance_ledger.events`
- Terminal failure policy
- Request status surface
- Readiness diagnostics
- Operational snapshot tooling

Historical verifier lanes retained inside Phase A:

| Legacy lane | New conceptual place | Status |
|---|---|---|
| `Phase 2` | `Foundation.A2 Correctness` | legacy name |
| `Phase 3` | `Foundation.A3 Resilience` | legacy name |
| `Phase 4` | `Foundation.A4 Operational Confidence` | legacy name |
| `rabbit-compat` | historical transport migration evidence | historical |

### Phase B — Production Hardening

Purpose:
- take the trusted backbone from local proof to production-grade operations

Expected work:
- tighten environment policy around migration-first schema bootstrap and eventually retire transitional compatibility modes
- backup/restore validation
- database outage and restart verification
- formal SLI/SLO and alerting posture
- diagnostics governance by environment
- additional automated test-project coverage

### Phase C — Engagement Layer MVP

Purpose:
- build the first internal UI and human interaction surfaces on top of the trusted backbone

Expected work:
- consume the existing request status, recent-request, and request-history backend surfaces in a first narrow UI
- operator and reviewer workflows
- internal review/task experiences
- ledger visibility and outcome presentation

### Phase D — Expanded COEL Experience

Purpose:
- broaden COEL beyond backbone plus first UI into the larger platform vision

Expected work:
- AI/LLM-assisted workflows
- dashboards and reporting
- richer human engagement flows
- future schema/projection/report generation layers

---

## Phase A Architecture

| Layer | Technology | Why It Is Here |
|---|---|---|
| Orchestration | .NET Aspire AppHost | explicit local orchestration and dependency startup |
| API Host | .NET 10 Web API | thin HTTP ingress plus durable dispatch |
| Messaging | MassTransit + RabbitMQ | at-least-once delivery, retry, error routing |
| Outbox/Inbox Persistence | PostgreSQL + MassTransit EF persistence | producer/consumer durability and replay safety |
| Audit Ledger | PostgreSQL append-only table | immutable compliance event record |
| Observability | OpenTelemetry -> Aspire Dashboard | end-to-end trace visibility |
| Contracts | shared class library (POCO) | stable message contract and low coupling |

---

## Governing Principles

### 1. Outbox Rule

API dispatch must be committed through transactional persistence so requests are durably staged before broker transfer.

### 2. Idempotency Is Non-Negotiable

Duplicate delivery must not create duplicate compliance effects.

### 3. Observability Is Audit Evidence

Dispatch, consume, duplicate-skip, terminal failure, and ledger persistence must be traceable through stable identifiers.

### 4. Ledger Is Append-Only

Application behavior treats the ledger as insert-only evidence.

### 5. Compatibility-First Evolution

As the project structure evolves, operational verifier paths remain stable until replacement paths are proven understandable and safe.

---

## Foundation.A2 / A3 / A4

### Foundation.A2 Correctness

Verified outcomes:
1. One request produces one durable handled outcome.
2. Worker writes append-only ledger rows to `compliance_ledger.events`.
3. Duplicate replay does not create duplicate ledger effects.
4. Terminal failure writes exactly one terminal `failed` ledger row after retries exhaust.

Canonical verifier lane:
- `diagnostics/phaseA/phase2/verify_backbone.sh`

### Foundation.A3 Resilience

Verified outcomes:
1. Trace continuity from ingress through outbox and worker processing.
2. Duplicate payloads remain replay-safe under the resilience gate.
3. Broker outage recovery completes after broker restart.

Canonical verifier lane:
- `diagnostics/phaseA/phase3/verify_phase3.sh`

Canonical support tooling:
- `diagnostics/phaseA/phase3/collect_phase3_facts.sh`
- `diagnostics/phaseA/phase3/run_ab_isolation.sh`

Current status:
- verifier tooling is present; local pass/fail status depends on the current diagnostic run

### Foundation.A4 Operational Confidence

Verified outcomes:
1. Bounded load remains green.
2. Backlog recovery drains successfully.
3. Terminal failure routing and evidence remain intact.
4. Stress and soak profiles produce operational trend data.

Canonical verifier lane:
- `diagnostics/phaseA/phase4/verify_phase4.sh`

Supporting tooling:
- `diagnostics/phaseA/phase4/capture_operational_snapshot.sh`

---

## What Is Deferred

Deferred beyond Phase A:
- broad production hardening items in `Phase B`
- frontend UI implementation in `Phase C` using the now-selected `Blazor` direction for the engagement layer
- AI/LLM workflow expansion
- compliance dashboards and advanced reporting
- richer engagement-layer orchestration

Deferred does not mean unsupported by the architecture. It means the trusted backbone now exists and those capabilities can be built on top of it.

## Forward Vision Package

For forward-looking, versioned product vision work beyond the current roadmap summary, start with:

- `docs/vision/pharma-control-plane/README.md`

---

## Compatibility Mapping

This consolidation now treats `phaseA` as the only supported diagnostics structure.

How to interpret old names:

| Old name/path | New conceptual place | Status |
|---|---|---|
| `diagnostics/phaseA/phase2/*` | `Phase A / Foundation.A2 Correctness` | canonical operational path |
| `diagnostics/phaseA/phase3/*` | `Phase A / Foundation.A3 Resilience` | canonical operational path |
| `diagnostics/phaseA/phase4/*` | `Phase A / Foundation.A4 Operational Confidence` | canonical operational path |
| `diagnostics/rabbit-compat/*` | historical compatibility and migration evidence | historical |

---

## Where To Start

For future builders:
- roadmap foundation: `docs/product/compliance-orchstration-engagement-layer-mvp.md`
- versioned product vision packages: `docs/vision/README.md`
- messaging runbook: `docs/architecture/compliance-messaging-pattern.md`
- docs index: `docs/README.md`
- diagnostics index: `diagnostics/README.md`
- Phase A diagnostics index: `diagnostics/phaseA/README.md`

For operators and backbone maintainers:
- correctness verifier: `diagnostics/phaseA/phase2/verify_backbone.sh`
- resilience verifier: `diagnostics/phaseA/phase3/verify_phase3.sh`
- operational verifier: `diagnostics/phaseA/phase4/verify_phase4.sh`
