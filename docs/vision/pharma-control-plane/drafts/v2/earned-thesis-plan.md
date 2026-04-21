# Sentinel v2 Earned Thesis Plan

Status: `working memo`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Related notes:

- `docs/vision/pharma-control-plane/current/v1/v1-discovery-wrap-and-strategic-thesis.md`
- `docs/vision/pharma-control-plane/current/v1/beliefs-doubts-and-must-prove-next.md`
- `docs/vision/pharma-control-plane/current/v1/design-partner-discovery-guide.md`
- `docs/vision/pharma-control-plane/current/v1/pilot-acceptance-plan.md`
- `docs/vision/pharma-control-plane/current/v1/mvp-simulation-harness-and-scenario-pack.md`
- `docs/vision/pharma-control-plane/drafts/v2/overlay-buying-path-interview-rubric.md`
- `docs/vision/pharma-control-plane/drafts/v2/internal-build-comparison-scorecard.md`
- `docs/vision/pharma-control-plane/drafts/v2/qualification-boundary-memo.md`

## Purpose

This memo defines what it means for Sentinel to earn its thesis after `v1` discovery produced a coherent product idea.

It exists to answer two practical questions:

- what evidence would make Sentinel more than a coherent concept
- how the team should move through that proof sequence without overbuilding

## Short Read

Sentinel should not try to earn its full company thesis all at once.

It should earn a narrower wedge thesis first:

Sentinel deserves to exist as a product if one recurring post-intake cross-system regulated follow-up matter is painful enough, buyable enough, and better served by Sentinel than by internal build or incumbent extension.

That thesis is earned only when the team can prove all of these at the same time:

- the same matter type appears repeatedly across qualified prospects
- at least one prospect has a credible overlay buying path
- Sentinel's buy case is stronger than internal build for the chosen workflow
- a narrow MVP proves the five core operator questions better than the current workaround
- the matter model survives repeated examples without turning into bespoke services

## Coherent Product Versus Earned Thesis

`v1` already established a coherent product center:

- a governed matter workspace on the surface
- a coordination-state layer underneath
- a narrow overlay boundary beside incumbent systems

That is necessary, but not sufficient.

An earned thesis requires field evidence, not only strategic coherence.

The team should therefore treat the next phase as proof work, not idea work.

## Sentinel Earned Thesis Standard

Sentinel should consider its initial wedge thesis earned only when the following are true:

### 1. Workflow proof

- one recurring matter type can be named in concrete operational language
- the matter repeats often enough to matter
- the workflow genuinely crosses systems and teams
- ownership, clocks, evidence, and downstream completion are hard to reconstruct today

### 2. Buying-path proof

- one named operational sponsor exists
- one plausible budget source exists
- one approval path for a narrow overlay is legible
- the buyer can explain why this should be an overlay rather than suite extension

### 3. Build-vs-buy proof

- Sentinel looks more credible than internal build on product coherence
- Sentinel looks more credible than internal build on repeatability
- Sentinel looks more credible than internal build on evidence rigor
- Sentinel looks more credible than internal build on speed to useful proof

### 4. Product proof

- the MVP or pilot lets a user answer:
  - who owns this matter now
  - which clock is active
  - what is blocked
  - which downstream action is still open
  - why the current decision exists
- users can answer those faster and more confidently than with the current workaround

### 5. Productization proof

- the same core matter model survives repeated examples
- the first proof works with one source system and one downstream target
- the product does not drift into generic workflow, dashboards, or bespoke services

If any one of these fails, the thesis remains unearned.

## Working Order To Earn The Thesis

The team should move through five stages in order.

Each stage exists to kill or strengthen the next one.

### Stage 1: Qualify The Workflow

Goal:

prove that the chosen matter type is real, recurring, and bounded enough to deserve a product.

Primary tools:

- `docs/vision/pharma-control-plane/current/v1/design-partner-discovery-guide.md`
- `docs/vision/pharma-control-plane/drafts/v2/qualification-boundary-memo.md`

Key questions:

- can prospects describe the same matter type repeatedly
- does the workflow cross at least two systems and two teams
- is the pain operational rather than only analytical
- does the buyer want coordination help rather than replacement software

Exit standard:

- at least one recurring matter type is obvious
- the matter type qualifies as at least `green` or strong `yellow`
- weak-fit prospects are actively disqualified rather than kept alive optimistically

### Stage 2: Qualify The Overlay Buying Path

Goal:

prove that a narrow overlay is actually buyable beside incumbent systems.

Primary tool:

- `docs/vision/pharma-control-plane/drafts/v2/overlay-buying-path-interview-rubric.md`

Key questions:

- who feels this pain weekly
- who would sponsor the pilot
- what budget would fund it
- who approves the overlay
- what first commercial framing feels smallest and safest

Exit standard:

- one sponsor, one budget path, and one approval path are all visible
- the best first framing lowers friction without hollowing out the product
- the prospect can explain why overlay is the right shape

### Stage 3: Beat Internal Build Honestly

Goal:

prove that Sentinel is a better answer than a local build or incumbent extension.

Primary tool:

- `docs/vision/pharma-control-plane/drafts/v2/internal-build-comparison-scorecard.md`

Key questions:

- would a local workflow build be good enough
- is evidence and provenance rigor materially important
- do operators need a shared workspace
- is downstream completion fragmented enough to justify product
- can Sentinel prove value faster than internal build

Exit standard:

- Sentinel scores as clearly contestable or advantaged against internal build
- the strongest prospect can say buying Sentinel feels more credible than stitching the answer together internally

### Stage 4: Build The Minimum Proof Product

Goal:

prove the product claim with the smallest honest implementation.

Primary tool:

- `docs/vision/pharma-control-plane/current/v1/mvp-simulation-harness-and-scenario-pack.md`

Build target:

- one source system stub
- one downstream target stub
- one narrow clock / obligation configuration
- one matter workspace with owner, clock, blocker, evidence, and downstream state
- scenario replay for happy path, delay path, and failure / retry path

Exit standard:

- the MVP can answer the five core operator questions on live scenarios
- the answer is clearer than the current workaround
- value appears before broad integration work is required

### Stage 5: Run A Narrow Pilot

Goal:

prove the wedge in the field without drifting into suite replacement.

Primary tool:

- `docs/vision/pharma-control-plane/current/v1/pilot-acceptance-plan.md`

Pilot standard:

- one recurring matter type only
- one source system
- one downstream target
- one small user group
- explicit success criteria around ownership, clocks, evidence, and downstream completion

Exit standard:

- the pilot proves matter visibility
- the pilot proves ownership and clock clarity
- the pilot proves evidence and decision traceability
- the pilot proves downstream coordination state
- the pilot preserves overlay integrity

## How To Move Through The Plan Without Overbuilding

The team should not run product, commercial, and engineering work as separate bets.

Instead, use a single narrowing loop:

1. qualify real prospects
2. reject weak prospects quickly
3. build only what the strongest prospect and proof workflow require
4. test the product against buy-versus-build, not only against user enthusiasm
5. stop widening scope until the narrow wedge proves itself

That means:

- do not build broad platform capabilities before the workflow qualifies
- do not add integrations beyond the minimum proof shape
- do not let demo polish replace buying-path proof
- do not treat conceptual agreement as evidence that a pilot will happen

## Practical Product-Solidification Loop

The most useful operating loop from here is:

### 1. Discovery and qualification

- run targeted design-partner conversations
- record each prospect against the workflow and qualification boundary
- walk away from weak-fit prospects early

### 2. Commercial proof

- score strong prospects on overlay buying path
- score strong prospects on internal-build contestability
- identify the best first commercial wrapper for each

### 3. Proof build

- implement only the MVP harness and workspace needed to test the chosen workflow
- keep the product centered on owner, clock, blocker, evidence, and downstream state

### 4. Pilot shaping

- shape one narrow pilot with one design partner
- agree pilot metrics before starting
- keep scope fixed unless a change improves proof quality directly

### 5. Decision

- continue if the workflow, buying path, and product proof all strengthen together
- re-scope if the workflow is real but the first proof is too broad
- pause or reframe if the best prospect still prefers internal build or suite extension

## Suggested Stop Rules

Do not call the thesis earned if:

- prospects cannot name the same matter type repeatedly
- the best prospect cannot connect sponsor, budget, approval, and overlay rationale
- internal build still feels more proportional than buying Sentinel
- the MVP proves reporting value but not coordination value
- the matter model changes materially from one example to the next

## Practical Success Read

The first real success state is not:

- broad category acceptance
- many integrations
- a full platform story

The first real success state is:

- one recurring workflow
- one buyable overlay motion
- one credible win against internal build
- one narrow pilot that proves Sentinel changes daily coordination materially

That is the point where Sentinel moves from coherent product to earned wedge thesis.
