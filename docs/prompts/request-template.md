# Request Templates v3 (Compact)

## Shorthand (recommended)

Use Sentinel prompt pack v3. Task: `<request>`
Use SPPv3. Task: `<request>`
Full User Example: `Use SPPv3. mode=auto gate=strict max_attempts=30 approval=blockers-only. Task: <your task>`

Optional toggles:
- `mode=auto|default|light`
- `gate=strict|hybrid`
- `max_attempts=<n>`
- `risk=low|medium|high`
- `approval=blockers-only`
- `hang_guard_minutes=<n>`
- `lane_budget=<control:3,broker:2,version:2,runtime:4,gate:3>`

Defaults (source of truth):
- `mode=auto`
- `gate=strict`
- `max_attempts=30`
- `risk=medium`
- `approval=blockers-only`
- `hang_guard_minutes=5`
- `lane_budget=control:3,broker:2,version:2,runtime:4,gate:3`

Output preference defaults:
- success: brief
- failure/blocker: exhaustive

Autonomous loop defaults:
- `max_attempts` is a global cap across replans/lanes in blocker-resolution runs.
- run a compatibility precheck lane before deep runtime tuning.
- enforce hang guard: if no new signal for `hang_guard_minutes`, classify `fail:stalled-runner`, kill, and continue.
- include state labels in summaries: `phase`, `transition_reason`, `terminal_rule`.
- when a lane first passes strict one-shot, auto-promote to:
  - strict streak gate,
  - Phase 2 regression,
  - default-config validation.
- continue without additional approval unless blocked by:
  - missing credentials/access,
  - destructive operation requiring explicit user consent,
  - external submission/publish action.

Required startup echo (first line of task run):
- `active_mode=<light|default> gate=<strict|hybrid> reporting=<brief|exhaustive-on-fail> max_attempts=<n>`
- If `mode=auto`, show resolved mode in the first line (`auto->light` or `auto->default`).
- On escalation, emit one transition line:
  - `mode_transition=light->default reason=<trigger>`

## Explicit fallback (file-reference)

Reference these files for this request:
- `docs/prompts/plan-guidance.md`
- `docs/prompts/execution-guidance.md`

Use defaults from this file's "Defaults (source of truth)" block.

Auto-mode note:
- `mode=auto` lets the model choose `light` or `default` and auto-escalate to `default` if failures/retries indicate higher complexity.

Here is my request:
`<describe task, constraints, and desired outcome>`
