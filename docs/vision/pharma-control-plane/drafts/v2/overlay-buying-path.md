# Sentinel v2 Overlay Buying Path

Status: `focused workstream`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Related notes:

- `docs/vision/pharma-control-plane/drafts/v2/synthesis.md`
- `docs/vision/pharma-control-plane/drafts/v2/executive-readout.md`
- `docs/vision/pharma-control-plane/current/v1/economic-buyer-map.md`
- `docs/vision/pharma-control-plane/current/v1/hypothetical-design-partner-assessment.md`
- `docs/vision/pharma-control-plane/current/v1/hypothetical-design-partner-assessment-weaker.md`
- `docs/vision/pharma-control-plane/current/v1/beliefs-doubts-and-must-prove-next.md`

## Purpose

This workstream isolates the hardest commercial risk still facing Sentinel:

can a narrow overlay next to incumbent systems actually be bought?

The goal is not to answer that completely in theory.

The goal is to turn the risk into a concrete evaluation frame.

## Current Read

The current product does not mainly lack a user sponsor.

It lacks an earned overlay buying path.

That means Sentinel must connect four things at once:

- a painful recurring workflow
- an operational sponsor who feels the pain directly
- a budget owner who can fund a narrow overlay
- approvers who accept the boundary with incumbent systems

If those four do not connect, the product stays believable and unbought.

## Strongest Current Buying Hypothesis

The best first buying path still looks like:

1. a safety operations leader identifies one recurring post-intake follow-up failure
2. Sentinel is framed as a narrow operational control overlay, not a suite replacement
3. the first pilot is funded from safety operations improvement, PV systems optimization, or adjacent transformation budget
4. enterprise architecture and security approve it because the systems of record do not change

This is stronger than:

- broad enterprise transformation sponsorship
- generic compliance-platform buying
- AI budget sponsorship
- architecture-first adoption

## What Must Be True For The Overlay Path To Work

### 1. The buyer must believe the overlay is materially smaller than replacement

Sentinel should feel like:

- less political friction
- less implementation exposure
- less system-of-record disruption

than extending or replacing the incumbent stack.

### 2. The workflow pain must already be visible to leadership

The buyer does not need a major incident.

But they likely need one of these:

- recurring status meetings and spreadsheets
- slow or risky exception handling
- leadership attention during follow-up delays
- inspection or audit pressure on fragmented evidence

### 3. The sponsor and the budget path must be close enough to one another

A strong operations sponsor is not enough if the budget sits somewhere vague, defensive, or politically opposed.

### 4. The overlay boundary must be intuitively legible

Approvers must be able to say:

- the source system stays authoritative
- Sentinel does not replace the suite
- the pilot is narrow enough to unwind if needed

## Where The Overlay Path Breaks

The path weakens fast when:

- no one can name the budget
- the incumbent owner insists the workflow belongs inside the suite
- architecture sees "another vendor" but not enough value
- the workflow is real but not severe enough to justify a separate product
- the sponsor wants visibility, but not a new operational surface

This is why the weaker hypothetical partner fails.

## Most Promising Commercial Framings

### 1. Narrow operational control overlay

This is still the safest frame.

It says Sentinel improves one painful workflow without changing the systems of record.

### 2. Evidence-grade follow-up workspace

This is stronger when inspection readiness, decision reconstruction, and fragmented evidence are already painful.

### 3. Exception control surface

This can help lower-appetite accounts say yes to a smaller first purchase.

It is useful only if it still leads into the deeper matter-workspace product.

## Weak Framings To Avoid

- compliance control plane
- AI-native compliance platform
- graph-first experience
- workflow modernization platform
- generalized safety orchestration layer

Those all make the overlay harder to buy.

## Strongest Questions To Test Next

- who would sponsor the first pilot if the workflow clearly qualified
- what budget would the pilot come from
- who can approve an overlay next to the incumbent system
- who most likely says no, and why
- what would make the buyer choose overlay rather than suite extension
- which first commercial wrapper makes the purchase feel smallest and safest

## Evidence Sentinel Still Needs

- one named sponsor archetype with real pilot authority
- one named budget archetype that plausibly funds the first proof
- one approval path that does not collapse under incumbent overlap concerns
- one framing that lowers perceived risk without hollowing out the product

## Working Decision Rule

Treat the overlay buying path as earned only when a target prospect can answer all of these clearly:

- who sponsors the pilot
- who pays for it
- who approves it
- why this should be an overlay rather than a suite extension or internal build

Until then, Sentinel should assume the buying path is still a live risk.
