# Sentinel UI Low-Fidelity Wireframes v1

Status: `draft`

Package root:

- `docs/vision/pharma-control-plane/README.md`

## Purpose

These wireframes translate the current first proof workflow into visible operator surfaces.

The workflow remains:

- a safety-relevant issue is already captured in an incumbent system
- follow-up may affect more than one market
- global and local teams now share responsibility
- another incumbent system may need an update
- ownership, due-state, and evidence would otherwise be reconstructed across notes, email, spreadsheets, and meetings

The design rule is:

every visual interaction should answer an operational question, not merely reveal more structure.

## Core Questions The UI Must Answer

- who owns this matter right now
- which clocks are active
- what is blocked
- which downstream systems have acted
- why the current decision exists

## Screen Set

The first low-fidelity set uses four screens:

- `Matter workspace`: default working view for everyday operators
- `Path drill-down`: stage-by-stage explanation of the matter journey
- `Systems board`: downstream completion and exception state
- `Expert graph mode`: focused dependency view for outages and routing failures

The graph is intentionally not the default screen.

Implementation note:

- the default workspace should remain Blazor-first
- the expert graph mode may use targeted JavaScript interop where specialized visualization behavior is genuinely needed

## Global Layout Pattern

All primary screens should share the same mental model:

- top summary strip for immediate orientation
- center workspace for the active question
- right context window for AI-compressed explanation with provenance
- lower supporting views for timeline, evidence, and system state

## Screen 1: Matter Workspace

Best for:

- who owns this right now
- which clocks are active
- what is blocked
- what happened most recently

```text
+--------------------------------------------------------------------------------------------------+
| SENTINEL | Matter: AE-47291 | Product: X | Severity: High | Status: In Follow-Up | 2 Markets   |
+--------------------------------------------------------------------------------------------------+
| Owner Now: Global Safety Ops | Next Due: EU 18h | Blockers: 1 | Systems Waiting: 2 | AI: Verified|
+--------------------------------------------------------------------------------------------------+
|                                                                                                  |
|  JOURNEY PATH                                                                                    |
|  [Captured]----[Triaged]----[Cross-Market Follow-Up]----[Local Review]----[Downstream Update]  |
|      done          done              active                    waiting              waiting       |
|                                                                                                  |
|  RESPONSIBILITY LANES                                                                            |
|  Global Safety       [ Owns Matter ]------------------------------->[ Await Local Input ]        |
|  Local Affiliate     [ Notified ]----------------[ Needs Review ]----------------------->        |
|  Regulatory Coord.   [ Standby ]-------------------------------------------------------->        |
|  Quality Liaison     [ Not Needed ]----------------------------------------------------->        |
|                                                                                                  |
|  CLOCK RAIL                                                                                      |
|  [EU Clock: 18h remaining]   [UK Clock: not triggered]   [CA Clock: review pending]            |
|                                                                                                  |
|  OPEN ITEMS                                                                                      |
|  - confirm whether local follow-up creates reportable action in Germany                          |
|  - wait for downstream quality acknowledgement                                                   |
|                                                                                                  |
|---------------------------------------------------------+----------------------------------------|
| TIMELINE / EVIDENCE / SYSTEMS                           | CONTEXT WINDOW                         |
|                                                         |                                        |
|  10:02 triage completed                                 | Selected: Cross-Market Follow-Up      |
|  10:30 owner assigned to global safety                  |                                        |
|  11:05 Germany affiliate requested review               | What happened                          |
|  11:22 quality update queued                            | The issue cleared initial triage and   |
|                                                         | now requires local-market review plus |
|                                                         | a downstream quality-system update.   |
|                                                         |                                        |
|                                                         | Why it matters                         |
|                                                         | One active EU clock depends on local  |
|                                                         | confirmation before downstream steps. |
|                                                         |                                        |
|                                                         | Evidence                               |
|                                                         | - triage note                          |
|                                                         | - source record link                   |
|                                                         | - prior similar matter                 |
|                                                         |                                        |
|                                                         | AI summary provenance                  |
|                                                         | 3 sources, human-reviewed             |
+--------------------------------------------------------------------------------------------------+
```

