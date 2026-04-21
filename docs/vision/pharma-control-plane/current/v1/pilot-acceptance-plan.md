# Sentinel Pilot Acceptance Plan v1

Status: `draft working note`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Related notes:

- `docs/vision/pharma-control-plane/current/v1/design-partner-pilot-scorecard.md`
- `docs/vision/pharma-control-plane/current/v1/vision.md`
- `docs/vision/pharma-control-plane/current/v1/system-design.md`

## Purpose

This note defines what a first design-partner pilot must prove for Sentinel's chosen wedge.

It does two things:

- turns the chosen matter type into concrete pilot acceptance criteria
- maps those acceptance criteria to backend capabilities Sentinel would need first

## Pilot Scope

The pilot should prove one recurring matter type only:

`post-intake cross-market safety follow-up matter`

The pilot starts when:

- a safety-relevant issue is already captured in an incumbent intake or safety system
- initial triage indicates that follow-up may affect more than one market
- global and local teams now share responsibility

The pilot ends when:

- required downstream actions are visible as pending, completed, or not required
- the decision and evidence path is preserved in one inspectable thread

## Pilot Goal

The pilot goal is not:

- replace the safety suite
- replace submission transport
- modernize all PV operations

The pilot goal is:

prove that Sentinel can make one recurring post-intake coordination problem materially easier to manage without replacing incumbent systems of record.

## Required Pilot Outcomes

The pilot should prove these five outcomes on the chosen matter type.

### 1. Matter visibility

The team can see one governed matter for the issue instead of reconstructing it across tools.

### 2. Ownership and clock clarity

The team can see who owns the matter now, which clocks are active, and why.

### 3. Evidence and decision traceability

The team can see the decision path and supporting evidence without manual history stitching.

### 4. Downstream coordination state

The team can see which downstream actions are still open and which systems have already acted.

### 5. Overlay integrity

Sentinel adds this value without becoming the system of record for intake, case processing, or authority submission.

## Acceptance Criteria And Backend Capability Map

| Acceptance area | Pilot acceptance test | Backend capability needed first | Current foundation read |
|---|---|---|---|
| signal ingress | Sentinel can accept a signal reference or update from an incumbent system and preserve provenance | durable intake API, request acceptance, append-only intake event recording | partly present in current Phase A backbone |
| matter opening or linking | Sentinel can open or update one `ComplianceMatter` for the recurring issue | matter identity model, correlation logic, external-record linking | new capability required |
| ownership clarity | Sentinel can show current accountable party and change history | responsible-party model, work-state transitions, actor attribution | new capability required |
| clock visibility | Sentinel can show active due windows tied to jurisdiction or authority context | obligation model, reporting-clock state, due-state projection | new capability required |
| evidence thread | Sentinel can preserve rationale, attachments, notes, and timeline history for one matter | append-only timeline, evidence artifacts, decision events | foundation partly present; domain extension required |
| downstream coordination | Sentinel can show requested downstream actions as pending, completed, or not required | transmission / routing state, downstream action tracking | new capability required |
| projection usability | Operators can query current owner, due-state, and downstream completion without manual reconstruction | read models and focused operator projections | foundation partly present; richer projections required |
| state separation | transport truth, workflow truth, and obligation truth remain separate | explicit domain status models and projections | transport truth present; other layers new |
| auditability | Replay-safe history remains intact as the matter evolves | append-only ledger / timeline discipline, durable async processing | strongly aligned with current Phase A backbone |

## Minimal Backend Capability Set

The smallest credible backend for the pilot should support:

- signal-reference ingestion from an incumbent system
- `ComplianceMatter` create / link behavior
- `Obligation` and `ReportingClock` state
- `ResponsibleParty` and `WorkItem` state
- `Decision` and `EvidenceArtifact` recording
- `Transmission` or downstream-action state
- operator-facing read models for owner, clock, evidence, and downstream completion

If the pilot requires materially more than this before value can be seen, the scope is probably too broad.

## Explicitly Out Of Scope For The Pilot

The pilot should not require:

- primary intake capture
- case authoring
- medical coding
- authority submission transport execution
- full quality investigation execution
- generalized workflow engine behavior
- broad analytics or warehouse replacement

If a design partner insists on these being part of the first proof, the pilot should probably be declined or re-scoped.

## Suggested Pilot Read Models

The first backend should expose focused reads such as:

- `matter overview`
  - current owner
  - current due-state
  - active jurisdictions
  - active downstream actions
- `matter timeline`
  - signal received
  - obligation derived
  - owner changed
  - decision recorded
  - downstream action requested
  - downstream action completed
- `work queue`
  - matters by current owner
  - matters with active clocks
  - matters with overdue follow-up
- `coordination exceptions`
  - missing owner
  - missing evidence
  - overdue obligation
  - downstream action still open

## Pilot Acceptance Questions

At pilot review time, a design partner should be able to answer yes to most of these:

- Can we tell who owns a matter right now without cross-system searching?
- Can we tell which clocks are active and why?
- Can we tell which downstream actions are still open?
- Can we reconstruct the current decision path from one place?
- Can we see one market complete while another remains open?
- Did Sentinel add this value without replacing the incumbent safety platform?

If the answer is no to most of these, the pilot did not prove the wedge.

## Pilot Exit Metrics

The pilot should leave behind measurable evidence such as:

- reduced time to identify current owner
- reduced time to identify active obligations and due windows
- reduced time to reconstruct decision history for one matter
- fewer manual touchpoints needed to understand current state
- more downstream actions visible without cross-system searching
- fewer matters managed through spreadsheet fallback

The exact numeric targets should be agreed with the design partner before the pilot starts.

## Continue / Stop Decision

Continue after the pilot only if:

- the recurring matter type was real and frequent enough
- the matter model remained stable across repeated examples
- the backend could prove ownership, clock, evidence, and downstream-completion clarity
- the value appeared without expanding into suite-replacement scope

Stop or re-scope if:

- the matter type kept changing
- too many bespoke core entities were needed
- the pilot only produced better reporting, not better coordination
- the design partner really wanted replacement software instead of an overlay
