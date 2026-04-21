# Sentinel v2 Autonomous Earned-Thesis Operating System

Status: `working memo`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Related notes:

- `docs/vision/pharma-control-plane/drafts/v2/earned-thesis-plan.md`
- `docs/vision/pharma-control-plane/drafts/v2/earned-thesis-scoreboard.md`
- `docs/vision/pharma-control-plane/current/v1/mvp-simulation-harness-and-scenario-pack.md`
- `docs/vision/pharma-control-plane/current/v1/pilot-acceptance-plan.md`
- `docs/todo/engagement-layer-proof-execution-list.md`

## Purpose

This memo defines the internal-only operating system for autonomous thesis-earning cycles inside the Sentinel repo.

It exists so future Codex or agent runs can:

- use one repeatable loop
- update one stable scoreboard
- choose one narrow proof slice at a time
- stop honestly when the next blocker is external

## Short Read

This operating system does not try to earn Sentinel's full company thesis autonomously.

It governs a narrower internal loop:

- strengthen product proof
- strengthen productization proof
- keep workflow, buying-path, and build-vs-buy proof prepared for future field validation

In internal-only mode, the loop may move some proof areas to `internally-proven`, but it must never pretend to have earned buyer-facing proof without field evidence.

## Operating Boundary

This operating system assumes:

- work happens inside the repo
- no external buyer interviews are run by the loop
- no pilot commitments are created by the loop
- external evidence remains an explicit dependency, not a silent assumption

The current backbone baseline is assumed to be trusted:

- `Phase A` verifier lanes are green
- the UI-ready backend slice is implemented
- the next leverage point is `Phase C` engagement-layer proof

## Allowed Decision States

These are the only allowed decision states for the scoreboard:

| State | Meaning |
|---|---|
| `blocked` | progress cannot continue with current repo evidence because an internal prerequisite or external dependency is missing |
| `ready-for-field` | internal preparation is strong enough that the next real proof requires field evidence |
| `internally-proven` | the repo contains enough implementation and verification evidence to support the claim internally |
| `earned` | the claim is supported by real field evidence, not only repo-side proof |

### Internal-only limits

In this operating mode:

- `workflow_proof` may not move past `ready-for-field`
- `buying_path_proof` may not move past `ready-for-field`
- `build_vs_buy_proof` may not move past `ready-for-field`
- only `product_proof` and `productization_proof` may move to `internally-proven`
- no proof area should be marked `earned` unless a later non-internal mode adds real field evidence

## Cycle Inputs

Every cycle must begin by reading from the same input set:

- current repo implementation under `Sentinel.Api`, `Sentinel.Shared`, `Sentinel.Worker`, and `Sentinel.Api.Tests`
- current backbone diagnostics and verifier lanes under `diagnostics/phaseA/`
- current roadmap and execution artifacts under `docs/` and `docs/todo/`
- current canonical wedge and proof notes under `docs/vision/pharma-control-plane/current/v1/`
- current narrowing artifacts under `docs/vision/pharma-control-plane/drafts/v2/`
- the live state interface in `docs/vision/pharma-control-plane/drafts/v2/earned-thesis-scoreboard.md`

If the scoreboard is stale relative to those inputs, the cycle must refresh it before doing anything else.

## Step Order

Every autonomous cycle must follow this order:

### 1. Refresh the scoreboard

Use repo truth only:

- docs
- code
- tests
- diagnostics evidence
- current verifier status

Do not carry forward unstated assumptions from prior turns.

### 2. Bucket every open claim

Each open claim must be placed into exactly one bucket:

- internally provable now
- blocked on external evidence
- out of scope for the current wedge

If a claim does not fit the current wedge, the cycle should reject it rather than quietly expanding the product story.

### 3. Choose one proof slice

Advance only one internal proof slice per cycle.

Choose the slice that:

- improves the five operator questions most directly
- requires the least new integration breadth
- stays inside one source stub, one downstream stub, and configuration-backed clock logic

### 4. Run the scope gate

Reject the slice if it mainly adds:

- platform breadth
- generic workflow
- dashboarding
- graph-first exploration
- demo polish with no proof value
- many-system integration requirements

