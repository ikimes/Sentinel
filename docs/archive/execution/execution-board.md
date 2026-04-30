# Sentinel Execution Board

Last updated: 2026-03-17

## Purpose

This board is the shared coordination layer for multi-window Codex execution.

All workers must treat this file as the current source of truth for:

- active slices
- ownership
- dependencies
- merge order
- what can run in parallel

## Global Rules

- Every worker runs exactly one slice.
- Every worker uses a separate branch, and ideally a separate git worktree.
- No worker should edit files outside its allowed cluster.
- All backend repo-tracked changes must pass:
  - `dotnet build Sentinel.sln`
  - `dotnet test Sentinel.sln`
- Any backend implementation change should also rerun:
  - `diagnostics/phaseA/phase2/verify_backbone.sh`
  - `diagnostics/phaseA/phase3/verify_phase3.sh`
  - `diagnostics/phaseA/phase4/verify_phase4.sh`
- Workers must stop and hand back control if they need to edit a file outside their allowed set.

## Canonical Read Set For Fresh Windows

Read only these before reading the slice packet:

- `readme.md`
- `docs/product/compliance-orchstration-engagement-layer-mvp.md`
- this file
- the assigned packet under `docs/todo/packets/`

## Status Values

Use only:

- `backlog`
- `active`
- `blocked`
- `ready for review`
- `done`

## File Ownership Clusters

### Test cluster

Owned files:

- `Sentinel.Api.Tests/*`

### Diagnostics cluster

Owned files:

- `diagnostics/phaseA/*`
- `diagnostics/README.md`
- `diagnostics/phaseA/README.md`

### Product-docs cluster

Owned files:

- `docs/todo/*`
- `docs/vision/*`

### Stage 4 code cluster

Owned files:

- `Sentinel.Api/features/compliance/*`
- `Sentinel.Shared/*`

## Active Board

| Slice | Status | Depends on | Cluster | Can run now | Notes |
|---|---|---|---|---|---|
| `S0.1` | `backlog` | none | product-docs | yes | optional baseline status note |
| `S1.1` | `done` | none | test | n/a | legacy schema adoption test merged into `Sentinel.Api.Tests` and verified green |
| `S1.2` | `done` | none | diagnostics | n/a | db outage/restart verifier and docs merged |
| `S1.3` | `done` | none | diagnostics | n/a | recent/history live smoke and docs merged |
| `S2.1` | `done` | none | product-docs | n/a | Stage 4 matter contract locked in `docs/todo/stage4-matter-contract.md` |
| `S1.4` | `done` | `S1.1` preferred | test | n/a | API edge-case coverage merged for unknown request, failed terminal status, and duplicate-dispatch deduplication |
| `S1.5` | `done` | `S1.1` preferred | test | n/a | pure-logic coverage merged for status mapping, actor normalization, and read projection helpers |
| `S1.6` | `done` | `S1.1` required | stage4/docs | n/a | migration-first bootstrap default clarified; `auto` and `ensurecreated` retained as explicit compatibility modes |
| `S2.2` | `done` | `S2.1` | stage4 | n/a | deterministic replay harness for the three locked Germany affiliate matter scenarios merged and test-covered |
| `S2.3` | `done` | `S2.2` | stage4 | n/a | matter overview endpoint merged with replay-backed operator projection and 404 handling for unsupported scenarios |
| `S2.4` | `done` | `S2.3` | stage4 | n/a | matter timeline endpoint merged with replay-backed causal path projection and 404 handling for unsupported scenarios |
| `S2.5` | `done` | `S2.3` | stage4 | n/a | queue and exception projection merged with replay-backed triage reads and focused API coverage; worktree verifier-path mismatch treated as setup drift rather than code failure |
| `S2.6` | `done` | `S2.2`-`S2.5` | product-docs | n/a | scoreboard refreshed; `product_proof` and `productization_proof` promoted to `internally-proven`; Stage 4 proof checkpoint written |
| `S3.1` | `done` | `S2.3`, ideally `S2.5` | frontend | n/a | Blazor shell added in `Sentinel.Web`; queue loads first, selects deterministically, and renders workspace, timeline, and deterministic context from existing matter endpoints |
| `S3.2` | `done` | `S3.1` | backend/ui | n/a | UI-side internal actor provider and API-side actor resolver now wrap the trusted header model without changing persisted actor fields |
| `S3.3` | `done` | `S3.2` | frontend | n/a | Blazor shell refined for operator comprehension: hero grounding, decision-oriented queue lenses, clearer selected state, less-congested matter hierarchy, operator brief rename, and human-readable timeline times |
| `S3.3b` | `done` | `S3.3` | frontend | n/a | second semantic pass merged in the shell: scenario-faithful queue signals, operator-facing surfaced reasons, clearer selected-state differentiation, and settled-vs-active trust cues before styling |
| `S3.4` | `done` | `S3.3b` | frontend | n/a | styling-system pass merged in `Sentinel.Web` with tokenized light/dark themes, an in-shell display toggle, restrained semantic accents, and verified desktop/mobile readability |

## First Parallel Wave

Recommended branches or worktrees:

- `codex/s1-1-legacy-schema-test`
- `codex/s1-2-db-outage-verifier`
- `codex/s1-3-recent-history-smoke`
- `codex/s2-1-matter-contract`

Recommended assignment:

- Worker 1: `S1.1`
- Worker 2: `S1.2`
- Worker 3: `S1.3`
- Worker 4: `S2.1`

Current state:

- merged into `codex/main`
- validated with `dotnet test Sentinel.Api.Tests/Sentinel.Api.Tests.csproj`

## Merge Order

Merge in this order unless a blocker changes it:

1. `S2.1`
2. `S1.1`
3. `S1.2`
4. `S1.3`

Then start:

5. `S1.4`
6. `S1.5`
7. `S1.6`
8. `S2.2`

After `S2.2`, keep `S2.3` to `S2.5` mostly sequential with one primary owner.

## Next Recommended Wave

- `S3.3b`

Recommended branch or worktree for this wave:

- `codex/s3-3b-semantic-clarity-pass`

Coordination notes:

- `S2.6` closed the Stage 4 proof-docs slice and recorded the internal-proof checkpoint
- `S3.2` is merged; the temporary trusted-header model is now wrapped behind a UI-side provider and API-side resolver seam
- `S3.3` should stay tightly focused on meaning, hierarchy, and in-product comprehension before any broader styling or capability work
- `S3.3b` exists to resolve the remaining semantic trust issues before visual polish
- `S3.4` should treat light/dark mode as a hard requirement and build on the content decisions from `S3.3`

## Worker Close-Out Format

Every worker must return:

- slice id
- branch name
- summary of changes
- files touched
- verification run
- blocker or risk
- recommended next slice
