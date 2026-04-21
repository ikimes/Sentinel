# Sentinel v2 Earned Thesis Scoreboard

Status: `live state interface`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Related notes:

- `docs/vision/pharma-control-plane/drafts/v2/autonomous-earned-thesis-operating-system.md`
- `docs/vision/pharma-control-plane/drafts/v2/earned-thesis-plan.md`
- `docs/todo/engagement-layer-proof-execution-list.md`

## Purpose

This file is the stable state interface for future autonomous earned-thesis cycles.

Future cycles should update this file rather than inventing new status language.

## Fixed Rules

- use only these proof areas:
  - `workflow_proof`
  - `buying_path_proof`
  - `build_vs_buy_proof`
  - `product_proof`
  - `productization_proof`
- use only these status values:
  - `blocked`
  - `ready-for-field`
  - `internally-proven`
  - `earned`
- every proof area must always contain the same fixed fields:
  - `status`
  - `evidence`
  - `unknowns`
  - `next_internal_action`
  - `external_dependency`
- in internal-only mode:
  - `workflow_proof`, `buying_path_proof`, and `build_vs_buy_proof` must not move past `ready-for-field`
  - only `product_proof` and `productization_proof` may become `internally-proven`

## Current Cycle Record

- `cycle_date`: `2026-03-16`
- `current_slice`: `s3_1_blazor_matter_workspace_shell`
- `written_decision`: `continue the current slice by consuming the internally-proven Stage 4 read model in the first Blazor workspace shell`
- `next_action`: `implement S3.1 as the first Blazor matter workspace shell for matter, queue, timeline, and context while keeping the locked matter contract and the three deterministic replay scenarios unchanged`
- `blocker_classification`: `internal repo-side proof still available for UI consumption; workflow, buying-path, and build-vs-buy blockers remain field-only`

## workflow_proof

- `status`: `ready-for-field`
- `evidence`:
  - `docs/vision/pharma-control-plane/current/v1/vision.md`
  - `docs/vision/pharma-control-plane/current/v1/design-partner-discovery-guide.md`
  - `docs/vision/pharma-control-plane/drafts/v2/qualification-boundary-memo.md`
- `unknowns`:
  - actual recurrence frequency inside real prospects
  - actual leadership visibility of the chosen matter
  - whether real accounts describe the same matter type with enough consistency
- `next_internal_action`:
  - keep the Stage 4 proof build anchored to the same recurring matter definition and reject slices that broaden the workflow
- `external_dependency`:
  - design-partner discovery conversations are still required before this proof can move beyond `ready-for-field`

## buying_path_proof

- `status`: `ready-for-field`
- `evidence`:
  - `docs/vision/pharma-control-plane/drafts/v2/overlay-buying-path.md`
  - `docs/vision/pharma-control-plane/drafts/v2/overlay-buying-path-interview-rubric.md`
  - `docs/vision/pharma-control-plane/drafts/v2/executive-readout.md`
- `unknowns`:
  - named sponsor archetype with real pilot authority
  - credible budget source for a narrow overlay
  - real approval path beside incumbent systems
- `next_internal_action`:
  - preserve the overlay framing in all proof artifacts and do not let internal slices drift toward suite replacement
- `external_dependency`:
  - real buyer conversations are required before this proof can move beyond `ready-for-field`

## build_vs_buy_proof

- `status`: `ready-for-field`
- `evidence`:
  - `docs/vision/pharma-control-plane/current/v1/build-vs-buy-teardown.md`
  - `docs/vision/pharma-control-plane/drafts/v2/internal-build-comparison-scorecard.md`
  - `docs/vision/pharma-control-plane/current/v1/competitive-positioning-comparison.md`
- `unknowns`:
  - whether a strong prospect would actually prefer Sentinel over internal build
  - where internal build looks proportionate versus where it drifts into stitched local solutions
  - whether Sentinel's workspace feels distinct enough in field use
- `next_internal_action`:
  - make each Stage 4 slice improve coherence, repeatability, and time-to-proof rather than feature breadth
- `external_dependency`:
  - prospect scoring and direct buy-versus-build conversations are still required before this proof can move beyond `ready-for-field`

## product_proof

- `status`: `internally-proven`
- `evidence`:
  - `readme.md`
  - `docs/product/compliance-orchstration-engagement-layer-mvp.md`
  - `docs/todo/stage4-matter-contract.md`
  - `Sentinel.Api/features/compliance/ComplianceMatterReplayHarness.cs`
  - `Sentinel.Api/features/compliance/Contracts.cs`
  - `Sentinel.Api/features/compliance/ComplianceServices.cs`
  - `Sentinel.Api/features/compliance/CheckText.cs`
  - `Sentinel.Api.Tests/ComplianceMatterReplayHarnessTests.cs`
  - `Sentinel.Api.Tests/ComplianceApiTests.cs`
- `unknowns`:
  - whether the same operator-answer framing remains compelling once it is consumed in the first Blazor workspace shell
  - whether operators need additional context layering beyond overview, timeline, and queue for live usage
  - whether the locked matter still feels like the highest-value wedge once field exposure begins
- `next_internal_action`:
  - consume the same overview, timeline, queue, and context surfaces in `S3.1` without widening the locked matter model
- `external_dependency`:
  - field validation is still required before this proof can move beyond `internally-proven`

## productization_proof

- `status`: `internally-proven`
- `evidence`:
  - `docs/todo/stage4-matter-contract.md`
  - `docs/todo/engagement-layer-proof-execution-list.md`
  - `Sentinel.Api/features/compliance/ComplianceMatterReplayHarness.cs`
  - `Sentinel.Api/features/compliance/Contracts.cs`
  - `Sentinel.Api/features/compliance/ComplianceServices.cs`
  - `Sentinel.Api.Tests/ComplianceMatterReplayHarnessTests.cs`
  - `Sentinel.Api.Tests/ComplianceApiTests.cs`
- `unknowns`:
  - whether the same matter-first contract stays clean when rendered in the first Blazor workspace shell
  - whether a second proof matter can reuse the same seams without widening integration breadth
  - whether later field packaging keeps the current overlay shape without drift toward suite replacement
- `next_internal_action`:
  - implement `S3.1` on top of the same matter contract and read surfaces before considering any additional proof matter
- `external_dependency`:
  - real field adoption evidence is still required before this proof can move beyond `internally-proven`
