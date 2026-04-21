# Sentinel Design-Partner Pilot Scorecard v1

Status: `draft research note`

Package root:

- `docs/vision/pharma-control-plane/README.md`

## Purpose

This note turns the current Sentinel wedge into a practical design-partner filter.

It answers four questions:

- what exact recurring matter type Sentinel should bet on first
- why that matter type is a better first bet than nearby alternatives
- what conditions make a design partner worth pursuing
- what success criteria a serious design partner should recognize immediately

## First Bet

The first recurring matter type Sentinel should bet on is:

`post-intake cross-market safety follow-up matter`

In plain language:

- a safety-relevant issue has already been captured in an incumbent intake or safety system
- initial triage indicates that follow-up may affect more than one market
- global safety operations and at least one local affiliate now share responsibility
- another incumbent system may need an update, handoff, or routed submission
- ownership, due-state, and evidence would otherwise be managed through system notes, email, spreadsheets, and meetings

This is the first bet because it is narrow enough to productize and painful enough to matter.

## What Counts As This Matter Type

The matter type should include cases like:

- a product concern or adverse-event-related issue that is already captured and now needs cross-market follow-up
- a safety-relevant issue where local and global teams both need visibility into obligations and ownership
- a matter where one market has an active follow-up clock while another market is still evaluating the same underlying issue
- a safety-led issue that requires a downstream update to a regulatory or quality-adjacent system without turning Sentinel into that system

## What Does Not Count

This first matter type should **not** quietly expand into:

- primary intake capture
- full case processing or case authoring
- medical coding
- gateway or submission transport ownership
- general regulatory lifecycle management
- full quality investigation or CAPA execution
- generic analytics cleanup or workflow automation

If the first design partner is really asking for one of those, Sentinel is drifting away from the chosen wedge.

## Why This Is The Right First Bet

### 1. It starts after incumbent strengths

The selected matter begins after an issue has already been captured in an incumbent system. That avoids direct competition with safety suites on their strongest ground.

### 2. It creates visible coordination pain

This matter type naturally creates:

- split ownership
- different clocks by market
- fragmented evidence
- multiple system handoffs
- recurring status reconstruction

That gives Sentinel a pain signature a buyer can already recognize.

### 3. It is narrow enough to measure

The first version can be judged by whether it improves one recurring post-intake coordination problem, rather than by whether it modernizes PV as a whole.

### 4. It still leaves room to expand later

If the same coordination model works here, it can later be tested against nearby adjacencies.

That is very different from trying to prove the entire future company in the first pilot.

## Why Nearby Alternatives Are Worse First Bets

### Alternative: AI intake or AI triage

Why worse first:

- too easy to collide with incumbent vendor roadmaps
- easier for buyers to interpret as feature competition
- risks making AI the wedge instead of coordination-state control

### Alternative: full safety case orchestration

Why worse first:

- collides directly with mature safety platforms
- invites case-authoring, coding, and submission expectations
- makes the product look like a replacement suite too early

### Alternative: regulatory-change or RIM-adjacent coordination

Why worse first:

- still plausible later, but weaker as the first proof because it is less tightly anchored to one recurring post-intake safety problem
- can drift into broad regulatory lifecycle expectations quickly

### Alternative: quality investigation coordination

Why worse first:

- too easy to slide into eQMS or CAPA platform expectations
- less aligned with the current PV-first wedge and supporting market analysis

## Design-Partner Entry Criteria

A prospective design partner is worth pursuing when most of these are true:

- the company already runs a serious safety platform and at least one other relevant incumbent system
- the candidate matter type already occurs with enough frequency to matter operationally
- one recurring post-intake issue truly crosses at least two teams and at least two systems
- the workflow crosses at least one meaningful jurisdiction boundary
- local and global ownership is genuinely split
- the current process requires spreadsheet tracking, email follow-up, meeting-driven reconciliation, or custom reporting to stay aligned
- missed or near-missed deadlines, unclear ownership, or audit-prep pain are already recognized internally
- there is a sponsor with authority to add a coordination overlay without first replacing the incumbent stack

## Pilot Disqualifiers

The candidate is probably **not** worth pursuing if any of these dominate:

- the buyer is still trying to finish its first major safety-platform rollout
- the requested solution is really a better dashboard or warehouse
- the requested solution is really case-processing replacement
- the first workflow does not cross at least one meaningful jurisdiction boundary
- the buyer cannot point to one recurring matter type that already hurts today
- the buyer expects Sentinel to own submission transport or gateway certification
- the workflow is so bespoke that the core matter model changes materially for that one customer
- no business owner can say how success would be recognized in operational terms

## Pilot Scope Rule

The pilot should prove one recurring matter type only.

That means the pilot should be able to say:

- this is the exact matter type
- these are the systems in scope
- these are the teams in scope
- these are the jurisdiction differences that matter
- these are the downstream actions we must coordinate

If the pilot cannot be described that simply, it is too broad.

## Pilot Success Criteria

The pilot should be considered successful only if a design partner can say "yes" to most of these statements after using it on the chosen matter type.

### Operational success

- we can tell who owns a matter right now without asking across multiple systems or inboxes
- we can see which clocks are active and why
- we can tell which downstream actions are still open
- we no longer need spreadsheet or meeting-based reconciliation to understand current state

### Evidence and inspection success

- we can see why the current decision was made
- the supporting evidence is preserved in one inspectable thread
- we can reconstruct the decision path without stitching together history from several tools

### Coordination success

- local and global teams can work the same matter without losing accountability
- downstream updates to incumbent systems are visible as pending, completed, or not required
- one market being complete while another remains open is visible without manual reconstruction

### Product-shape success

- Sentinel added value without replacing the safety platform
- the pilot required only a limited number of focused integrations
- the core matter model remained stable across repeated instances of the chosen matter type

## Immediate Pilot Metrics

The first design partner should be able to evaluate Sentinel with metrics like:

- time to identify current owner
- time to determine active obligations and due windows
- time to reconstruct decision history for one matter
- number of manual touchpoints needed to understand current state
- number of open downstream actions visible without cross-system searching
- number of matters that can be coordinated without resorting to spreadsheets

The exact numeric targets should be negotiated with the design partner, but the metric categories should remain stable.

## Not Worth Building Signals

Even if the pilot sounds exciting, it is probably not worth building first if:

- the sponsor keeps pulling the conversation back toward full suite replacement
- the first matter type keeps changing during discovery
- the buyer cannot tell whether the pain is workflow, data, reporting, or organizational politics
- the team would need many bespoke core entities before the first workflow becomes usable
- the implementation would require many integrations before any value can be observed
- the strongest buyer enthusiasm is for the long-term vision, not the first recurring matter type

## Practical Decision Rule

The first design-partner pilot is worth doing if all of the following are true:

- the exact matter type is recurring
- the pain is already visible
- the workflow crosses teams, systems, and at least one jurisdiction boundary
- the sponsor wants an overlay, not a replacement
- the first proof can be recognized through ownership, clock, evidence, and downstream-completion clarity

If any of those are missing, Sentinel should probably keep narrowing rather than forcing a pilot.