### 5. Execute and verify the slice

The slice is only valid if it is verified against:

- `dotnet build Sentinel.sln`
- the relevant `Sentinel.Api.Tests` coverage
- `diagnostics/phaseA/phase2/verify_backbone.sh`
- `diagnostics/phaseA/phase3/verify_phase3.sh`
- `diagnostics/phaseA/phase4/verify_phase4.sh`

### 6. Close the cycle with one written decision

Every cycle must end with exactly one decision:

- continue the current slice
- re-scope the slice
- stop because the next blocker is external

That decision must be written into the scoreboard together with exactly one next action and an explicit blocker classification.

## Gate Rules

### 1. Refresh gate

No slice work may begin until the scoreboard has been refreshed from current repo state.

### 2. Single-slice gate

Only one internal proof slice may be `in progress` at a time.

Parallel implementation work is allowed only when it belongs to the same slice and does not widen scope.

### 3. Five-question gate

A task is only in scope if it materially improves one or more of these answers:

- who owns this matter now
- which clock is active
- what is blocked
- which downstream action is still open
- why the current decision exists

### 4. Minimal-breadth gate

The loop must prefer:

- deterministic replay
- configuration-backed clocks
- one source-system stub
- one downstream target stub

The loop must avoid:

- broad integration programs
- generalized workflow engines
- dashboard-first slices
- category-expanding work

### 5. Verification gate

`product_proof` and `productization_proof` may not be promoted without:

- green build
- green or intentionally updated API tests
- pre-change and post-change verifier awareness
- post-change reruns of the canonical `Phase A` verifier lanes

### 6. Promotion gate

In internal-only mode:

- `workflow_proof`, `buying_path_proof`, and `build_vs_buy_proof` may advance to `ready-for-field` only
- `product_proof` may advance to `internally-proven` only after the proof slices answer the five operator questions on live scenarios
- `productization_proof` may advance to `internally-proven` only after the same matter model survives repeated scenario use without services drift

## Stop Rules

Stop the cycle early if any of these dominate:

- the next meaningful proof requires field evidence
- the proposed slice widens scope beyond the wedge
- the slice needs many integrations before value appears
- the verifier lanes regress
- the matter model changes so much that the slice becomes bespoke

When a stop rule triggers, the cycle should record `stop because the next blocker is external` or `re-scope the slice`, not keep building optimistically.

## Internal Proof Sequence

The slices must be executed in this order unless the scoreboard records a documented re-scope:

### Slice 1: Scenario replay harness

Goal:

create a deterministic proof environment on top of the existing backbone.

Required shape:

- one source-system stub
- one downstream target stub
- one narrow clock configuration
- deterministic scenario replay for:
  - happy path
  - delay path
  - failure / retry path

Primary outcome:

the repo can replay the chosen matter repeatedly without pretending to be a full enterprise suite.

### Slice 2: Matter overview projection

Goal:

add the smallest projection that answers the operator's first-pass questions from one place.

Required answers:

- owner
- active clock
- blocker
- downstream state
- decision basis

Primary outcome:

Sentinel starts behaving like a matter workspace rather than only a durable messaging core.

### Slice 3: Matter timeline and path projection

Goal:

preserve causality, evidence, and operational path reasoning across replayed scenarios.

Primary outcome:

the repo can explain how the matter reached its current state without relying on raw internals alone.

### Slice 4: Queue and exception projection

Goal:

support internal sorting and triage across the proof matters.

Required views:

- missing owner
- active clock
- blocked downstream action
- missing evidence

Primary outcome:

the repo supports operational triage for the narrow wedge without broad workflow expansion.

## Completion Rule

The autonomous loop should treat the wedge as `ready-for-field` only when all of these are true:

- all four internal proof slices are green
- `product_proof` is `internally-proven`
- `productization_proof` is `internally-proven`
- `workflow_proof` is at least `ready-for-field`
- `buying_path_proof` is at least `ready-for-field`
- `build_vs_buy_proof` is at least `ready-for-field`

That is the handoff point to later field validation.

It is not yet the point where Sentinel's thesis is fully earned.
