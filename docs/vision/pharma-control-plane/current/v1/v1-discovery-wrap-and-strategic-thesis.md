# Sentinel v1 Discovery Wrap and Strategic Thesis

Status: `draft v1 wrap memo`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Related notes:

- `docs/vision/pharma-control-plane/current/v1/vision.md`
- `docs/vision/pharma-control-plane/current/v1/system-design.md`
- `docs/vision/pharma-control-plane/current/v1/beliefs-doubts-and-must-prove-next.md`
- `docs/vision/pharma-control-plane/current/v1/product-doctrine-options.md`
- `docs/vision/pharma-control-plane/current/v1/competitive-positioning-comparison.md`
- `docs/vision/pharma-control-plane/current/v1/hypothetical-design-partner-assessment.md`
- `docs/vision/pharma-control-plane/current/v1/hypothetical-design-partner-assessment-weaker.md`

## Purpose

This memo closes the `v1` discovery session.

It does not claim that Sentinel is fully validated.

It records what the project now believes strongly enough to carry forward, what still remains unearned, and what the next phase should test directly.

## What v1 Accomplished

The `v1` discovery session moved Sentinel from:

- a broad compliance-platform ambition

to:

- a narrower, more credible product wedge
- a clearer product doctrine
- a clearer operator experience
- a more honest picture of where the idea should and should not work

The most important improvement is that Sentinel now has a product identity, not only a technical backbone and a problem statement.

## v1 Strategic Thesis

The strongest current strategic thesis is:

Sentinel is an evidence-grade matter workspace for cross-system regulated follow-up.

More concretely:

- Sentinel does not replace the source systems
- Sentinel becomes valuable when no single system owns the governed thread cleanly
- Sentinel helps operators understand and work one matter across systems by making ownership, clocks, blockers, downstream state, and decision basis visible
- Sentinel must preserve provenance and evidence strongly enough to be inspection-ready, not merely convenient

## What Now Feels Settled Enough

These points look strong enough to carry into the next phase without reopening the whole story:

### 1. The wedge should remain narrow

The first serious wedge is:

`post-intake cross-market safety follow-up matter`

This is stronger than broader stories about PV modernization or compliance control planes in the abstract.

### 2. Sentinel should remain an overlay

Sentinel is not trying to become:

- the safety suite
- the source system of record
- the authority gateway
- the generic workflow platform
- the dashboard layer

The overlay boundary is one of the healthiest parts of the current strategy.

### 3. The product center should be a workspace, not only a backend

The UI work showed that the product becomes much more coherent when it is understood as a daily operator surface rather than as invisible orchestration plumbing.

### 4. The architecture should stay light and matter-centered

The core model should stay anchored on:

- `ComplianceMatter`
- `Obligation`
- `ReportingClock`
- `Decision`
- `EvidenceArtifact`
- `Transmission`
- `TimelineEvent`

This is enough for the first proof if it remains stable.

### 5. The first proof should be narrow and minimally integrated

One source system, one downstream target, one recurring matter type, and a replayable scenario pack is enough to prove whether Sentinel changes the workflow materially.

## What Still Looks Open

These questions remain unresolved after `v1` and should now be treated as the main uncertainty set:

### 1. Economic buyer

The likely user sponsor is visible.

The durable budget owner is still not clear enough.

### 2. Demand density

The chosen matter type is plausible and strategically clean.

It is not yet proven frequent and painful enough to force buying behavior.

### 3. Build-vs-buy advantage

The product is more distinct than before, but it still must prove why a buyer should purchase Sentinel instead of extending its current stack.

### 4. Stable model versus services drift

The core primitives look promising.

They are not yet proven robust enough across repeated real examples.

### 5. Entry urgency

The product is more compelling now.

It is not yet proven urgent.

## What v1 Disproved or Weakened

The discovery session meaningfully weakened several earlier instincts:

- broad control-plane language as the main entry story
- AI as the primary wedge
- graph view as the main UI
- the idea that visibility alone is enough
- the idea that Sentinel should try to prove the whole future company at once

Those are useful negative learnings.

## Strongest Current Product Doctrine

The strongest current doctrine is:

Sentinel should behave like a governed matter workspace, be architected like a coordination-state layer, and be sold first like an evidence-grade exception control surface only when that helps the buying motion.

In simpler terms:

- user-facing identity: `workspace`
- technical center: `coordination-state layer`
- near-term commercial packaging: `evidence-grade control surface`

## What Good v2 Work Should Look Like

The next phase should not reopen `v1` from scratch.

It should pressure-test and productize it.

The most valuable next work would be:

- real buyer validation
- first-proof workflow execution planning
- MVP harness and scenario implementation
- qualification criteria for real prospects
- more explicit go / no-go thresholds

## Practical Decision Rule

Treat `v1` as a completed discovery package if all of these feel true:

- the product story is coherent enough to explain in one sentence
- the first workflow is narrow enough to implement without reopening strategy
- the team knows what Sentinel is not
- the main remaining questions are commercial and executional rather than conceptual

That appears to be true now.

## Closing Read

`v1` should be considered a successful discovery session.

Not because it proved the company is inevitable.

Because it turned Sentinel into a product-shaped idea with a real doctrine, a bounded wedge, a plausible UI, a coherent system model, and an honest set of remaining doubts.

That is a strong place to stop discovery and begin the next phase more deliberately.
