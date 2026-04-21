# Sentinel Build-vs-Buy Teardown v1

Status: `draft validation note`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Related notes:

- `docs/vision/pharma-control-plane/current/v1/competitive-positioning-comparison.md`
- `docs/vision/pharma-control-plane/current/v1/feasibility-and-entry-framework.md`
- `docs/vision/pharma-control-plane/current/v1/ui-low-fidelity-wireframes.md`
- `docs/vision/pharma-control-plane/current/v1/beliefs-doubts-and-must-prove-next.md`

## Purpose

This note answers the hardest strategic question still hanging over Sentinel:

why should a buyer purchase Sentinel instead of extending the stack they already have?

The relevant alternatives are:

- extend the incumbent suite
- build on ServiceNow or an internal platform
- rely on dashboards and reporting
- keep using manual coordination

## The Standard Sentinel Must Beat

Sentinel does not win by being more conceptually elegant.

It wins only if it is more credible on these dimensions:

- faster time to operational value
- stronger matter-level ownership clarity
- stronger evidence and decision reconstruction
- clearer downstream completion state
- better operator experience for cross-system follow-up
- lower long-run drift into bespoke services than an internal build

## Option 1: Extend The Incumbent Suite

### Why buyers like it

- fewer vendors
- lower political friction
- leverages existing record ownership
- looks safer to architecture and procurement

### Why it may fail on Sentinel's workflow

- the workflow crosses systems the suite does not own well
- evidence for the matter lives outside the suite boundary
- local/global handoffs span organizational and platform seams
- downstream completion still requires stitching together states from elsewhere

### What Sentinel must prove to beat it

- the first workflow genuinely crosses suite boundaries
- one cross-system matter workspace is materially better than more workflow inside one suite
- operators can answer owner, clock, block, and evidence questions faster in Sentinel than in the incumbent stack

### No-buy implication

If the incumbent suite can answer the first matter cleanly enough with minor extension, Sentinel probably should not be bought there.

## Option 2: Build On ServiceNow Or Internal Platform

### Why buyers like it

- uses existing teams and budget
- politically easy to justify
- flexible for local process quirks
- feels safer than a new category product

### Why it may fail on Sentinel's workflow

- can become ticketing plus custom reports
- provenance and matter logic may be inconsistent
- operator experience may drift by team or project
- each new workflow may require more custom modeling and services

### What Sentinel must prove to beat it

- a stable coordination-state model that works repeatedly
- a better default operator workspace than a generic workflow build
- purpose-built context compression with provenance
- lower total design and maintenance burden over repeated workflows

### No-buy implication

If the buyer already has a strong internal platform team and only needs one narrow local workflow, internal build may be the rational choice.

## Option 3: Analytics And Reporting Only

### Why buyers like it

- familiar
- often already budgeted
- fast to prototype
- good for leadership visibility

### Why it fails on Sentinel's workflow

- dashboards do not own current matter state
- dashboards do not preserve accountable handoffs
- dashboards do not create evidence-backed decisions
- dashboards rarely help operators close the loop

### What Sentinel must prove to beat it

- operators can act from Sentinel, not just observe
- the workspace reduces manual reconciliation, not just reports on it
- the system can show current owner, active clocks, and downstream action state directly

### No-buy implication

If leadership only wants visibility, analytics may be enough and Sentinel should stay out.

## Option 4: Manual Coordination

### Why buyers tolerate it

- no procurement
- flexible for edge cases
- hidden costs are dispersed

### Why it eventually breaks

- ownership is ambiguous
- clocks are easy to miss
- audit reconstruction is painful
- outage and exception handling are slow

### What Sentinel must prove to beat it

- the pain is painful enough to stop tolerating
- the product meaningfully reduces manual touchpoints
- the workspace becomes a better daily habit than email and spreadsheets

## What Sentinel Must Be, Or It Loses

To survive the build-vs-buy test, Sentinel must be all of these at once:

- a reusable `ComplianceMatter` and coordination-state model
- an evidence-grade timeline and provenance layer
- a purpose-built operator workspace for cross-system follow-up
- an integration-light first proof

If Sentinel loses any one of these, it becomes vulnerable:

- without the stable model, it becomes services
- without the provenance layer, it becomes workflow tooling
- without the operator workspace, it becomes plumbing
- without limited-integration value, it becomes an implementation project

## The Most Defensible Buy Argument

The strongest current buy argument is:

Sentinel productizes a cross-system compliance matter model and operator workspace that buyers would otherwise rebuild imperfectly inside ticketing, dashboards, and one-off integrations.

That is stronger than:

- "we orchestrate systems"
- "we give you a graph"
- "we add AI summaries"

## The Weakest Buy Argument

The weakest version is:

Sentinel gives you one more place to see status.

That version will lose to:

- incumbent extension
- analytics tooling
- internal build

## Practical Test Questions

- would the buyer still want Sentinel if the graph view disappeared
- would the buyer still want Sentinel if AI summaries were turned off
- would the buyer still want Sentinel if the incumbent suite offered one more workflow screen
- would the buyer still want Sentinel if dashboards became better

If the answer to any of those is "no," the product is not yet distinct enough.

## Working Decision Rule

Sentinel is earning a real buy case only when a buyer says something close to:

"We could try to build this ourselves, but the matter model, evidence trail, and operator workspace are distinct enough that buying Sentinel is more credible than stitching it together again."
