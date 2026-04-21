# Sentinel Economic Buyer Map v1

Status: `draft validation note`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Related notes:

- `docs/vision/pharma-control-plane/current/v1/vision.md`
- `docs/vision/pharma-control-plane/current/v1/feasibility-and-entry-framework.md`
- `docs/vision/pharma-control-plane/current/v1/beliefs-doubts-and-must-prove-next.md`
- `docs/vision/pharma-control-plane/current/v1/design-partner-discovery-guide.md`

## Purpose

This note turns the vague question of "who buys Sentinel?" into a concrete validation map.

The goal is not to declare the answer solved.

The goal is to identify:

- who feels the daily pain
- who can sponsor a pilot
- who controls budget
- who can block an overlay
- what buying path is most realistic for the first wedge

## Core Problem

The biggest commercial risk is still simple:

the user sponsor may be real, while the economic buyer is still missing.

Sentinel does not become a company unless those two things connect.

## Buyer Layers

### 1. Daily user

Likely users:

- global safety operations teams
- local safety affiliates
- outsourced safety or follow-up partners
- regulatory coordinators when the matter crosses into regulatory follow-up

What they want:

- clear ownership
- visible clocks
- less status reconstruction
- easier evidence and decision review

These users are necessary.

They are not sufficient buyers by themselves.

### 2. Operational sponsor

Most likely first sponsor:

- head of global safety operations
- VP or senior director of pharmacovigilance operations
- PV systems or operations transformation lead

Why this layer matters:

- they feel the pain directly
- they can define success in operational terms
- they may sponsor a pilot if the workflow is narrow and painful enough

Risk:

- they may not own durable software budget
- they may be able to champion, but not actually buy

### 3. Economic buyer

Most plausible economic buyers for the first wedge:

- a VP or head of drug safety / pharmacovigilance with discretionary transformation budget
- an enterprise safety-platform owner with budget for adjacent tooling
- a business technology or digital transformation leader aligned to safety operations

Possible but weaker economic buyers:

- regulatory operations leadership
- quality systems leadership
- enterprise architecture leadership

Why weaker:

- they may be stakeholders rather than the party most motivated to fund the first proof

### 4. Approval and blocking layer

These roles may not buy Sentinel, but they can absolutely stop it:

- enterprise architecture
- security and compliance
- platform engineering
- incumbent-suite owners
- procurement and vendor management

Their typical concern is not the workflow pain itself.

It is:

- another integration surface
- another vendor in the stack
- overlap with current platforms
- unclear boundary versus incumbent systems

## Best Current Buying Hypothesis

The most credible first buying path is:

1. an operational sponsor inside safety identifies one recurring post-intake coordination failure
2. that sponsor frames Sentinel as a narrow overlay, not a suite replacement
3. the first pilot is funded from operations transformation, safety systems optimization, or adjacent digital budget
4. enterprise architecture and security approve the overlay because the authoritative systems remain unchanged

This is more believable than:

- a central enterprise platform team buying Sentinel top-down first
- a broad compliance transformation program buying Sentinel as its initial center
- a buyer adopting Sentinel before it is tied to one painful recurring workflow

## Buyer Archetype Ranking

| Archetype | Current fit | Why |
|---|---|---|
| `Global safety operations leader` | high | strongest pain ownership and most believable day-one sponsor |
| `PV systems / operations transformation leader` | high | can connect operational pain to tooling budget and pilot scope |
| `Head of drug safety / PV` | medium-high | could be true economic buyer if pain is visible enough |
| `Business technology leader aligned to safety` | medium | can fund overlays, but needs strong business sponsor |
| `Regulatory operations leader` | medium-low | useful stakeholder, weaker first sponsor unless workflow is visibly shared |
| `Enterprise architecture leader` | low | more likely blocker or approver than originating buyer |
| `Chief compliance / GRC leader` | low | too broad for the narrow first wedge |

## What A Real Buyer Must Believe

For Sentinel to be buyable, the economic buyer must believe all of these:

- the problem is already expensive enough without new software
- the workaround is operationally embarrassing or risky
- the overlay can improve outcomes without replacing the core suite
- the first pilot is narrow enough to contain implementation risk
- Sentinel is more repeatable than a one-off internal build

If even one of those is missing, the conversation can slide back to "maybe later" very quickly.

## Budget Hypotheses To Test

The most plausible budget sources are:

- safety operations improvement budget
- PV systems optimization budget
- digital transformation budget attached to safety or operations
- adjacent innovation budget for workflow and evidence control

Less plausible first-budget sources:

- enterprise AI strategy budget
- broad compliance transformation budget
- analytics or BI budget alone
- generic architecture modernization budget

Those may participate later, but they are weak anchors for the first wedge.

## Discovery Questions That Test Real Buying Power

- who would sponsor the pilot if the workflow clearly qualified
- what budget would a pilot likely come from
- has this team purchased adjacent workflow or overlay tooling before
- who must approve an overlay even if the business sponsor wants it
- who owns the incumbent system that Sentinel would sit beside
- who would say "no" because they believe current platforms should cover this
- what failure or near-miss would make budget appear faster

## Green Signals

- one named executive can sponsor the pilot and define success
- that sponsor controls or can access a transformation budget
- the buyer already distinguishes this pain from suite replacement
- architecture stakeholders accept the overlay boundary quickly
- the pilot can be justified as an operational control improvement, not just nicer visibility

## Yellow Signals

- a strong operator sponsor exists, but budget source is vague
- several leaders agree on the pain, but none owns the decision
- the buyer likes the concept, but wants a much broader future story before approving a pilot

## Red Signals

- everyone agrees the pain is real, but no one can name the budget
- the strongest sponsor is below the level needed to add a new vendor
- the real buyer wants to finish an incumbent rollout first
- the buyer sees Sentinel mainly as reporting, AI, or architecture experimentation
- incumbent owners insist the workflow should be solved inside current platforms

## Current Best Working Position

The safest commercial framing right now is:

Sentinel is a narrow operational control overlay for safety-led cross-system follow-up matters.

That framing gives the economic buyer the best chance to say:

- this is small enough to try
- this is painful enough to matter
- this does not force us to replace our core systems

## Practical Decision Rule

Treat the buyer question as unresolved until a real prospect can answer all three of these clearly:

- who sponsors the pilot
- who owns the budget
- who has authority to approve an overlay next to the incumbent stack

If those answers keep drifting apart, the wedge may remain intellectually strong and commercially weak.
