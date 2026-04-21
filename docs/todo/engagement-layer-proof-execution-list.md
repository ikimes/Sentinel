# Engagement-Layer Proof Execution List

## Purpose

This note converts the current earned-thesis plan into a sequenced execution list for Stage 4 internal product proof.

It does not include buyer outreach, pilot selling, or broad platform expansion.

It exists to guide the next repo-side work after the trusted backbone and UI-ready backend slices.

## Current Read

As of March 16, 2026, Sentinel's current repo baseline is:

- `Phase A` trusted backbone is implemented and verifier-backed
- the UI-ready backend slice is implemented
- the narrow wedge is documented in the pharma-control-plane vision package
- the locked matter now has deterministic replay, overview, timeline, and queue projections implemented in the repo
- the earned-thesis scoreboard can now mark `product_proof` and `productization_proof` as `internally-proven`
- `workflow_proof`, `buying_path_proof`, and `build_vs_buy_proof` remain capped at `ready-for-field`

That means the next repo-side leverage point is:

- the first `Blazor` matter workspace shell on top of the proven overview, timeline, queue, and context reads
- keeping the same locked matter contract and three deterministic replay scenarios while the UI is introduced

The selected recurring matter is now locked in:

- `docs/todo/stage4-matter-contract.md`

## Guardrails

- treat `docs/vision/pharma-control-plane/drafts/v2/earned-thesis-scoreboard.md` as the live state interface
- advance only one Stage 4 slice at a time
- keep the proof inside one source stub, one downstream stub, and configuration-backed clock logic
- do not expand into generic workflow, dashboarding, graph-first exploration, or demo-only polish
- treat `Phase A` verifier reruns as mandatory before and after any slice that changes repo-tracked implementation
- keep Phase C work on top of the already-green backbone and UI-ready backend rather than reopening backbone scope

## Likely Repo Touchpoints

The first Stage 4 slices should primarily build on:

- `Sentinel.Api/features/compliance/`
- `Sentinel.Api.Tests/`
- `Sentinel.Shared/`

Those areas already own the narrow read surfaces, persistence baseline, and integration coverage that the next proof slices should extend.

## Ordered Execution Checklist

### 1. Lock Stage 4 proof guardrails

- Treat `dotnet build Sentinel.sln` as mandatory before and after each slice.
- Treat `Sentinel.Api.Tests` as the first automated verification lane for each slice.
- Treat `diagnostics/phaseA/phase2/verify_backbone.sh`, `diagnostics/phaseA/phase3/verify_phase3.sh`, and `diagnostics/phaseA/phase4/verify_phase4.sh` as mandatory post-change verifier reruns.
- Require the scoreboard to identify exactly one current slice before implementation begins.

Done when:

- every future Stage 4 slice inherits the same build, test, and verifier gate
- the scoreboard and this execution list agree on the next slice to advance

### 2. Slice 1: Scenario replay harness

- Add a deterministic scenario runner for the `post-intake cross-market safety follow-up matter` locked in `docs/todo/stage4-matter-contract.md`.
- Implement one source-system stub that emits signal references and narrow updates.
- Implement one downstream target stub that reports `pending`, `acknowledged`, `failed`, or `not required`.
- Implement one narrow configuration-backed clock and obligation source for the chosen matter.
- Support at least three replayable scenarios:
  - happy path
  - delay path
  - failure / retry path

Done when:

- the repo can replay the same matter deterministically
- scenario outputs are written in human-answer terms, not only raw system state
- the harness stays narrow and does not pretend to model full enterprise suites

### 3. Slice 2: Matter overview projection

- Add the smallest projection or read model that answers:
  - current owner
  - active clock
  - blocker
  - downstream state
  - decision basis
- Keep the projection matter-first rather than request-first.
- Reuse the scenario harness as the primary truth source instead of adding broad new integrations.

Done when:

- one matter can be inspected from a single narrow overview
- the overview is more useful for the five operator questions than the current request-level read surfaces alone
- the slice does not require a generalized workflow engine

### 4. Slice 3: Matter timeline and path projection

- Add a projection that explains how the matter reached its current state.
- Preserve causality across signal intake, ownership changes, clock changes, decisions, evidence, and downstream actions.
- Keep the path view grounded in provenance-backed events, not inferred storytelling alone.

Done when:

- the current decision can be reconstructed from one inspectable thread
- a delay or retry scenario can be understood without reading raw system internals
- the slice improves understanding of blockers and operational causality rather than just adding visual complexity

### 5. Slice 4: Queue and exception projection

- Add a narrow queue or exception view for the proof matters.
- Support sorting or filtering by:
  - missing owner
  - active clock
  - blocked downstream action
  - missing evidence
- Keep the slice focused on proof-matter triage, not broad operational dashboards.

Done when:

- internal users can triage the proof matters from one narrow operational surface
- the queue exposes the most important exceptions without becoming a generic reporting layer
- the slice still fits the same narrow matter model

### 6. Scoreboard promotion gate

- After each slice, update the scoreboard using only the allowed decision states.
- Do not promote `workflow_proof`, `buying_path_proof`, or `build_vs_buy_proof` past `ready-for-field`.
- Promote `product_proof` only when the slice materially improves the five operator questions and verification remains green.
- Promote `productization_proof` only when repeated slice use shows the same matter model surviving without bespoke drift.
- End each slice with one written decision:
  - continue the current slice
  - re-scope the slice
  - stop because the next blocker is external

Done when:

- the scoreboard remains the single source of truth for current earned-thesis state
- each slice ends with one next action and one blocker classification

## Stage 4 Exit Criteria

The repo is ready for later field handoff when all of these are true:

- slice 1 through slice 4 are complete and verified
- `product_proof` is `internally-proven`
- `productization_proof` is `internally-proven`
- `workflow_proof` remains at least `ready-for-field`
- `buying_path_proof` remains at least `ready-for-field`
- `build_vs_buy_proof` remains at least `ready-for-field`

That is the point where Sentinel has an internally proven wedge implementation shape.

As of March 16, 2026, that internal proof boundary is met in the repo for the locked Stage 4 matter.

It is not yet the point where the thesis is fully earned in market.

## Deferred Beyond This List

The following remain intentionally deferred:

- real buyer interviews and sponsor discovery
- pilot-selling motion and budget validation
- broad multi-system integration programs
- generalized workflow engine behavior
- dashboard-first or graph-first category expansion
- broad Phase D experience work
