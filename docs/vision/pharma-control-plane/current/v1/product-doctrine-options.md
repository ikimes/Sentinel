# Sentinel Product Doctrine Options v1

Status: `draft strategy note`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Related notes:

- `docs/vision/pharma-control-plane/current/v1/strategic-product-thinking-lens.md`
- `docs/vision/pharma-control-plane/current/v1/vision.md`
- `docs/vision/pharma-control-plane/current/v1/system-design.md`
- `docs/vision/pharma-control-plane/current/v1/ui-low-fidelity-wireframes.md`

## Purpose

This note defines several possible product doctrines for Sentinel.

Each doctrine is built around a different answer to the question:

what is the deepest product truth of Sentinel?

The purpose is not to choose immediately.

It is to make the options explicit so the project can think more clearly about its center of gravity.

## Common Doctrine Template

Each doctrine is described using the same structure:

- deepest truth
- Sentinel exists to
- Sentinel is not
- Sentinel is best when
- Sentinel fails when
- Sentinel expands only when
- strategic strength
- strategic risk

## Doctrine A: Governed Matter Workspace

### Deepest truth

Sentinel is a governed matter workspace for cross-system regulated follow-up.

### Sentinel exists to

give operators one place to understand and work a regulated matter when ownership, due-state, evidence, and downstream actions are scattered across systems.

### Sentinel is not

- a system-of-record replacement
- a safety case system
- a dashboard layer
- a generic workflow builder

### Sentinel is best when

- a matter crosses more than one team
- a matter crosses more than one system
- no one system cleanly answers owner, clock, and evidence questions
- daily users need a shared operational workspace

### Sentinel fails when

- the real pain is only visibility
- the real pain is only case processing
- the matter workspace is less useful than the incumbent system itself
- the workflow is too infrequent to justify a dedicated workspace

### Sentinel expands only when

the same matter model and workspace answer can support another regulated follow-up workflow without inventing a new center of gravity.

### Strategic strength

This doctrine aligns well with the UI direction and gives Sentinel a strong human-facing identity.

### Strategic risk

It may understate the importance of the underlying coordination-state platform and make Sentinel look like "just another interface."

## Doctrine B: Coordination-State Layer

### Deepest truth

Sentinel is the coordination-state layer for regulated work that spans incumbent systems.

### Sentinel exists to

preserve the shared truth of who owns what, what is due, what evidence exists, and what downstream actions remain open when no incumbent system owns the full thread.

### Sentinel is not

- a new domain suite
- a generic integration platform
- an analytics warehouse
- a user-interface-only product

### Sentinel is best when

- multiple systems each own a piece of the real-world thread
- cross-system handoffs matter more than local workflow optimization
- stable shared primitives can be reused across repeated matters

### Sentinel fails when

- the buyer only wants nicer screens
- the same coordination model does not survive across repeated examples
- internal build can reproduce the needed state model cheaply enough

### Sentinel expands only when

new workflows can be expressed through the same core primitives: `Signal`, `ComplianceMatter`, `Obligation`, `ReportingClock`, `Decision`, `EvidenceArtifact`, `Transmission`, and `TimelineEvent`.

### Strategic strength

This doctrine gives Sentinel a strong architectural reason to exist and a clean expansion law.

### Strategic risk

It can become too infrastructure-oriented and weaken the product's visible identity for daily users.

## Doctrine C: Evidence-Grade Exception Control Surface

### Deepest truth

Sentinel is an evidence-grade exception control surface for regulated follow-up.

### Sentinel exists to

help organizations regain control when exceptions, follow-up obligations, and decision evidence become hard to manage across systems.

### Sentinel is not

- a broad orchestration suite
- a generalized compliance platform
- an AI-first product
- a visualization experiment

### Sentinel is best when

- the pain is concentrated in exceptions, escalations, and inspection readiness
- a buyer has low appetite for broad platform change but real appetite for a control surface
- operators repeatedly reconstruct why an exception is still open

### Sentinel fails when

- the workflow is too calm and routine
- inspection and exception pain are not meaningful
- the buyer already has strong exception control inside current systems

