# Verification Gaps and Follow-Up

## Purpose

This note records the most obvious remaining verification gaps after the UI-ready backend slice was implemented and verified green.

It is intended as a later follow-up artifact, not a blocker for starting the first narrow hello-world UI.

As of March 13, 2026, the current verification stack is strong for MVP backend work:

- `dotnet build Sentinel.sln`
- `dotnet test Sentinel.sln`
- `diagnostics/phaseA/phase2/verify_backbone.sh`
- `diagnostics/phaseA/phase3/verify_phase3.sh`
- `diagnostics/phaseA/phase4/verify_phase4.sh`

That said, a few meaningful gaps still remain.

## Current Coverage Strengths

What is already covered well:

- real-stack correctness, duplicate replay, and terminal failure handling
- broker outage and recovery behavior
- bounded load, backlog drain, and operational confidence checks
- migration-backed startup on a clean PostgreSQL database
- API-level coverage for:
  - `accepted | processed | failed`
  - actor header propagation
  - recent-request read shape
  - request-history read shape
  - no full-content exposure in recent/history responses

## Obvious Remaining Gaps

### 1. Database outage, restart, backup, and restore verification

Current state:

- broker outage is exercised
- database outage and lifecycle recovery are not yet exercised with the same rigor

Why it matters:

- the database is now central to the trusted backbone, migration lifecycle, read model, and actor persistence
- broker-only resilience is not enough for a stronger pilot posture

Recommended follow-up:

- add a database restart verifier
- add a database outage-and-recovery verifier
- add at least one backup/restore drill artifact

### 2. Legacy schema adoption path lacks direct automated proof

Current state:

- the bootstrapper now contains logic to adopt an older `EnsureCreated()` schema into the migration baseline
- clean migration startup is covered
- legacy-adoption behavior is not yet directly tested

Why it matters:

- this is a real transition path for existing local or retained databases
- it is easy for this code path to silently drift if it only exists as inferred behavior

Recommended follow-up:

- add an automated test that starts from a legacy schema without `__EFMigrationsHistory`
- verify actor columns are added and the baseline migration is recorded

### 3. New recent/history reads are not yet exercised in a full real-broker verifier

Current state:

- the API integration suite covers `recent` and `history`
- the shell verifiers still focus mainly on write path, worker path, ledger behavior, and diagnostics

Why it matters:

- the new UI-ready backend seams are important enough to deserve at least one real-stack smoke path
- this would protect against future drift between API integration behavior and full runtime behavior

Recommended follow-up:

- extend a Phase A verifier or add a narrow companion script that:
  - performs a real POST
  - waits for worker completion
  - asserts `GET /api/compliance/check/recent`
  - asserts `GET /api/compliance/check/{requestId}/history`

### 4. The automated test layer is still integration-heavy

Current state:

- the current `Sentinel.Api.Tests` project provides strong end-to-end API coverage
- there are not yet small standalone unit tests around status mapping and projection logic

Why it matters:

- integration tests are great safety nets but are slower and broader than necessary for some regressions
- small pure-logic tests would make refactors safer around status mapping and timeline composition

Recommended follow-up:

- add a few lightweight tests around:
  - status mapping
  - earliest accepted-time selection
  - terminal-event projection
  - actor-header normalization

### 5. A few cheap endpoint edge cases are still missing

Current state:

- the main happy paths and important failure/history cases are covered
- several small edge cases are not yet explicitly asserted

Examples:

- `GET /api/compliance/check/{requestId}` returns `404` for unknown request
- plain status endpoint returns `failed` with failure detail from ledger rows
- recent/history semantics when duplicate dispatch rows exist
- accepted-time semantics remain tied to earliest dispatch row

Why it matters:

- these are inexpensive tests with good regression value
- they sharpen the contract before UI code starts relying on it

Recommended follow-up:

- add a compact edge-case test group in the current API test project

## Priority Order

Recommended order for later follow-up:

1. add one database restart/outage verifier
2. add one legacy-schema adoption test
3. add one real-stack smoke check for `recent` and `history`
4. add a small unit-test group around status/projection logic
5. add cheap API edge-case assertions

## Practical Read

These gaps do not change the current verdict:

> the backend is sufficiently verified to start a narrow hello-world UI

They do change the next verification-hardening priorities after UI work begins.
