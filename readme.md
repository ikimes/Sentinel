# Sentinel

Sentinel is a .NET compliance-coordination prototype that explores how to make cross-system follow-up work visible, auditable, and easier to operate.

At its core, the project models a compliance "matter" as a coordination object that moves through:
- intake and dispatch
- durable processing
- ledger-backed read models
- an operator-facing workspace for queue, selected matter state, timeline, and operator brief

This repository is being used as a technical deep-dive project, so it contains both the running implementation and the supporting docs that explain the architecture, verification approach, and product direction.

## What It Demonstrates

- ASP.NET Core API and worker services coordinated through RabbitMQ and PostgreSQL
- durable messaging patterns with outbox/inbox style guarantees
- replay-backed Stage 4 read models for:
  - matter overview
  - matter timeline
  - queue / exception projection
- a Blazor Server operator dashboard backed by real matter queue, overview, and timeline endpoints
- diagnostics and verification scripts for correctness, resilience, and operational confidence

## Current State

The repo currently includes:

- `Sentinel.Api`
  - HTTP write/read surfaces and compliance-specific endpoints
- `Sentinel.Worker`
  - background processing for compliance requests
- `Sentinel.Shared`
  - contracts, EF-backed messaging persistence, and bootstrap utilities
- `Sentinel.Web`
  - Blazor Server operator dashboard for queue, selected matter state, timeline, and a UI-derived operator brief
- `Sentinel.AppHost`
  - Aspire-based local orchestration for the full stack
- `Sentinel.Api.Tests`
  - API and logic-level verification

The implementation is organized around the current lifecycle model:

- `Phase A: Trusted Backbone Foundation`
- `Phase B: Production Hardening`
- `Phase C: Engagement Layer MVP`
- `Phase D: Expanded COEL Experience`

Historical notes may still reference `Phase 2`, `Phase 3`, and `Phase 4`, but the supported diagnostics structure now lives under `diagnostics/phaseA/`.

## Architecture At A Glance

```text
Blazor shell
    -> Sentinel.Api
        -> PostgreSQL (read/write persistence)
        -> RabbitMQ (durable dispatch)
            -> Sentinel.Worker
                -> PostgreSQL ledger / messaging tables
```

The operator-facing shell is intentionally read-oriented right now:

- queue
- selected matter summary
- timeline
- operator brief / context

The current web experience centers on one primary dashboard flow backed by the matter queue, overview, and timeline endpoints. The operator brief is currently derived in the UI from those same API-backed facts rather than served as its own endpoint.

## Tech Stack

- .NET 10
- ASP.NET Core
- Blazor Server
- Aspire AppHost
- MassTransit
- PostgreSQL
- RabbitMQ
- Entity Framework Core

## Running Locally

Preferred local UI workflow:

```bash
just dev-ui
```

That starts:

- the API in replay-backed development mode on `http://localhost:5022`
- the Blazor dashboard under `dotnet watch` on `http://localhost:5026`

Use this when iterating on the dashboard or other read-oriented UI work.

Full local stack with Aspire:

```bash
just apphost
```

That brings up:

- the API
- the worker
- RabbitMQ
- PostgreSQL
- the Blazor shell

The standalone API replay mode exists to support fast local dashboard work without requiring the full database and broker stack. It is a development convenience, not the primary product topology.

## Build And Test

Build the solution:

```bash
just build
```

Run the test project:

```bash
just test
```

## Configuration And Local Defaults

Sentinel is set up so other developers can launch it locally without needing any personal or deployment-specific secrets from this repository.

Repository-safe defaults:

- localhost-only URLs and launch profiles
- sample database and broker names
- clearly fake placeholder passwords such as `example-password`
- replay-backed API mode for faster local UI work

Override with environment variables when needed:

- `ConnectionStrings__compliancedb`
- `ConnectionStrings__compliancedb_admin`
- `ConnectionStrings__messaging`
- `Sentinel__DbAppRolePassword`

Practical guidance:

- use the committed defaults for local exploration and UI iteration
- use environment variables for any non-local, shared, or deployment-like setup
- do not replace sample placeholders in tracked files with real credentials

## Verification Scripts

The trusted-backbone diagnostics live under `diagnostics/phaseA/`.

Canonical verification entrypoints:

```bash
diagnostics/phaseA/phase2/verify_backbone.sh
diagnostics/phaseA/phase3/verify_phase3.sh
diagnostics/phaseA/phase4/verify_phase4.sh
diagnostics/phaseA/phase4/verify_db_restart.sh
diagnostics/phaseA/phase4/capture_operational_snapshot.sh
```

These scripts are meant to be committed as durable tooling.
Generated evidence, snapshots, local test results, and review artifacts are intentionally kept out of Git.

## Key Runtime Surfaces

Write path:

```text
POST /api/compliance/check
```

Read-oriented API surfaces:

```text
GET /api/compliance/check/{requestId}
GET /api/compliance/check/recent
GET /api/compliance/check/{requestId}/history
GET /api/compliance/matters/{scenarioId}/overview
GET /api/compliance/matters/{scenarioId}/timeline
GET /api/compliance/matters/queue
```

UI-derived dashboard surface:

```text
Operator brief is composed in Sentinel.Web from queue, overview, and timeline data.
```

Operational surface:

```text
GET /api/diagnostics/readiness
```

## Where To Look Next

- docs index:
  - [docs/README.md](docs/README.md)
- diagnostics index:
  - [diagnostics/README.md](diagnostics/README.md)
- roadmap and current phase model:
  - [docs/product/compliance-orchstration-engagement-layer-mvp.md](docs/product/compliance-orchstration-engagement-layer-mvp.md)
- trusted backbone runbook:
  - [docs/architecture/compliance-messaging-pattern.md](docs/architecture/compliance-messaging-pattern.md)
- product and vision package:
  - [docs/vision/README.md](docs/vision/README.md)

## Notes

- Local/dev defaults in this repo are sample-only and intended for non-production use.
- Historical repro work is intentionally omitted from this public baseline.
- Generated diagnostics bundles, screenshots, dumps, and local tool state are gitignored on purpose.
- This project is still evolving, so some docs and UI routes remain exploratory by design.
