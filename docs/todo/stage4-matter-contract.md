# Stage 4 Matter Contract

Status: `locked by S2.1`

## Purpose

This note fixes the first Stage 4 proof matter so future slices can implement against one narrow contract without reopening product-definition decisions.

## Selected Matter

- `matter name`: `post-intake cross-market safety follow-up matter`
- `narrow proof shape`: one safety-intake signal creates one governed follow-up matter that needs one local affiliate review and, if warranted, one downstream quality action acknowledgement
- `proof market`: Germany affiliate review for the first deterministic replay pack
- `primary operator lens`: global safety operations coordinating one cross-system follow-up thread

## Why This Matter

This matter already matches the strongest recurring wedge in the current vision package:

- it is post-intake, not a broad intake or case-management replacement
- it crosses one global team, one local affiliate, and one downstream target
- it creates the ownership, clock, blocker, and downstream-state ambiguity Sentinel is meant to resolve
- it stays narrow enough for one source stub, one downstream stub, and one configuration-backed clock model

## Scope Boundaries

In scope:

- one source-system stub representing the incumbent safety intake system
- one downstream target stub representing a quality action queue
- one configuration-backed clock for Germany affiliate follow-up
- one governed matter thread with evidence, owner state, clock state, and downstream state

Out of scope:

- broad workflow orchestration
- multiple downstream targets
- generic dashboards or cross-matter reporting
- deep regulatory-content engines
- full case authoring or source-system replacement

## Fixed System Seams

### Source Stub

- `system name`: `Safety Intake Stub`
- `emits`: source record id, source system name, signal summary, provenance timestamp, and narrow status updates
- `first proof event`: a triaged safety signal that may require Germany affiliate confirmation and possible downstream quality follow-up

### Downstream Stub

- `system name`: `Quality Action Queue Stub`
- `states`: `pending`, `acknowledged`, `failed`, `not required`
- `purpose`: confirm whether the requested quality follow-up has been accepted or has failed and needs retry handling

### Clock Model

- `clock name`: `DE affiliate follow-up due window`
- `basis`: once global safety requests Germany affiliate review, the matter carries one active due window from configuration
- `initial proof configuration`: `72h from affiliate-review request`
- `resolved states`: review received, no-action decision, or not-triggered determination
- `non-goal`: this is not a general rules engine; it is one configuration-backed obligation model

## Five Operator Questions

The future workspace must answer these five questions in human terms for every replay:

1. Who owns this matter now?
2. Which clock is active, and how much time is left?
3. What is blocked right now?
4. Which downstream action is still open?
5. Why does the current decision exist?

## Golden Replay Scenarios

### Scenario 1: Happy Path

- `scenario id`: `de-affiliate-happy-path`
- `setup`: safety intake emits a signal that requires Germany affiliate review before a quality action request is routed
- `event sequence`:
  1. source stub emits the triaged signal reference
  2. Sentinel opens the matter and assigns Global Safety Ops
  3. Global Safety Ops requests Germany affiliate review and starts the `DE affiliate follow-up due window`
  4. Germany affiliate responds in time with the required evidence
  5. Sentinel routes one action to the Quality Action Queue Stub
  6. downstream stub returns `acknowledged`
- `expected workspace answers`:
  - owner: `Global Safety Ops`
  - active clock: `none; DE affiliate follow-up satisfied`
  - blocker: `none`
  - downstream action: `quality action acknowledged`
  - decision basis: `source signal + Germany affiliate evidence + routed quality action acknowledgement`

### Scenario 2: Delay Path

- `scenario id`: `de-affiliate-delay-path`
- `setup`: the same matter opens, but Germany affiliate review does not arrive before the due window becomes urgent
- `event sequence`:
  1. source stub emits the triaged signal reference
  2. Sentinel opens the matter and requests Germany affiliate review
  3. the `DE affiliate follow-up due window` remains active
  4. no affiliate evidence arrives on time
  5. downstream action cannot complete because required local evidence is still missing
- `expected workspace answers`:
  - owner: `Germany Affiliate Safety`
  - active clock: `DE affiliate follow-up due window active and nearing breach`
  - blocker: `waiting on Germany affiliate review evidence`
  - downstream action: `quality action pending`
  - decision basis: `source signal + open affiliate review request + no local evidence yet`

### Scenario 3: Failure / Retry Path

- `scenario id`: `de-affiliate-downstream-retry`
- `setup`: Germany affiliate review completes, but the downstream quality action acknowledgement fails once before a retry is issued
- `event sequence`:
  1. source stub emits the triaged signal reference
  2. Sentinel opens the matter and receives Germany affiliate evidence in time
  3. Sentinel routes one action to the Quality Action Queue Stub
  4. downstream stub returns `failed`
  5. Sentinel records the failure, schedules one retry, and reissues the downstream action
  6. the matter remains open until acknowledgement arrives
- `expected workspace answers`:
  - owner: `Global Safety Ops`
  - active clock: `none; DE affiliate follow-up satisfied`
  - blocker: `waiting on downstream quality acknowledgement after retry`
  - downstream action: `quality action pending after one failed attempt`
  - decision basis: `source signal + Germany affiliate evidence + downstream failure event + retry decision`

## S2.2 Implementation Handoff

`S2.2` should implement only this matter contract.

That means:

- deterministic replay only
- one matter at a time
- stable scenario ids matching this note
- outputs written in operator-answer terms, not only raw transport state
- no new product-definition work unless this contract proves internally inconsistent
