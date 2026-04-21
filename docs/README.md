# Sentinel Docs

This directory is organized around the current COEL lifecycle model:

- `Phase A: Trusted Backbone Foundation`
- `Phase B: Production Hardening`
- `Phase C: Engagement Layer MVP`
- `Phase D: Expanded COEL Experience`

Historical references may still mention `Phase 2`, `Phase 3`, and `Phase 4`, but the live diagnostics structure is now entirely under `diagnostics/phaseA/`.

## Start Here

| Need | Canonical doc |
|---|---|
| Understand the current project phase model | `docs/product/compliance-orchstration-engagement-layer-mvp.md` |
| Understand the trusted backbone runtime flow | `docs/architecture/compliance-messaging-pattern.md` |
| Understand the canonical Phase A diagnostics layout | `diagnostics/phaseA/README.md` |
| Browse the active product/roadmap docs | `docs/product/README.md` |
| Browse the implementation/runtime docs | `docs/architecture/README.md` |
| Explore versioned product vision packages | `docs/vision/README.md` |
| Explore frontend direction and future engagement work | `docs/product/coel-frontend-considerations.md` |
| Review supporting reference material | `docs/reference/README.md` |

## Secondary Material

These directories are retained for traceability and local workflow support, but they are not the recommended starting point for a first review of the repo:

- `docs/todo/`
  - active execution notes and implementation artifacts
- `docs/archive/`
  - retained historical analysis and completed refinement notes
- `docs/prompts/`
  - local prompt templates and execution guidance used during project development

## Structure

- `docs/architecture/`
  - runtime, messaging, and implementation-facing system docs
- `docs/product/`
  - roadmap, phase model, and engagement-layer/product direction
- `docs/reference/`
  - supporting guidance and secondary reference material
- `docs/prompts/`
  - local prompt templates and execution guidance
- `docs/todo/`
  - active execution and planning artifacts retained as working history
- `docs/archive/`
  - historical working notes retained for traceability
- `docs/vision/`
  - versioned product vision packages

## Compatibility Mapping

| Old name/path | New conceptual place | Status |
|---|---|---|
| `diagnostics/phaseA/phase2` | `Phase A / Foundation.A2 Correctness` | canonical verifier lane |
| `diagnostics/phaseA/phase3` | `Phase A / Foundation.A3 Resilience` | canonical verifier lane |
| `diagnostics/phaseA/phase4` | `Phase A / Foundation.A4 Operational Confidence` | canonical verifier lane |
| `Phase 2` | `Phase A / Foundation.A2 Correctness` | legacy name |
| `Phase 3` | `Phase A / Foundation.A3 Resilience` | legacy name |
| `Phase 4` | `Phase A / Foundation.A4 Operational Confidence` | legacy name |
| `diagnostics/rabbit-compat` | historical transport migration evidence | historical |

## Extensibility Rules

- Add future backbone-proof or hardening docs under the new `Phase A` / `Phase B` conceptual model first.
- Keep future versioned product-vision packages under `docs/vision/`.
- Keep future verifier and support tooling under `diagnostics/phaseA/` unless a new top-level phase structure is intentionally introduced.
- Treat this docs index as the narrative entrypoint for future builders and reviewers.
