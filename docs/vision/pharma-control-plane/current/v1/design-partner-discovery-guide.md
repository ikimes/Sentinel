# Sentinel Design-Partner Discovery Guide v1

Status: `draft working note`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Related note:

- `docs/vision/pharma-control-plane/current/v1/design-partner-pilot-scorecard.md`

## Purpose

This guide is for discovery conversations with potential design partners.

Its job is not to pitch the whole Sentinel vision.

Its job is to test one narrow hypothesis:

does this organization have a recurring `post-intake cross-market safety follow-up matter` that is painful enough, repeatable enough, and bounded enough to justify a pilot?

## Core Rule

Do not let the conversation drift into:

- replacing the safety suite
- building a better dashboard
- broad AI strategy
- general workflow modernization
- enterprise master-data cleanup

Keep bringing the conversation back to one recurring matter type:

- already captured in an incumbent system
- now crossing teams, systems, and at least one jurisdiction boundary
- currently requiring manual ownership, due-state, and evidence reconstruction

## What We Need To Learn

By the end of discovery, we should be able to answer:

- what exact matter type hurts today
- how often it happens
- which systems are involved
- which teams are involved
- where ownership becomes unclear
- which clocks or deadlines matter
- what evidence has to be reconstructed manually
- who can sponsor an overlay pilot
- how the buyer would recognize success quickly

## Interview Structure

### 1. Confirm The Matter Type

Goal:

make sure the buyer can describe one recurring problem, not a grab bag of frustrations.

Questions:

- What is the exact kind of issue that repeatedly forces people to coordinate across systems after intake is already complete?
- Walk me through the last three examples of that issue.
- Where is the issue first captured today?
- At what point do local and global teams both become involved?
- Which markets most often make the workflow more complex?
- Which other systems usually need updates or follow-up once the issue is underway?

Strong signal:

- the buyer can describe one recurring matter type in concrete operational language

Weak signal:

- the buyer keeps bouncing between unrelated workflows

### 2. Map The Current Workflow

Goal:

understand how the work moves today and where it breaks.

Questions:

- After the issue is captured, what happens next step by step?
- Where does ownership move from one team to another?
- Which systems hold part of the story?
- Where do people leave the systems and switch to email, spreadsheets, chat, or meetings?
- What is hardest to answer quickly when leadership asks for status?

Strong signal:

- there is a repeatable handoff pattern and visible manual reconciliation

Weak signal:

- the workflow is mostly contained inside one product already

### 3. Confirm Ownership And Clock Pain

Goal:

verify that this is more than a reporting problem.

Questions:

- Which deadlines or reporting clocks matter for this matter type?
- How are those clocks tracked today?
- Who is accountable globally?
- Who is accountable locally?
- Where does ownership become ambiguous?
- What happens when one market is done and another is still open?

Strong signal:

- clocks and ownership are operationally important and currently hard to track cleanly

Weak signal:

- deadlines exist, but nobody relies on a shared coordination layer to manage them

### 4. Confirm Evidence And Inspection Pain

Goal:

verify that decision traceability is part of the pain.

Questions:

- If you had to explain why a recent decision was made, where would you pull that history from?
- What evidence lives in system records versus notes, email, attachments, or local trackers?
- How much effort does it take to reconstruct a complete thread for one issue?
- What creates stress during inspection, audit, or management review?

Strong signal:

- evidence and rationale are fragmented across tools

Weak signal:

- the system of record already preserves the whole inspection-ready thread

### 5. Test Overlay Readiness

Goal:

confirm the buyer wants coordination help, not replacement software.

Questions:

- Are you looking for a new system of record, or a way to coordinate across the systems you already have?
- Would value still exist if Sentinel never replaced your safety platform?
- How many systems would realistically be in scope for a first pilot?
- What would make an overlay acceptable from a governance or architecture standpoint?

Strong signal:

- the buyer explicitly wants an overlay and can tolerate a limited new integration surface

Weak signal:

- the buyer expects Sentinel to own case processing or submission transport

### 6. Confirm Sponsor And Pilot Readiness

Goal:

make sure there is a real path to a pilot.

Questions:

- Who would sponsor this pilot?
- Who would use it weekly?
- Which team would judge whether it worked?
- How would success be recognized in operational terms within the first pilot window?
- What is the smallest workflow slice that would still matter internally?

Strong signal:

- a named sponsor, user group, and evaluation path exist

Weak signal:

- enthusiasm is high but nobody can define a first slice or a success test

## Red-Flag Questions

Use these when the conversation sounds promising but blurry.

- If Sentinel only improved ownership, due-state, and evidence reconstruction, would that still matter?
- If Sentinel never replaced your current safety suite, would you still want the pilot?
- Can you name one matter type that already hurts every month or quarter?
- Can the pilot stay inside one recurring matter type with only a few systems in scope?

If the answer to most of these is no, the opportunity is probably too broad or too weak.

## Capture Template

Record discovery notes in this structure:

- `matter type`
- `where captured first`
- `systems in scope`
- `teams in scope`
- `jurisdictions in scope`
- `ownership failure pattern`
- `clock / deadline pain`
- `evidence reconstruction pain`
- `downstream actions`
- `current workaround`
- `executive sponsor`
- `weekly users`
- `pilot success definition`
- `major disqualifiers`

## Green / Yellow / Red Readout

### Green

- one recurring matter type is obvious
- at least two systems and two teams are clearly involved
- at least one jurisdiction boundary matters
- ownership and evidence pain are already visible
- the buyer wants an overlay
- a pilot sponsor exists

### Yellow

- the matter type is real but not yet tightly scoped
- the pain exists but is only partially operationalized
- sponsorship or pilot scope is still fuzzy

### Red

- the buyer really wants replacement software, analytics cleanup, or broad transformation
- no recurring matter type can be named
- the workflow does not genuinely cross systems and jurisdictions
- no one can define success in operational terms

## Exit Decision

Advance to pilot shaping only if all of these are true:

- the exact matter type is recurring
- the pain is already visible
- the workflow crosses teams, systems, and at least one jurisdiction boundary
- the buyer wants an overlay
- success can be recognized through ownership, clock, evidence, and downstream-completion clarity

If any of those are missing, keep narrowing or walk away.
