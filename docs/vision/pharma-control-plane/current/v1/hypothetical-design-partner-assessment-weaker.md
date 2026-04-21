# Sentinel Hypothetical Design-Partner Assessment v1B

Status: `draft validation exercise`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Related notes:

- `docs/vision/pharma-control-plane/current/v1/hypothetical-design-partner-assessment.md`
- `docs/vision/pharma-control-plane/current/v1/economic-buyer-map.md`
- `docs/vision/pharma-control-plane/current/v1/build-vs-buy-teardown.md`
- `docs/vision/pharma-control-plane/current/v1/matter-frequency-and-pain-scorecard.md`
- `docs/vision/pharma-control-plane/current/v1/minimal-integration-proof.md`

## Purpose

This note tests Sentinel against a deliberately weaker but still plausible design-partner profile.

The goal is to identify where the wedge starts to fail.

This is not the wrong customer in an obvious way.

It is the kind of customer that could sound exciting in conversation but still be a weak first partner.

## Hypothetical Partner

`Partner B` is a mid-sized biotech with:

- one incumbent safety platform
- limited local-market complexity
- a small central safety operations team
- basic reporting in Power BI
- a light internal workflow team that can build on existing enterprise tools when needed

### Assumed operating environment

- core source system: incumbent safety platform
- downstream follow-up is usually handled by notes, email, or a light internal queue
- only occasional local-market involvement outside the central team
- most matters remain within one system and one primary working group

### Assumed recurring matter type

The candidate workflow is:

- a safety-relevant issue is captured in the safety system
- occasionally one market-specific follow-up is required
- central safety asks for local confirmation
- most of the time the issue is resolved without many downstream system updates

## Why This Is A Useful Failure Test

This partner is useful because it is not obviously disqualified.

There is some real coordination pain.

There is some cross-market behavior.

There is some interest in better visibility.

But the question is whether that adds up to enough wedge for Sentinel to matter.

## Economic Buyer Read

### Likely operational sponsor

Most plausible:

- director of safety operations
- systems manager for the safety platform

### Most plausible economic buyer

Unclear.

Possible answers:

- head of safety
- business systems leader
- no one clearly named

### Approval and blockers

Likely blockers:

- enterprise applications team
- incumbent-suite owner
- procurement

### Buyer verdict

`Weak`

The operational sponsor exists, but the budget path is blurry and likely too small or too indirect.

This is exactly the kind of partner who could agree with the problem and still never buy.

## Matter Frequency And Pain Score

| Dimension | Score | Reason |
|---|---|---|
| `Recurrence` | `2` | cross-market follow-up exists, but not often enough to shape weekly operations |
| `Operational severity` | `2` | irritating and occasionally risky, but usually manageable |
| `Cross-system breadth` | `2` | most matters remain inside the safety platform or a light internal queue |
| `Clock pressure` | `2` | timing matters sometimes, but not with regular multi-market intensity |
| `Evidence fragmentation` | `3` | some stitching is needed, but not consistently severe |
| `Manual reconciliation cost` | `3` | recurring enough to be annoying, not severe enough to dominate operations |
| `Leadership visibility` | `2` | leadership notices exceptions, but not as an ongoing control problem |
| `Buy urgency` | `2` | likely to be deferred in favor of existing priorities |
| `Overlay appetite` | `2` | internal extension feels safer than a new overlay |
| `Repeatable model fit` | `3` | some shared shape, but the workflow does not feel central enough |

### Total score

`23 / 50`

### Interpretation

This is a weak first-design-partner candidate.

The workflow is real enough to discuss, but not commercially dense enough to anchor the first product.

## Build-vs-Buy Read

### Why this partner might like the idea

- the UI could make their occasional messy matters easier to understand
- one workspace for owner, clock, and evidence would still feel cleaner than email and notes

### Why this partner likely does not buy

- incumbent extension feels sufficient
- internal workflow tooling can probably cover the small number of exceptions
- better reporting may feel like the cheapest answer

### Current buy-vs-build verdict

`Build, extend, or tolerate`

This partner is where the wedge starts to fail.

The workflow is not painful enough, frequent enough, or broad enough to force a separate product decision.

## Minimal Integration Proof For This Partner

### Technically possible first-proof footprint

- `1` source safety system
- `1` light downstream queue
- `2` human roles

### Commercial problem

Even if Sentinel could be integrated lightly here, the result may still look like:

- nicer status visibility
- nicer context
- cleaner exception handling

That is not enough by itself.

The buyer may reasonably say:

"This is helpful, but not enough to add another product."

### First proof verdict

`Technically plausible, commercially weak`

This is an important distinction.

The wedge does not fail here because the software cannot be built.

It fails because the value is too light relative to the alternatives.

## UI Fit Against This Partner

The UI would still look good here.

That is part of the risk.

The partner could easily like:

- the Matter Workspace
- the Path view
- the Context Window

without actually needing Sentinel strongly enough.

This is the clearest reminder that good UI is not the same as strong demand.

## Where The Wedge Starts To Fail

This partner exposes several failure edges clearly:

- the workflow does not recur often enough
- too much of the activity still lives comfortably inside the incumbent system
- leadership visibility is weak
- overlay appetite is low
- the internal build alternative is good enough

Once several of those are true at the same time, Sentinel stops feeling like a must-have control surface and starts feeling like a nice improvement.

## Qualification Verdict

`Do not pursue as a first design partner`

This partner is still useful as a comparison case because it shows the wedge failing without the story becoming absurd.

## What This Exercise Says About Sentinel

This is a healthy failure case.

It suggests Sentinel should stay disciplined about only pursuing partners where:

- the matter is frequent
- the coordination pain is operationally serious
- the workflow genuinely crosses system boundaries
- the buyer wants an overlay strongly enough to pay for it

If those are not true, the product can still look sharp and still be the wrong first bet.
