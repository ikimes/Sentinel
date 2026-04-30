# UI-Ready Backend Execution List

## Purpose

This note converts the current Sentinel analysis into a sequenced execution list that stops at a UI-ready backend.

It does not include frontend implementation work.

## Reconciliation Status

As of March 12, 2026, the core UI-ready backend slice described in this note has been implemented and verified green.

Completed in code and verification:

- Shared-owned migration ownership and baseline migration
- migration-backed clean-database startup validation
- normalized `accepted | processed | failed` status vocabulary
- `GET /api/compliance/check/recent`
- `GET /api/compliance/check/{requestId}/history`
- trusted internal actor-header persistence and readback
- Postgres-backed API integration coverage
- post-change `phase2`, `phase3`, and `phase4` verifier reruns

Still open as artifact/process follow-up:

- no fresh pre-change verifier baseline was captured during the implementation session
- the automated test layer is currently integration-heavy; small standalone unit tests were not added in this slice

## Artifact Decisions

- **Actor v0**: use a **trusted internal stub** now; actor identity is temporarily supplied by the internal request layer and persisted for audit/read-model use; real auth/SSO is explicitly deferred.
- **Actor input mechanism**: use **trusted internal headers**, not request-body fields, so the temporary model can later be replaced by real authentication with minimal API-body churn.
- **Status vocabulary v0**: use **`accepted` / `processed` / `failed`** as the product-facing status set; `accepted` replaces both current `Processing` and `in_flight` wording in the execution plan.

## Public Interface Decisions

- recent endpoint path: `GET /api/compliance/check/recent`
- history endpoint path: `GET /api/compliance/check/{requestId}/history`
- actor header names:
  - `X-Actor-Id`
  - `X-Actor-Type`
  - `X-Actor-Display-Name`
- actor persisted fields:
  - `actorId`
  - `actorType`
  - `actorDisplayName`
- v0 list/history views must not store or expose full request content; only metadata needed for the hello-world flow is in scope

## Ordered Execution Checklist

### 1. Lock baseline guardrails

- [x] Treat `diagnostics/phaseA/phase2/verify_backbone.sh`, `diagnostics/phaseA/phase3/verify_phase3.sh`, and `diagnostics/phaseA/phase4/verify_phase4.sh` as mandatory before/after checks around backend-prep work.
- [ ] Capture pre-change baseline evidence before migration, contract, or read-model work begins.
- [x] Require post-change verifier reruns before declaring the backend slice complete.

Done when:
- the execution log for this slice includes pre-change and post-change verifier references
- no backend-prep work is accepted without verifier-backed comparison

### 2. Establish migration ownership

- [x] Choose `Sentinel.Shared` as the single migration assembly for app-owned persistence.
- [x] Introduce the first baseline EF migration there for `dispatch_records` and `compliance_ledger.events`.
- [x] Validate clean-database startup through migrations rather than relying on `EnsureCreated()` as the steady-state path.
- [x] Keep `Sentinel:DbSchemaBootstrapMode=auto` during the transition so existing local flows do not break while the migration path is proved out.

Done when:
- a clean database can boot the app through the migration path
- migration ownership is explicit and documented
- migration-backed startup is verified before UI work begins

### 3. Add thin automated test scaffolding

- [x] Add API integration-test scaffolding for the compliance read surfaces.
- [ ] Add small unit tests around status mapping and query composition logic.
- [x] Make the initial test layer narrow and fast; it is meant to complement the shell verifiers, not replace them.

Done when:
- status normalization has automated coverage
- recent-requests and request-history reads have automated coverage
- actor-header propagation/read-model projection has automated coverage

### 4. Normalize status contracts

- [x] Align write and read semantics to `accepted | processed | failed`.
- [x] Replace mixed product/technical wording such as `Processing` and `in_flight` in the UI-facing contract plan.
- [x] Keep the mapping simple: `accepted` means durably accepted but not yet terminal.

Done when:
- the planned write response and read responses use the same vocabulary
- the status contract is stable enough for a first narrow UI without client-side interpretation rules

### 5. Add recent-requests read surface

- [x] Plan and implement `GET /api/compliance/check/recent`.
- [x] Return only v0 metadata needed for the hello-world flow, not full request content.
- [x] Make the response suitable for an operator list view backed by stable semantics.

Done when:
- the endpoint returns a bounded recent-request view
- the payload includes only metadata needed for list display and navigation
- automated coverage exists for the query behavior and response contract

### 6. Add request-history read surface

- [x] Plan and implement `GET /api/compliance/check/{requestId}/history`.
- [x] Compose the history from acceptance metadata plus append-only ledger evidence.
- [x] Return a stable timeline suitable for a first detail page.

Done when:
- a single request can be inspected as a timeline/history view
- `accepted`, `processed`, and `failed` states are represented consistently
- error detail and trace metadata are available where appropriate

### 7. Add minimal actor persistence

- [x] Accept `X-Actor-Id`, `X-Actor-Type`, and `X-Actor-Display-Name` from the trusted internal request layer.
- [x] Persist `actorId`, `actorType`, and `actorDisplayName` for audit/read-model use.
- [x] Expose actor metadata through the recent-request and request-history reads.
- [x] Label this implementation as temporary and internal-only until real auth replaces it.

Done when:
- actor metadata survives acceptance and can be read back from the v0 read model
- the artifact trail clearly states that this is a trusted internal stub, not a finished auth model
- the UI can display who initiated a request without inventing client-only state

### 8. Define the UI-ready backend gate

- [x] Treat the backend as UI-ready only when migrations, thin tests, normalized statuses, recent/history reads, and actor stub persistence are all complete.
- [x] Do not start the first hello-world UI implementation until this gate is met.

Done when:
- the backend slice can support a narrow UI with no unresolved API-shape decisions
- the first UI can restrict itself to submit, list, and detail/history flows

## UI-Ready Backend Exit Criteria

The backend is ready for a narrow hello-world UI when all of the following are true:

- verifier reruns have been completed before and after the backend-prep slice
- migration ownership is established in `Sentinel.Shared`
- clean-database startup through migrations has been validated
- thin automated tests exist for status normalization, recent requests, request history, and actor propagation
- UI-facing status vocabulary is stable as `accepted | processed | failed`
- `GET /api/compliance/check/recent` exists
- `GET /api/compliance/check/{requestId}/history` exists
- actor metadata is accepted from trusted internal headers and exposed through the v0 read model
- no frontend work is required to invent missing backend semantics

Practical status:

- functionally met for a narrow hello-world UI
- one process artifact remains open: a fresh pre-change verifier baseline was not captured during the implementation session
- one optional hardening follow-up remains open: add small standalone unit tests beside the current integration suite

## Deferred After V0

The following remain intentionally deferred until after the first backend-prep slice:

- real auth/SSO
- reviewer workflow engine
- approval/sign-off model beyond the temporary actor stub
- backup/restore drills
- broader database outage matrix
- wider frontend implementation beyond the narrow hello-world surface
