# Sentinel v2 Qualification Boundary Memo

Status: `working memo`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Related notes:

- `docs/vision/pharma-control-plane/drafts/v2/partner-a-tool-dry-run.md`
- `docs/vision/pharma-control-plane/drafts/v2/partner-b-tool-dry-run.md`
- `docs/vision/pharma-control-plane/drafts/v2/overlay-buying-path-interview-rubric.md`
- `docs/vision/pharma-control-plane/drafts/v2/internal-build-comparison-scorecard.md`
- `docs/vision/pharma-control-plane/drafts/v2/executive-readout.md`

## Purpose

This memo turns the current `v2` dry runs into a practical qualification boundary for first-customer pursuit.

It answers three questions:

- what makes a prospect strong enough to pursue
- what makes a prospect drift into "interesting but wrong for now"
- what hard disqualifiers should stop Sentinel early

## Short Read

Sentinel should pursue prospects that look at least as strong as `Partner A` and avoid prospects that drift toward `Partner B`.

The core difference is not company prestige or surface complexity.

It is whether the pain is concentrated strongly enough to create:

- a credible overlay buying path
- a real advantage over internal build

## The Boundary In One Sentence

Sentinel qualifies when one recurring cross-system follow-up matter is painful, visible, and reusable enough that buying a narrow overlay feels more credible than extending the incumbent stack or stitching together a local build.

## The Strong Side Of The Boundary

Prospects on the strong side of the line look like `Partner A`.

### Signals that push a prospect toward Partner A

- the matter recurs often enough to shape weekly or near-weekly operations
- the workflow genuinely crosses systems and teams
- ownership and due-state become hard to see after intake
- evidence and downstream completion are reconstructed manually today
- leadership sees the pain often enough for it to feel like a control problem
- one operations-oriented sponsor can plausibly champion a pilot
- one budget path is at least plausible
- an overlay feels politically smaller than replacement
- internal build looks possible but likely to drift into tickets, reports, and one-off integrations
- the first product footprint can stay narrow while still mattering

### What a strong prospect should sound like

The strongest prospects say things close to:

- "This one workflow keeps costing us time and clarity."
- "We do not want to replace the suite. We want control over the seams."
- "We could build this ourselves, but it would likely become another stitched solution."

## The Weak Side Of The Boundary

Prospects on the weak side of the line look like `Partner B`.

### Signals that push a prospect toward Partner B

- the matter happens only occasionally
- most of the workflow stays inside one incumbent system
- local-market or downstream complexity is limited
- leadership mostly sees the issue as an annoyance, not a recurring operational problem
- the strongest sponsor is too low-level or too indirect to drive a pilot
- budget is vague or hypothetical
- overlay appetite is weak because local extension feels sufficient
- internal build looks not just plausible, but proportionate
- the product would mainly improve visibility rather than change how the work is controlled

### What a weak prospect usually sounds like

The weakest acceptable-sounding prospects say things close to:

- "This is annoying, but not a top priority."
- "We could probably solve most of this with a few workflow tweaks and better reporting."
- "The UI looks useful, but I am not sure it justifies another product."

## What Actually Flips The Result

The dry runs suggest five flip points matter most:

### 1. Recurrence

- `Partner A`: frequent enough to matter operationally
- `Partner B`: occasional enough to tolerate

### 2. Cross-system breadth

- `Partner A`: real multi-system coordination burden
- `Partner B`: mostly contained inside one stack

### 3. Leadership visibility

- `Partner A`: visible often enough to sponsor concern
- `Partner B`: visible mostly during exceptions

### 4. Overlay appetite

- `Partner A`: plausible if framed narrowly
- `Partner B`: weak because extension feels safer

### 5. Internal-build proportionality

- `Partner A`: internal build is respectable but contestable
- `Partner B`: internal build feels more proportional than Sentinel

## Minimum Qualification Bar

Do not pursue a prospect unless most of these are true:

- one recurring matter type is obvious
- at least two systems and two teams clearly matter
- ownership, evidence, and downstream-state pain already exist
- the issue is visible enough that leadership can recognize it
- one sponsor can plausibly champion the pilot
- one budget path is at least plausible
- the buyer sees value in an overlay rather than only in extension or reporting
- internal build is not obviously the more proportional answer

## Hard Disqualifiers

Stop early if any of these dominate:

- no recurring matter type can be named
- the workflow mostly stays inside one incumbent system
- the buyer mainly wants dashboards, reports, or generic visibility
- the buyer mainly wants full suite replacement
- no plausible budget path exists
- the sponsor cannot realistically drive a pilot
- the first commercial wrapper still does not make the purchase feel legible
- internal build is clearly faster, cheaper, and good enough for the workflow

## Practical Filter

Use this simple rule:

### Pursue

Pursue when the prospect feels at least as strong as `Partner A` on both:

- overlay buying-path quality
- internal-build contestability

### Keep Qualifying

Keep qualifying when:

- the workflow is strong
- product fit looks good
- but buyer clarity or buy-versus-build confidence is still incomplete

### Walk Away

Walk away when the prospect starts resembling `Partner B` on either of these:

- no credible buying motion
- internal build clearly feels more proportional than Sentinel

## What This Means For Sentinel

Sentinel should not treat "interesting workflow" as enough.

The first-customer bar is higher:

- the workflow must qualify
- the buying path must qualify
- the internal-build comparison must at least be contestable

That means the first customer is not just the one with pain.

It is the one where:

- pain is concentrated
- the overlay can be bought
- and Sentinel has a credible right to exist as product rather than local project.

## Recommended Next Use

Use this memo as the front-door filter before deep discovery.

Then use:

- `docs/vision/pharma-control-plane/drafts/v2/overlay-buying-path-interview-rubric.md`
- `docs/vision/pharma-control-plane/drafts/v2/internal-build-comparison-scorecard.md`

to score the prospect in detail.
