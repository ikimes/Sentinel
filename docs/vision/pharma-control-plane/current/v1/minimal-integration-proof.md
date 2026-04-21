# Sentinel Minimal Integration Proof v1

Status: `draft validation note`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Related notes:

- `docs/vision/pharma-control-plane/current/v1/system-design.md`
- `docs/vision/pharma-control-plane/current/v1/pilot-acceptance-plan.md`
- `docs/vision/pharma-control-plane/current/v1/ui-low-fidelity-wireframes.md`
- `docs/vision/pharma-control-plane/current/v1/beliefs-doubts-and-must-prove-next.md`

## Purpose

This note defines the smallest integration footprint that should still prove Sentinel is valuable.

The commercial reason is simple:

if Sentinel needs a large integration program before value appears, adoption will get much harder.

## Core Principle

The first proof should demonstrate product value before the buyer commits to a broad systems program.

That means:

- limited systems
- limited teams
- one recurring matter type
- clear operator questions answered well

## Smallest Credible First Footprint

The first proof should aim for:

- `1` incumbent source system
- `1` downstream target or follow-up destination
- `2` to `3` human roles
- Sentinel as the coordination-state and operator workspace layer

In plain terms:

- one system where the safety-relevant issue already exists
- one place where a downstream update, handoff, or acknowledgement must be tracked
- one local and one global working team

That is enough to test whether Sentinel creates real coordination value.

## Recommended First-Proof Configuration

### In scope

- incumbent source safety or intake system
- Sentinel matter workspace
- one downstream follow-up target such as affiliate workflow, quality queue, or regulatory tracker
- evidence and timeline inside Sentinel
- focused notifications or work-item state changes

### Out of scope

- many downstream systems at once
- authority transport execution
- broad data-lake or warehouse build-out
- enterprise-wide master-data unification
- fully automated end-to-end orchestration before the matter model proves useful

## What The First Integration Must Support

### 1. Source reference ingestion

Sentinel must be able to receive or register:

- source record identifier
- source system name
- minimal event or signal metadata
- provenance timestamp

It does not need the full source record model on day one.

### 2. Matter creation and update

Sentinel must be able to:

- open or link a `ComplianceMatter`
- assign owner and responsible party
- attach evidence and decisions
- display active clocks and open obligations

### 3. Downstream state visibility

Sentinel must be able to show:

- whether the downstream action is needed
- whether it is pending, complete, failed, or not required
- what evidence or acknowledgement supports the current state

### 4. Operator-readable projections

Sentinel must provide enough read models to answer:

- who owns this now
- which clocks are active
- what is blocked
- which downstream action is still open
- why the current decision exists

## Acceptable First-Proof Shortcuts

These shortcuts are acceptable if they accelerate validation without breaking trust:

- semi-manual matter opening from a source reference
- configuration-backed clock logic for one narrow workflow
- manual evidence attachment
- a single downstream acknowledgement adapter
- lightweight notifications rather than full orchestration automation

These shortcuts are not product failure.

They are acceptable if the core product claim is still being tested honestly.

## Unacceptable First-Proof Shortcuts

These shortcuts would make the pilot misleading:

- spreadsheet import standing in for the actual source-system relationship
- a UI demo with no real coordination-state persistence
- operator views that cannot show real provenance
- no downstream state at all
- a proof that only shows dashboards and summaries without matter-level action state

## Minimal Success Test

The first proof is strong enough only if a user can do this on a live matter:

1. open the matter workspace
2. see the current owner
3. see the active clock
4. see the downstream action state
5. open the context window and understand why the matter is in its current state

If that experience still requires searching across several systems, the proof is not yet good enough.

## Why This Matters Strategically

This minimal-integration rule helps Sentinel confront two open risks directly:

- whether the product can win before many integrations are required
- whether the product is a real product or just an implementation-heavy overlay

If the first proof needs many systems before value appears, Sentinel becomes much easier to dismiss as a large project.

## Practical Decision Rule

Do not expand the first proof beyond:

- one recurring matter type
- one source system
- one downstream target
- a small number of accountable users

until the buyer can already say:

"Even with this small footprint, Sentinel gives us a better way to understand and work this matter than the stack we already had."
