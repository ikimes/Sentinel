# Phase A Diagnostics

`diagnostics/phaseA/` is the canonical home for the trusted backbone foundation verifier lanes.

Canonical paths:

- `diagnostics/phaseA/phase2/`
- `diagnostics/phaseA/phase3/`
- `diagnostics/phaseA/phase4/`

Companion recovery verifier:

- `diagnostics/phaseA/phase4/verify_db_restart.sh`

Phase 4 also includes a narrow live read smoke:

- `diagnostics/phaseA/phase4/smoke_recent_history.sh`

Canonical Phase 3 support outputs now also live under:

- `diagnostics/phaseA/phase3/ab-isolation/`
- `diagnostics/phaseA/phase3/fact-bundles/`

Canonical artifact output now lives under `phaseA`:

- `diagnostics/phaseA/phase2/evidence/`
- `diagnostics/phaseA/phase3/evidence/`
- `diagnostics/phaseA/phase4/evidence/`
- `diagnostics/phaseA/phase4/snapshots/`

PostgreSQL restart verifier runs write to:

- `diagnostics/phaseA/phase4/evidence/<utc-stamp>-db-restart/`

Phase 3 support and investigation bundles are now split intentionally:

- new runs from `collect_phase3_facts.sh` write to `diagnostics/phaseA/phase3/fact-bundles/`
- new runs from `run_ab_isolation.sh` write to `diagnostics/phaseA/phase3/ab-isolation/`
- historical Phase 3 support bundles now also live under `diagnostics/phaseA/phase3/`

Retention policy:

- `diagnostics/retention-policy.md`