### Interaction Notes

- clicking a path stage updates the context window
- clicking an owner lane filters timeline and evidence to that team's activity
- clicking a clock opens the specific jurisdiction and rule basis

## Screen 2: Path Drill-Down

Best for:

- what is blocked
- where the matter is stuck
- which step caused the current delay
- how one stage depends on another

```text
+--------------------------------------------------------------------------------------------------+
| Matter AE-47291 > Path View                                                                      |
+--------------------------------------------------------------------------------------------------+
|                                                                                                  |
| [1] Captured      [2] Triaged      [3] Follow-Up      [4] Local Review      [5] Downstream      |
|     complete           complete         active             waiting               waiting          |
|                                                                                                  |
|                                +-------------------------+                                       |
|                                | 3. FOLLOW-UP ACTIVE     |                                       |
|                                | Owner: Global Safety    |                                       |
|                                | Started: 11:05          |                                       |
|                                | Blocked by: Local input |                                       |
|                                +-------------------------+                                       |
|                                   |                |                                             |
|                                   |                +-------------------------------+             |
|                                   |                                                |             |
|                    +---------------------------+                   +---------------------------+  |
|                    | Germany affiliate review  |                   | Quality system update     |  |
|                    | status: waiting           |                   | status: queued            |  |
|                    | due: 18h                  |                   | waits on local decision   |  |
|                    +---------------------------+                   +---------------------------+  |
|                                                                                                  |
|---------------------------------------------------------+----------------------------------------|
| PATH EVENTS                                              | CONTEXT WINDOW                         |
|                                                          |                                        |
| - triage marked as cross-market                          | Selected node: Germany affiliate       |
| - Germany identified as affected market                  |                                        |
| - local review request sent                              | What happened                          |
| - quality system update prepared                         | Local affiliate input is required to   |
|                                                          | determine whether downstream quality   |
|                                                          | action remains informational or formal.|
|                                                          |                                        |
|                                                          | What is blocked                        |
|                                                          | Downstream quality submission waits on |
|                                                          | this response.                         |
|                                                          |                                        |
|                                                          | Next expected action                   |
|                                                          | Local affiliate review by 08:00 CET   |
+--------------------------------------------------------------------------------------------------+
```

### Interaction Notes

- clicking any node should answer why that stage exists, what it gates, and what happens next
- clicking a dependency line should explain the dependency rather than only highlight it
- users should be able to collapse completed stages so the active path stays readable

## Screen 3: Systems Board

Best for:

- which downstream systems have acted
- which transmissions are pending or failed
- where an outage or acknowledgement failure lives

```text
+--------------------------------------------------------------------------------------------------+
| Matter AE-47291 > Systems                                                                         |
+--------------------------------------------------------------------------------------------------+
| SYSTEM / ACTION                     | STATE         | OWNER              | LAST EVENT            |
|-------------------------------------+---------------+--------------------+-----------------------|
| Safety Platform source case         | linked        | Global Safety      | synced 11:01         |
| Affiliate workflow inbox            | pending       | Germany Affiliate  | notified 11:05       |
| Quality system follow-up            | queued        | Quality Liaison    | waiting on decision  |
| Regulatory tracker                  | not needed    | --                 | --                   |
| Evidence store                      | current       | Sentinel           | added note 11:22     |
| Outbound notification service       | sent          | Sentinel           | delivered 11:23      |
| Message ledger path                 | degraded      | Platform Ops       | retrying 11:27       |
| Dead-letter review                  | clear         | Platform Ops       | none                 |
+--------------------------------------------------------------------------------------------------+
|                                                                                                  |
| STREAM PATH                                                                                      |
| Source Case ----> Matter Opened ----> Affiliate Notify ----> Quality Queue ----> Ack Pending    |
|    ok                ok                 ok                    retrying             blocked        |
|                                                                                                  |
|---------------------------------------------------------+----------------------------------------|
| EXCEPTIONS                                               | CONTEXT WINDOW                         |
|                                                          |                                        |
| - quality queue waiting on local decision                | Selected: Message ledger path          |
| - one retry in outbound ack path                         |                                        |
| - no dead-letter events                                  | What happened                          |
|                                                          | The outbound path retried once after   |
|                                                          | a transient integration failure.       |
|                                                          |                                        |
|                                                          | Operational impact                     |
|                                                          | No data loss detected. Quality-system  |
|                                                          | acknowledgement is delayed.            |
|                                                          |                                        |
|                                                          | Suggested next action                  |
|                                                          | Monitor until retry threshold reached. |
+--------------------------------------------------------------------------------------------------+
```