### Sentinel expands only when

new exception classes can be represented through the same evidence, ownership, and downstream-state model.

### Strategic strength

This doctrine is attractive for lower-appetite buyers because it packages Sentinel as a smaller, more buyable control layer.

### Strategic risk

It may make Sentinel feel narrower than the long-term company ambition and can over-center exception handling.

## Doctrine D: Context Engine For Regulated Work

### Deepest truth

Sentinel is a context engine that makes fragmented regulated work legible through provenance-backed explanation.

### Sentinel exists to

turn scattered evidence, system states, and decisions into trustworthy operational context that everyday workers can act on quickly.

### Sentinel is not

- a pure AI copilot
- a graph visualization tool
- a generic search layer
- a records system

### Sentinel is best when

- the human cost of understanding the situation is high
- context is fragmented across several systems
- AI summaries can be anchored to reliable provenance and state

### Sentinel fails when

- the buyer mainly needs control, not explanation
- provenance is too weak to support trusted summaries
- the context layer is more impressive than the workflow itself

### Sentinel expands only when

new workflows still benefit from the same pattern of provenance-backed context compression and action guidance.

### Strategic strength

This doctrine aligns strongly with the UI and AI-assisted interaction vision.

### Strategic risk

It can sound exciting while becoming too soft or too easy to imitate if the control model underneath is weak.

## Comparative Read

| Doctrine | Best center of gravity | Strongest strength | Biggest risk |
|---|---|---|---|
| `Governed Matter Workspace` | operator workflow | strongest visible product identity | can look like interface over someone else's truth |
| `Coordination-State Layer` | shared system truth | strongest reusable model and expansion law | can feel too infrastructural |
| `Evidence-Grade Exception Control Surface` | oversight and exception handling | most buyable for lower-appetite accounts | may narrow the company too much |
| `Context Engine For Regulated Work` | explanation and legibility | strongest match with AI-assisted UI vision | can become too soft or demo-driven |

## Recommended Current Doctrine

The strongest current doctrine is not any one option in pure form.

The most compelling current center is:

`Governed Matter Workspace` on the surface,
powered by a `Coordination-State Layer` underneath,
with `Evidence-Grade Exception Control` as the most credible near-term commercial entry.

In plain language:

Sentinel should behave like a governed matter workspace.

It should be architected like a coordination-state layer.

It may first be sold like an evidence-grade exception control surface.

That combination preserves:

- a strong user-facing identity
- a stable product core
- a more realistic early buying motion

## Recommended Doctrine Draft

### Deepest truth

Sentinel is an evidence-grade matter workspace for cross-system regulated follow-up.

### Sentinel exists to

help operators work one governed thread across systems when ownership, clocks, evidence, and downstream actions no longer live cleanly in one place.

### Sentinel is not

- a replacement for the source systems
- a generic workflow or ticketing layer
- a dashboard-first visibility tool
- a graph-first or AI-first product

### Sentinel is best when

- a recurring follow-up matter crosses teams and systems
- due-state and accountability become hard to see after intake
- evidence and decisions are fragmented
- one shared operator workspace is more useful than more reporting

### Sentinel fails when

- the pain is infrequent or tolerable
- one incumbent suite already owns the thread well enough
- buyers really want dashboards, replacement, or internal platform work
- the model cannot stay stable without customer-specific redesign

### Sentinel expands only when

the next workflow can reuse the same matter, obligation, evidence, and downstream-state model without changing the product's center of gravity.

## What To Watch As We Think More

As Sentinel evolves, the key doctrinal question is:

which part is the center and which parts are supporting machinery?

The project should watch for drift into:

- infrastructure without product identity
- UI polish without true product depth
- exception handling so narrow that expansion becomes artificial
- AI explanation that outruns control and provenance

## Practical Summary

The doctrine work is not about finding a clever slogan.

It is about deciding what Sentinel fundamentally is, so future workflow choices, UI choices, and expansion choices stay coherent.

Right now the strongest answer is:

Sentinel is an evidence-grade matter workspace for cross-system regulated follow-up.
