# Plan Guidance v3 (Compact)

Use this when the task needs planning before implementation.

Priority order: `safety > correctness > speed`.

## Planning Rules
- Execution model: autonomous.
- Ask questions only for true blockers (missing access, unresolved product decision, external dependency unknown).
- No plan-only stall after plan is decision-complete.
- Honor startup echo contract from `docs/prompts/request-template.md`.

## Required Planning Checklist
Run 3 passes and report each as: `Findings`, `Improvements`, `Go/No-Go`.
1. Completeness/Feasibility
2. Architecture/Clean Code
3. Reliability/Testability/Ops Safety

If any pass is `No-Go`, revise before execution.

## Decision Locking (Required)
For any unresolved option, lock a default with:
- `default`
- `rationale`
- `override_condition`

No open decisions remain in final plan.

## Risk Gate (Required)
- `risk_level`: `low|medium|high`
- `blast_radius`
- `rollback_strategy`
- `verification_depth`:
  - `low`: targeted checks + build
  - `medium`: build + integration + regression checks
  - `high`: full integration/e2e + failure injection + rerun proof

## Output Contract
Use this structure:
1. Summary
2. Implementation Changes
3. Decision Locks
4. Risk Gate Matrix
5. Test Cases/Scenarios
6. Public APIs/Interfaces/Types
7. Assumptions/Defaults

For autonomous loop plans (required fields):
- lane order,
- lane switch criteria,
- per-lane cap,
- global cap,
- terminal decision rule.
- compatibility precheck lane and exit criteria.
- hang-guard threshold and `fail:stalled-runner` handling.
- state-label contract: `phase`, `transition_reason`, `terminal_rule`.
- winning-lane promotion sequence:
  - strict streak,
  - Phase 2 regression,
  - default-config validation.

## Reporting Behavior
- On expected success path: keep plan and status output concise.
- On blockers/failures: provide exhaustive diagnostics and decision branches.

## Reference Anchors
- MassTransit outbox: <https://masstransit.io/documentation/patterns/transactional-outbox>
- MassTransit retry/exceptions: <https://masstransit.io/documentation/concepts/exceptions>
- RabbitMQ reliability: <https://www.rabbitmq.com/docs/reliability>
- Aspire orchestration: <https://learn.microsoft.com/en-us/dotnet/aspire/fundamentals/orchestrate-resources>
- EF EnsureCreated caveat: <https://learn.microsoft.com/en-us/ef/core/managing-schemas/ensure-created>