### Interaction Notes

- clicking a system row should reveal authoritative links, last transmission state, and required next action
- clicking the stream path should open a compressed ledger story, not raw queue internals by default
- operators should be able to switch between `business state` and `integration state`

## Screen 4: Expert Graph Mode

Best for:

- outage diagnosis
- dependency tracing
- focused exploration around one failure or bottleneck

This should be an expert mode, not the default workspace.

```text
+--------------------------------------------------------------------------------------------------+
| Matter AE-47291 > Expert Graph                                                                    |
+--------------------------------------------------------------------------------------------------+
| Filters: [Active only] [Systems] [Evidence] [Failures] [Show 1-hop neighbors]                    |
|                                                                                                  |
|                  (Germany Review)                                                                 |
|                         |                                                                         |
|                         | blocks                                                                  |
|                         v                                                                         |
| (Source Case) ---> (Matter) ---> (Quality Queue) ---> (Ack Pending)                              |
|      |               |                |                 |                                         |
|      |               |                |                 +--> (Retry Event)                        |
|      |               |                +--> (Evidence Note)                                        |
|      |               +--> (EU Clock)                                                              |
|      +--> (Triage Note)                                                                           |
|                                                                                                  |
| Legend:                                                                                           |
|  circle = state node   square = system node   diamond = decision or clock                         |
|                                                                                                  |
|---------------------------------------------------------+----------------------------------------|
| NEIGHBOR LIST                                            | CONTEXT WINDOW                         |
|                                                          |                                        |
| - Matter -> EU Clock                                     | Selected edge: Matter -> Quality Queue |
| - Matter -> Germany Review                               |                                        |
| - Quality Queue -> Ack Pending                           | Why this link exists                   |
|                                                          | Matter resolution requires a quality   |
|                                                          | system update after local review.      |
|                                                          |                                        |
|                                                          | Source basis                           |
|                                                          | Decision 11:18, queue event 11:22     |
|                                                          |                                        |
|                                                          | Risk if delayed                        |
|                                                          | Follow-up remains incomplete and the   |
|                                                          | matter cannot be closed.               |
+--------------------------------------------------------------------------------------------------+
```

### Interaction Notes

- graph mode should open centered on the selected failure or dependency, not on the entire enterprise network
- one click should reveal linked clocks, evidence, and downstream effects
- users should always be able to jump back to path view or systems view

## Recommended Default Navigation

```text
[Matter Workspace] [Path] [Systems] [Timeline] [Evidence] [Graph]
```

Recommended behavior:

- everyday operators land in `Matter Workspace`
- deeper operational reasoning happens in `Path`
- cross-system completion and outages live in `Systems`
- `Graph` is a deliberate expert drill-down

## Context Window Contract

Every main screen uses the same context window structure.

```text
Selected item
What happened
Why it matters
Current owner
Active clocks
Blocked / next action
Supporting evidence
AI summary provenance
```

This consistency matters more than the specific visual treatment.

## Wireframe Takeaways

The first UI should feel less like a generalized network map and more like an operational workspace with explainable drill-downs.

The strongest design pattern for Sentinel is:

- visible path
- visible ownership
- visible clocks
- visible system completion state
- AI-compressed context on click

That is the most direct way to make orchestration state digestible for everyday workers without hiding the source trail.
