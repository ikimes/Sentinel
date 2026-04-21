# Sentinel Pharma Control Plane v2 Narrowing Phase

Status: `active draft - first full three-pass cycle complete`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Discovery baseline:

- `docs/vision/pharma-control-plane/current/v1/`

## Purpose

`v2` is a strategic narrowing phase built on top of the endorsed `v1` discovery baseline.

It is not a restart.

It exists to answer three narrower questions:

- what Sentinel should copy
- what Sentinel should avoid
- what Sentinel still must uniquely prove

## Working Order

Every pass should use the same order:

1. `copy`
2. `avoid`
3. `uniquely prove`

## Pass Method

Each axis file must contain three passes:

### Pass 1: Wide-Range Initial Pass

- pull a broad set of candidates from `current/v1/`
- include strong candidates, weaker candidates, tensions, and contradictions
- do not narrow too early

### Pass 2: Narrow-Hardening Pass

- reduce to a smaller set of stronger positions
- explicitly use what was learned from the other two axes' pass-1 outputs
- allow at most one materially new answer if it is better supported than the inherited `v1` set
- pressure-test against:
  - the strong hypothetical partner
  - the weak hypothetical partner
  - the current doctrine
  - the overlay boundary

### Pass 3: Final Narrow-Hardening Pass

- reduce each axis to final strategic rules
- each final item must answer:
  - why it survives
  - what evidence supports it
  - what failure mode it prevents
- this pass exists to prepare `synthesis.md`

## Evidence Hierarchy

- primary: all `current/v1/` artifacts
- secondary: targeted official-source refreshes only if a real gap appears
- tertiary: analog and adjacent-market material already documented in `v1`

## v2 Files

- `docs/vision/pharma-control-plane/drafts/v2/copy.md`
- `docs/vision/pharma-control-plane/drafts/v2/avoid.md`
- `docs/vision/pharma-control-plane/drafts/v2/uniquely-prove.md`
- `docs/vision/pharma-control-plane/drafts/v2/synthesis.md`
- `docs/vision/pharma-control-plane/drafts/v2/executive-readout.md`
- `docs/vision/pharma-control-plane/drafts/v2/earned-thesis-plan.md`
- `docs/vision/pharma-control-plane/drafts/v2/autonomous-earned-thesis-operating-system.md`
- `docs/vision/pharma-control-plane/drafts/v2/earned-thesis-scoreboard.md`
- `docs/vision/pharma-control-plane/drafts/v2/overlay-buying-path.md`
- `docs/vision/pharma-control-plane/drafts/v2/internal-build-superiority.md`
- `docs/vision/pharma-control-plane/drafts/v2/overlay-buying-path-interview-rubric.md`
- `docs/vision/pharma-control-plane/drafts/v2/internal-build-comparison-scorecard.md`
- `docs/vision/pharma-control-plane/drafts/v2/partner-a-tool-dry-run.md`
- `docs/vision/pharma-control-plane/drafts/v2/partner-b-tool-dry-run.md`
- `docs/vision/pharma-control-plane/drafts/v2/qualification-boundary-memo.md`

## Completion Criteria

`v2` is complete only when:

- all three axis files contain all three passes
- the final axis outputs are narrower than `v1`
- the final outputs are non-overlapping
- `synthesis.md` is short enough to become the default strategic reference for future work
