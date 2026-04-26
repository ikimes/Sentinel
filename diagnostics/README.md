# Diagnostics Index

Diagnostics are grouped by the COEL phase model, and `phaseA` is the only supported live diagnostics structure.

## Foundation Verification

These are the trusted backbone verifier lanes for `Phase A`.

| Legacy path | New conceptual place | What it proves | Status |
|---|---|---|---|
| `diagnostics/phaseA/phase2/verify_backbone.sh` | `Foundation.A2 Correctness` | durable dispatch, ledger write, duplicate suppression, terminal failure basics | canonical |
| `diagnostics/phaseA/phase3/verify_phase3.sh` | `Foundation.A3 Resilience` | strict outage recovery, trace continuity, resilience proof | canonical |
| `diagnostics/phaseA/phase4/verify_phase4.sh` | `Foundation.A4 Operational Confidence` | bounded load, backlog recovery, terminal failure, stress/soak evidence | canonical |
| `diagnostics/phaseA/phase4/verify_db_restart.sh` | `Phase A companion recovery verifier` | PostgreSQL outage detection, restart recovery, and post-recovery request proof | canonical companion |
| `diagnostics/phaseA/phase4/smoke_recent_history.sh` | `Foundation.A4 read-seam smoke` | live `recent` and `history` read validation without backend changes | canonical companion |
| `diagnostics/phaseA/phase4/capture_operational_snapshot.sh` | `Phase A operational support` | live readiness and operational state capture | canonical support tool |

Phase 3 support tooling now writes canonically to:

- `diagnostics/phaseA/phase3/ab-isolation/`
- `diagnostics/phaseA/phase3/fact-bundles/`

Canonical artifact roots:

- `diagnostics/phaseA/phase2/evidence/`
- `diagnostics/phaseA/phase3/evidence/`
- `diagnostics/phaseA/phase3/ab-isolation/`
- `diagnostics/phaseA/phase3/fact-bundles/`
- `diagnostics/phaseA/phase4/evidence/`
- `diagnostics/phaseA/phase4/snapshots/`

The PostgreSQL restart companion verifier writes under:

- `diagnostics/phaseA/phase4/evidence/<utc-stamp>-db-restart/`

## Retention Policy

The diagnostics retention policy lives at:

- `diagnostics/retention-policy.md`

The repository currently keeps curated baseline files in place and intentionally omits generated evidence bundles, snapshots, and local run artifacts from Git.

## Hardening Diagnostics

This consolidation pass does not introduce a new `hardening` directory yet. Future `Phase B` diagnostics should be added under the `Phase B` conceptual model first, while preserving compatibility with current backbone tooling.

Current bridge until a dedicated `Phase B` diagnostics tree exists:

- PostgreSQL outage/restart verification lives at `diagnostics/phaseA/phase4/verify_db_restart.sh`

Expected future `Phase B` topics:
- migrations validation
- backup/restore drills
- alerting and SLI regression checks

## Historical Compatibility Diagnostics

| Path | Meaning | Status |
|---|---|---|
| `diagnostics/rabbit-compat/README.md` | historical transport compatibility and migration evidence | historical |

## Operational Note

- `diagnostics/phaseA/` is the sole supported diagnostics structure for the trusted backbone foundation.
