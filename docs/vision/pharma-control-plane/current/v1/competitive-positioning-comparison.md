# Sentinel Competitive Positioning Comparison v1

Status: `draft analysis note`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Related notes:

- `docs/vision/pharma-control-plane/current/v1/vision.md`
- `docs/vision/pharma-control-plane/current/v1/system-design.md`
- `docs/vision/pharma-control-plane/current/v1/feasibility-and-entry-framework.md`
- `docs/vision/pharma-control-plane/current/v1/beliefs-doubts-and-must-prove-next.md`
- `docs/vision/pharma-control-plane/current/v1/ui-low-fidelity-wireframes.md`

## Purpose

This note pressure-tests Sentinel against the most likely alternatives a buyer could choose instead:

- extend an incumbent suite
- build on ServiceNow or an internal platform
- rely on analytics and reporting layers

The goal is not to prove Sentinel wins automatically.

The goal is to answer a harder question:

if the problem is real, why should Sentinel exist as a distinct product at all?

## Short Answer

The UI-backed version of Sentinel is stronger than the earlier abstract pitch.

It now looks like:

- a coordination-state data platform underneath
- an operator workspace on top
- an AI-assisted context layer that compresses evidence and system state into operational answers

That is more distinct than "workflow plus dashboards."

It is still not fully differentiated from internal build or suite extension.

## Comparison Frame

The first workflow remains:

- a safety-relevant issue is already captured in an incumbent system
- follow-up may affect more than one market
- global and local teams now share responsibility
- another incumbent system may need an update
- ownership, due-state, and evidence would otherwise be reconstructed across notes, email, spreadsheets, and meetings

The comparison question is:

which option best helps an operator answer:

- who owns this now
- which clocks are active
- what is blocked
- which systems have acted
- why the current decision exists

## Comparison Matrix

| Option | What the buyer gets | What it does well | Where it breaks on the first Sentinel workflow | UI / operator experience answer | Strategic risk for Sentinel |
|---|---|---|---|---|---|
| `Extend incumbent suite` | More workflow or reporting inside an existing safety or regulatory platform | Strong domain depth, lower political friction, easier alignment with existing system of record | Often stops at suite boundary; cross-system ownership, non-native evidence, and downstream completion can still fragment | Usually strongest inside the suite itself, weaker when the operator needs one cross-system matter workspace | If one suite already covers the handoff well enough, Sentinel should probably not exist there |
| `Build on ServiceNow or internal platform` | Custom overlay shaped to local process | Flexible, politically acceptable, can reuse existing enterprise tooling and teams | Can become slow, services-heavy, and customer-specific; provenance, clock logic, and operator UX may be uneven | Can produce working screens, but often drifts toward ticketing plus custom reports unless purpose-built | This is the most dangerous substitute because it can look "good enough" and uses existing budget |
| `Analytics-only approach` | Dashboards, monitoring, KPIs, and status reporting | Great for visibility, aggregation, and leadership reporting | Does not own matter state, decision provenance, accountable handoffs, or downstream coordination | Good for seeing that something is wrong, weak at helping an operator resolve it | If buyer pain is really visibility only, Sentinel loses |
| `Manual coordination around existing systems` | No new product; email, spreadsheets, meetings, local trackers | Cheap in the short term, familiar, flexible for edge cases | Fragile ownership, invisible clocks, weak audit reconstruction, slow exception handling | No real operator workspace; people reconstruct the story manually | If this pain remains tolerable, demand may never form |
| `Sentinel` | A thin overlay for governed cross-system matter coordination | Purpose-built for ownership, clocks, evidence, downstream state, and operator-readable context | Must prove stable primitives, limited-integration value, and a real economic buyer | Distinct if the workspace consistently turns messy orchestration state into actionable answers with provenance | If the product feels like generic workflow, generic graphing, or generic reporting, it loses its reason to exist |

## What Sentinel Is Actually Selling

Sentinel is not just selling orchestration in the abstract.

It is selling a specific combination:

- a `ComplianceMatter` model that survives across systems
- jurisdiction-aware obligations and reporting clocks
- evidence-backed decisions and attestations
- downstream coordination state
- an operator workspace that makes this legible without requiring users to inspect raw system internals

That means the product offer is not:

- "we connect systems"
- "we give you dashboards"
- "we add AI summaries"

It is:

we preserve and explain the governed thread between systems when no incumbent tool cleanly owns it.

