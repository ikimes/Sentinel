# Pharma Control Plane Vision Package

This package is the canonical home for Sentinel's pharma-first compliance control-plane vision work.

## Status

| Field | Value |
|---|---|
| package purpose | define the product wedge, target-customer lens, and conceptual system design for Sentinel beyond the current trusted backbone |
| primary audience | investor/product leadership, with enough precision for engineering follow-on |
| current wedge | `PV-first` |
| current canonical version | `v1` |
| active draft | `v2` |
| current v2 phase | `first full three-pass narrowing cycle complete; ready for iteration` |
| stable package link | `docs/vision/pharma-control-plane/README.md` |

## Package Links

- current v1 discovery baseline:
  - `docs/vision/pharma-control-plane/current/v1/vision.md`
- current v1 system design:
  - `docs/vision/pharma-control-plane/current/v1/system-design.md`
- current v1 frontend decision:
  - `docs/vision/pharma-control-plane/current/v1/frontend-decision.md`
- current v1 discovery wrap and strategic thesis:
  - `docs/vision/pharma-control-plane/current/v1/v1-discovery-wrap-and-strategic-thesis.md`
- current v1 supporting corpus:
  - `docs/vision/pharma-control-plane/current/v1/`
- active v2 package README:
  - `docs/vision/pharma-control-plane/drafts/v2/README.md`
- active v2 copy axis:
  - `docs/vision/pharma-control-plane/drafts/v2/copy.md`
- active v2 avoid axis:
  - `docs/vision/pharma-control-plane/drafts/v2/avoid.md`
- active v2 uniquely-prove axis:
  - `docs/vision/pharma-control-plane/drafts/v2/uniquely-prove.md`
- active v2 synthesis:
  - `docs/vision/pharma-control-plane/drafts/v2/synthesis.md`
- active v2 executive readout:
  - `docs/vision/pharma-control-plane/drafts/v2/executive-readout.md`
- active v2 earned thesis plan:
  - `docs/vision/pharma-control-plane/drafts/v2/earned-thesis-plan.md`
- active v2 autonomous earned-thesis operating system:
  - `docs/vision/pharma-control-plane/drafts/v2/autonomous-earned-thesis-operating-system.md`
- active v2 earned thesis scoreboard:
  - `docs/vision/pharma-control-plane/drafts/v2/earned-thesis-scoreboard.md`
- active v2 overlay buying-path workstream:
  - `docs/vision/pharma-control-plane/drafts/v2/overlay-buying-path.md`
- active v2 internal-build-superiority workstream:
  - `docs/vision/pharma-control-plane/drafts/v2/internal-build-superiority.md`
- active v2 overlay buying-path interview rubric:
  - `docs/vision/pharma-control-plane/drafts/v2/overlay-buying-path-interview-rubric.md`
- active v2 internal-build comparison scorecard:
  - `docs/vision/pharma-control-plane/drafts/v2/internal-build-comparison-scorecard.md`
- active v2 Partner A tool dry run:
  - `docs/vision/pharma-control-plane/drafts/v2/partner-a-tool-dry-run.md`
- active v2 Partner B tool dry run:
  - `docs/vision/pharma-control-plane/drafts/v2/partner-b-tool-dry-run.md`
- active v2 qualification boundary memo:
  - `docs/vision/pharma-control-plane/drafts/v2/qualification-boundary-memo.md`
- canonical slot:
  - `docs/vision/pharma-control-plane/current/v1/`
- archive index:
  - `docs/vision/pharma-control-plane/archive/README.md`

## Draft Versions In Progress

| Version | Focus | Status |
|---|---|---|
| `v2` | strategic narrowing across what Sentinel should copy, avoid, and uniquely prove | `active draft` |

## Current Iteration Mode

`current/v1/` is now the endorsed discovery baseline for this package.

That means `drafts/v2/` should build from the wrapped `v1` corpus rather than reopening the whole discovery story by default.

The current v2 priorities are:

- what Sentinel should copy
- what Sentinel should avoid
- what Sentinel still must uniquely prove
- producing a final synthesis that can guide buyer validation, MVP proof, and implementation planning

## Archived Versions

No archived canonical versions exist yet.

Future archived versions will be listed here after a draft is promoted into `current/` and later superseded.

## Iteration and Promotion Rules

1. Create or revise content in `drafts/vN/`.
2. Keep drafts editable until terminology, diagrams, and package structure are stable.
3. Promote the approved draft into `current/vN/`.
4. Move the previously canonical `current/vN-1/` into `archive/vN-1/`.
5. Update this package index and `docs/vision/README.md` so only one canonical version is active.

## Canonicality Rules

- Only one canonical version may exist at a time.
- Roadmap and top-level docs should link to this package `README.md` or the endorsed `current/vN/`, never to a draft path as the stable target.
- Archived versions are frozen except for trivial typo or broken-link repair.
- Drafts may be rewritten freely.
- Do not overwrite archived versions to create the next draft.

## Version Rules

- Use major-only version labels: `v1`, `v2`, `v3`.
- Start a new major version when the product story, wedge, package structure, or conceptual system framing changes materially.
- Keep small wording fixes within the active draft version until promotion.
