# Execution Guidance v3 (Compact)

Use this when implementing and validating changes.

## Goal
Deliver working end-to-end changes with deterministic verification.

## Modes
- `auto` (recommended): model chooses `light` or `default` at start, then can escalate on failure signals.
- `default`: reliability/backend, migrations, messaging, infra.
- `light`: low-risk docs/small edits with minimal ceremony.

## Auto Mode Policy
- Start in `light` only if task is low-risk (docs/copy/small non-runtime edits).
- Start in `default` for runtime behavior, infra, messaging, persistence, security, or migrations.
- Escalate `light -> default` immediately when any trigger appears:
  - build/test/runtime failure occurs,
  - same failure class repeats 2+ times,
  - 4+ total attempts are used without success,
  - scope expands beyond original low-risk intent.
- Once escalated, do not de-escalate within the same run.

## Startup Echo (Required)
- First line on every task run:
  - `active_mode=<light|default> gate=<strict|hybrid> reporting=<brief|exhaustive-on-fail> max_attempts=<n>`
- If `mode=auto`, include resolved mode in the same first line (`auto->light` or `auto->default`).
- On escalation, emit exactly one transition line:
  - `mode_transition=light->default reason=<trigger>`

## Execution Contract (Required)
Per attempt:
`baseline -> one focused change -> verify -> classify -> next action`

Autonomous troubleshooting loop (required for blocker-resolution runs):
`attempt -> verify -> classify -> evidence -> auto-replan -> next attempt`

Stop conditions:
- success on first full pass, or
- attempt cap reached, or
- same failure class repeats 3 times without new signal (force reclassification).

Isolation defaults (required for blocker-resolution runs):
- run compatibility precheck lane before deep runtime tuning.
- use lane budget matrix:
  - `control:3, broker:2, version:2, runtime:4, gate:3` (unless overridden).
- when same no-signal failure repeats 3 times, auto-switch lane.

Hang guard (required):
- if a live run produces no new check/log signal for `hang_guard_minutes`:
  - classify `fail:stalled-runner`,
  - terminate the attempt,
  - continue to next planned lane/action.

Approval behavior:
- continue autonomously after initial approval.
- pause only for true blockers:
  - missing access/credentials,
  - destructive action requiring explicit approval,
  - external issue/comment submission.

## Guardrails
- No destructive commands unless explicitly requested.
- No silent fallback that can hide strict/final-gate behavior.
- No skipping failed checks.

## Evidence Contract
- `default` mode:
  - capture evidence every attempt (pass/fail), include logs + DB/runtime proofs.
- `light` mode:
  - capture only minimal proof for success (build/test/output), escalate to full evidence if failure appears.
- `auto` mode:
  - follow active mode (`light` or `default`) and record mode transitions in the attempt ledger.

State labels (required in summary/decision outputs):
- `phase=<control|broker|version|runtime|gate>`
- `transition_reason=<why lane switched>`
- `terminal_rule=<local_fix_proven|upstream_repro|global_cap_exhausted|blocked>`

Winning lane promotion (required):
- after first strict one-shot pass:
  - run strict streak gate,
  - run Phase 2 regression,
  - run default-config validation,
  - only then mark `local_fix_proven`.

## Reporting Contract
- Success path: brief summary (what changed + proof + status).
- Failure/blocker path: exhaustive dump (attempt ledger, evidence paths, root-cause classification, next lane).

## Failure Classes (minimum)
- `fail:startup`
- `fail:build`
- `fail:functional`
- `fail:verification`
- `fail:unknown`