## UI Answer Versus Competitors

The UI wireframes help Sentinel answer a question that the earlier docs did not answer clearly:

what does the product feel like in daily use?

The current answer is:

- `Matter Workspace` for ownership, clocks, blockers, and recent activity
- `Path` for dependency and blockage reasoning
- `Systems` for downstream completion and outage visibility
- `Context Window` for compressed explanation with provenance
- `Graph` only as expert drill-down, not as the default surface

This is a stronger position than a generic graph or workflow tool because it is explicitly built around the five first-matter questions.

That distinction matters:

- an incumbent extension usually optimizes for its own native records and workflow
- a ServiceNow-style build often optimizes for ticketing and process control
- an analytics layer optimizes for visibility
- Sentinel is trying to optimize for governed cross-system comprehension and action

That is a more distinct identity than before.

## Data Platform Answer Versus Competitors

Sentinel's data-platform story is also clearer now.

It should own only the coordination-state primitives required to support the operator workspace:

- `Signal`
- `ComplianceMatter`
- `Obligation`
- `ReportingClock`
- `WorkItem`
- `Decision`
- `EvidenceArtifact`
- `Transmission`
- `TimelineEvent`

This is important because it sets Sentinel apart from:

- a suite extension, which usually centers its own domain record
- a data platform build, which often centers pipelines and reporting datasets
- an analytics tool, which centers projections but not authoritative coordination state

Sentinel's data platform should therefore be judged by whether it can answer the operator questions repeatedly with the same core primitives.

If not, it is drifting toward custom integration work.

## Is Sentinel Orchestrating In A Valuable Way

Conditionally, yes.

The value is not simply that Sentinel routes messages or links systems.

The value is that Sentinel tries to preserve three things at the same time:

- accountable ownership
- inspectable evidence
- current downstream completion state

across a matter that no single incumbent system owns end to end.

That is valuable when:

- more than one system matters
- more than one team matters
- timing and evidence matter operationally
- operators need more than dashboards

That is not valuable enough when:

- one suite already covers the handoff
- the real pain is only reporting
- the workflow is too infrequent
- the organization prefers internal build regardless of product fit

## Is The Niche Distinct Enough

The niche is now more distinct than it was before the UI work, but it is still a hypothesis rather than a proven category.

The strongest current identity is:

an evidence-grade operator workspace for cross-system compliance matters

or, even more narrowly:

the coordination and context layer for post-intake safety follow-up when ownership, clocks, evidence, and downstream actions span multiple systems

That is distinct because it combines:

- cross-system matter coordination
- evidence-grade provenance
- operator-facing context compression

Many competitors do one or two of those well.

Sentinel is attempting to do all three in one narrow workflow.

That is the best current argument for distinct identity.

## Skeptic Questions Revisited

### 1. Are we providing a clear UI answer

More than before, yes.

The wireframes finally answer what the product does on a normal workday.

The UI answer is:

- not a graph-first experience
- not a dashboard-first experience
- not a ticket-first experience

It is a matter-first operational workspace with explainable drill-down.

### 2. Are we providing a clear data-platform answer

Partly yes.

The current docs now imply a coherent coordination-state platform.

The main remaining risk is whether those primitives stay stable across buyers without turning into services.

### 3. Are we orchestrating in a way buyers would value

Potentially yes, but only if the chosen matter type is recurring and painful enough.

The UI improves plausibility.

It does not prove demand density.

### 4. Are we distinct enough against competitors

More than before, yes.

But the distinctness is still fragile.

If Sentinel is described carelessly, it collapses into:

- workflow layer
- dashboard layer
- graph layer
- AI summary layer

Its distinctness only survives if the coordination-state model and operator workspace stay tightly bound together.

### 5. What still feels unresolved

These still remain the hardest open questions:

- who can actually buy this
- why buy Sentinel instead of extending current stack
- whether the first workflow recurs often enough
- whether the product can prove value with limited integrations

The UI work improved product identity.

It did not eliminate market risk.

## Practical Working Conclusion

The new UI-backed presentation makes Sentinel feel more like a real product and less like an abstract systems thesis.

That is meaningful progress.

My current best honest read is:

- Sentinel now has a clearer product identity
- the orchestration value is more legible
- the niche looks more distinct than before
- the commercial proof is still not earned

So the right conclusion is not:

"the vision is validated"

It is:

"the product now has a shape worth validating against real buyers."
