# Sentinel MVP Simulation Harness and Scenario Pack v1

Status: `draft execution note`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Related notes:

- `docs/vision/pharma-control-plane/current/v1/system-design.md`
- `docs/vision/pharma-control-plane/current/v1/ui-low-fidelity-wireframes.md`
- `docs/vision/pharma-control-plane/current/v1/minimal-integration-proof.md`
- `docs/vision/pharma-control-plane/current/v1/product-doctrine-options.md`

## Purpose

This note defines how Sentinel should prove its MVP without needing to integrate deeply with every surrounding enterprise system.

The core rule is:

do not mock vendor brands or full enterprise suites.

Mock the boundary behaviors that Sentinel actually depends on.

## MVP Proof Standard

The MVP is successful if a user can open Sentinel on a live scenario and answer:

- who owns this matter now
- which clock is active
- what is blocked
- which downstream action is still open
- why the current decision exists

faster and more confidently than they can with the current workaround.

The MVP does not need to prove:

- deep native parity with Veeva, Argus, or IQVIA
- full authority submission transport
- broad regulatory content coverage
- enterprise-wide integration breadth

## Boundary-Behavior Approach

The first MVP should simulate four system roles.

### 1. Source system stub

Purpose:

- represent the incumbent safety or intake system
- emit signal references and updates

What it must provide:

- source record identifier
- source system name
- minimal signal metadata
- provenance timestamp
- status update event

What it should not do:

- full case authoring
- medical coding
- complete source schema modeling

### 2. Downstream target stub

Purpose:

- represent the system or queue that must acknowledge, complete, or reject downstream follow-up

What it must provide:

- action requested
- current state: `pending`, `acknowledged`, `failed`, `not required`
- acknowledgement timestamp
- optional failure reason

What it should not do:

- broad workflow modeling
- full downstream domain behavior

### 3. Clock and rule configuration service

Purpose:

- provide narrow, workflow-specific timing and obligation logic

What it must provide:

- jurisdiction context
- one narrow rule basis
- active clock start
- due window
- not-triggered or not-required state

What it should not do:

- become a broad regulatory content engine
- attempt enterprise-wide rule coverage

### 4. Failure and delay injector

Purpose:

- force the kinds of states where Sentinel becomes valuable

What it must simulate:

- local review delay
- downstream acknowledgement failure
- transient retry
- missing evidence until attached

This role is critical because Sentinel's value is clearest in exceptions.

## Harness Topology

```text
Source System Stub ---> Sentinel Ingress ---> Matter / Timeline / Evidence / Clock State
                                         \-> Operator Workspace
Clock Config Stub ----> Rule Resolution -/
Failure Injector ------> Scenario Events -/
Sentinel Routing ------> Downstream Target Stub
```

## Recommended MVP Modules

The MVP proof environment should include:

- `scenario runner`
  - seeds scenarios and replays event sequences deterministically
- `source stub`
  - exposes a tiny API or event feed for signal references
- `downstream stub`
  - accepts and returns acknowledgement states
- `clock config`
  - file- or config-backed logic for one narrow matter type
- `workspace projections`
  - matter overview
  - path view
  - systems board
  - evidence/timeline

## Golden Scenario Pack

The first proof should use three golden scenarios.

### Scenario A: Happy path

Purpose:

- prove the matter model works when follow-up proceeds cleanly

Flow:

1. source stub emits safety-relevant issue reference
2. Sentinel opens `ComplianceMatter`
3. one local review is requested
4. clock becomes active
5. downstream target acknowledges completion
6. evidence and decision thread are preserved

What the user should see:

- clear owner
- one active clock
- no blocker ambiguity
- downstream state moves from pending to complete

### Scenario B: Delay path

Purpose:

- prove Sentinel is useful when the matter becomes operationally stressful

Flow:

1. matter opens normally
2. local affiliate input is delayed
3. clock remains active
4. downstream target remains waiting
5. operator needs to understand exactly what is blocked

What the user should see:

- owner is explicit
- clock urgency is visible
- blocker is visible in path view
- context window explains why downstream completion cannot happen yet

### Scenario C: Outage and retry path

Purpose:

- prove Sentinel retains trustworthy coordination state during technical problems

Flow:

1. matter reaches downstream routing
2. downstream target returns failure or no acknowledgement
3. retry is attempted
4. operator must determine whether the problem is business state or integration state

What the user should see:

- stream path shows retrying or blocked state
- no ambiguity about whether data was lost
- evidence timeline preserves events
- context window explains operational impact and next action

## Optional Fourth Scenario

### Scenario D: No-action decision

Purpose:

- prove Sentinel can preserve a defensible no-action outcome, not only escalations

Flow:

1. matter opens
2. review concludes no downstream action is required
3. clock is resolved or marked not triggered
4. decision rationale and supporting evidence are preserved

Why useful:

- helps prove Sentinel is not only an escalation console

## Scenario Data Contract

Each scenario should be represented by:

- `scenario id`
- `source record id`
- `source system`
- `matter type`
- `jurisdiction context`
- `active owner`
- `downstream target`
- `event sequence`
- `expected workspace answers`

The key design rule is that expected outputs should be written in human terms, not only system terms.

Example:

```text
Expected workspace answers:
- owner: Global Safety Ops
- active clock: EU follow-up due in 18h
- blocker: waiting on Germany affiliate review
- downstream state: quality queue pending
- decision basis: triage note + local review request + routing event
```

## Acceptable MVP Shortcuts

These are acceptable:

- configuration-backed clock logic
- semi-manual matter opening from a source reference
- one downstream target only
- replayed deterministic events instead of live enterprise integrations
- manual evidence attachment for early scenarios

These shortcuts still test the actual product claim.

## Misleading MVP Shortcuts

These should be avoided:

- spreadsheet import replacing the source-system relationship entirely
- static screenshots with no live state changes
- AI summaries without provenance
- dashboards without matter-level action state
- scenario demos that never show delay, retry, or unresolved blocker behavior

## UI Proof Requirements

The scenario pack should drive at least these screens:

- `Matter Workspace`
- `Path`
- `Systems`
- `Timeline / Evidence`

The graph view is optional for MVP proof.

If the graph is removed and the proof weakens materially, the product center is still too dependent on visualization novelty.

## Evidence-Grade Proof Requirements

For each scenario, Sentinel should preserve:

- source reference provenance
- clock or rule basis
- owner changes
- decision events
- downstream transmission states
- attached or referenced evidence artifacts

This is what makes the MVP evidence-grade rather than merely operational.

## Implementation Guidance

The harness should be optimized for repeatability, not realism for its own sake.

That means:

- deterministic seeds
- replayable event streams
- stable scenario IDs
- expected-answer assertions
- minimal but honest adapters

The harness is not a fake production environment.

It is a disciplined proving environment for the product claim.

## Practical Summary

Sentinel does not need to mock every enterprise system around it.

It needs to simulate the surrounding boundary behaviors that create coordination pain.

The cleanest MVP proof is:

- one source system stub
- one downstream target stub
- one narrow clock/rule configuration
- one failure injector
- three to four replayable golden scenarios

That is enough to prove whether the operator workspace and evidence-grade coordination model actually work.
