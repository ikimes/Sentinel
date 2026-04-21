# Sentinel Hypothetical Design-Partner Assessment v1

Status: `draft validation exercise`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Related notes:

- `docs/vision/pharma-control-plane/current/v1/economic-buyer-map.md`
- `docs/vision/pharma-control-plane/current/v1/build-vs-buy-teardown.md`
- `docs/vision/pharma-control-plane/current/v1/matter-frequency-and-pain-scorecard.md`
- `docs/vision/pharma-control-plane/current/v1/minimal-integration-proof.md`
- `docs/vision/pharma-control-plane/current/v1/ui-low-fidelity-wireframes.md`

## Purpose

This note tests the current Sentinel `v1` against one realistic hypothetical design partner.

The goal is not to fantasize about a perfect customer.

The goal is to force the product through one plausible buying and workflow environment and see what still breaks.

## Hypothetical Partner

`Partner A` is a multinational pharma sponsor with:

- an incumbent safety platform already in place
- separate local affiliate workflows in key markets
- one downstream quality-adjacent system used for follow-up visibility
- distributed global safety operations and local-market teams
- recurring pressure to improve speed and control after intake and triage

### Assumed operating environment

- core source system: incumbent safety platform
- one important downstream target: quality or affiliate follow-up queue
- one meaningful market split: EU affiliate plus global safety
- current coordination method: system notes, email, spreadsheets, and recurring status meetings

### Assumed recurring matter type

The repeated workflow is:

- a safety-relevant issue is captured in the source safety system
- triage indicates cross-market follow-up may be required
- global safety needs local-market confirmation
- a downstream quality or regulatory-adjacent update may be required
- ownership and due-state become hard to track after the initial signal is recorded

## Why This Is A Useful Test Partner

This partner is useful because it is not artificially ideal.

It has:

- enough system maturity for Sentinel to be an overlay
- enough fragmentation for the wedge to matter
- enough organizational structure for ownership to become blurry

But it also has real reasons not to buy:

- incumbent vendors already exist
- internal platform teams may want to solve this themselves
- the workflow might still be tolerable if pain is not severe enough

## Economic Buyer Read

### Likely operational sponsor

Most plausible:

- VP or senior director of global safety operations
- PV systems / operations transformation lead

Why:

- they feel the handoff pain directly
- they can define success in terms of ownership clarity, clock visibility, and reduced manual reconciliation

### Most plausible economic buyer

Best current guess:

- head of drug safety / pharmacovigilance
- or a safety-aligned business technology leader with transformation budget

### Approval and blockers

Likely blockers:

- enterprise architecture
- incumbent safety-platform owner
- security and procurement

### Buyer verdict

`Yellow but plausible`

This partner has a believable sponsor path, but the budget path is still fragile.

The strongest risk is still that the sponsor can champion the problem without fully owning the software decision.

## Matter Frequency And Pain Score

Scored using the current `matter-frequency-and-pain-scorecard`.

| Dimension | Score | Reason |
|---|---|---|
| `Recurrence` | `4` | likely familiar weekly or near-weekly workflow in a large global safety operation |
| `Operational severity` | `4` | delays, ambiguity, and near-miss risk are operationally meaningful |
| `Cross-system breadth` | `4` | source system plus local workflow plus one downstream target |
| `Clock pressure` | `4` | at least one market-facing or authority-relevant clock exists |
| `Evidence fragmentation` | `4` | evidence is split across system notes, messages, and follow-up artifacts |
| `Manual reconciliation cost` | `5` | recurring status meetings and spreadsheets imply real coordination tax |
| `Leadership visibility` | `3` | pain is visible during exceptions, but may not yet be a top program |
| `Buy urgency` | `3` | important enough to investigate, not automatically urgent enough to buy |
| `Overlay appetite` | `3` | plausible, but internal extension may still feel safer |
| `Repeatable model fit` | `4` | the matter shape appears stable across repeated examples |

### Total score

`38 / 50`

### Interpretation

This is a `borderline-to-strong` candidate.

The workflow looks commercially real enough to pursue, but not yet strong enough to assume demand.

The soft spots are:

- buy urgency
- overlay appetite
- leadership-level prioritization

## Build-vs-Buy Read

### Why this partner might buy Sentinel

- the workflow clearly crosses more than one system boundary
- operators need one place to understand owner, clock, block, and downstream state
- the wireframed workspace is more purpose-built than dashboards or ticket queues
- the matter model can likely be reused for repeated examples

### Why this partner might not buy Sentinel

- they may ask the incumbent suite owner to add more workflow
- they may push the problem into ServiceNow or an internal platform team
- they may decide better reporting is "good enough"

### Current buy-vs-build verdict

`Sentinel has a real opening, but not a decisive moat`

The best argument is not that Sentinel is impossible to build internally.

The best argument is that Sentinel gives them a more coherent matter model, evidence trail, and operator workspace than they are likely to assemble quickly or consistently themselves.

## Minimal Integration Proof For This Partner

### Best first-proof footprint

- `1` source safety system
- `1` downstream follow-up target
- `2` human roles:
  - global safety operations
  - local affiliate reviewer
- Sentinel as the shared matter workspace

### First proof scenario

- source safety case is linked into Sentinel as a signal reference
- Sentinel opens the `ComplianceMatter`
- Sentinel displays active clock, current owner, and local review dependency
- Sentinel shows whether downstream quality or affiliate action is pending or complete
- Sentinel preserves decision basis and evidence in one place

### Why this is enough

It directly tests the product claim without requiring:

- full case-processing replacement
- many downstream integrations
- authority gateway execution
- enterprise-wide system rollout

### First proof verdict

`Strong`

This hypothetical partner supports the idea that Sentinel can prove value with a limited footprint if the workflow pain is genuine.

## UI Fit Against This Partner

The wireframes are a good fit for this partner because the operational questions are exactly the ones the workflow creates:

- `Matter Workspace`: who owns this now and what is due
- `Path`: what is blocked and why
- `Systems`: which downstream system has or has not acted
- `Context Window`: why the current decision exists and what evidence supports it

The most important point is that the UI is not just decorative here.

It is the product surface that turns coordination state into something the partner can work from daily.

## Overall Qualification

### What looks strong

- the workflow is narrow enough to describe clearly
- the pain is believable
- the limited integration footprint is plausible
- the UI and data-platform story fit this environment well

### What still looks fragile

- economic buyer is still not certain
- the partner may prefer incumbent extension or internal build
- urgency may be moderate rather than acute

### Qualification verdict

`Worth pursuing as a design-partner candidate`

but only if discovery confirms:

- one named budget path
- real recurrence of the workflow
- real appetite for an overlay rather than replacement or reporting-only fixes

## What This Exercise Says About Sentinel

This exercise is encouraging, but not validating in the strongest sense.

It suggests:

- Sentinel is coherent enough to survive contact with a realistic partner profile
- the product can be described as a real workflow tool, not just a systems thesis
- the biggest remaining weakness is still commercial ownership, not product shape

## Practical Next Step

Use this hypothetical partner as the baseline for future validation.

Any real prospect should be compared against it on:

- buyer clarity
- matter score
- build-vs-buy pressure
- minimal integration path

If a real prospect looks materially weaker than this hypothetical one, it is probably not a good first design partner.
