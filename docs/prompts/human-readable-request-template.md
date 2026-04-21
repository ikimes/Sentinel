## Global 30-attempt loop (no mid-lane approvals)

Use this prompt:

```text
Use SPPv3. mode=auto gate=strict max_attempts=30 approval=blockers-only. Task: <your task>
```

What this means in practice:

- I run continuously through re-plan/execute loops up to 30 failed attempts.
- I do not stop for approval between lanes.
- I only pause for true blockers:
  - missing credentials/access,
  - destructive action requiring explicit consent,
  - external submission action (issue/comment/publish).
- I end with one of:
  - `local_fix_proven`
  - `upstream_repro`
  - `global_cap_exhausted`
  - `blocked`
- Final output includes evidence paths.
