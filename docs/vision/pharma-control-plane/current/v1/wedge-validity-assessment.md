# Sentinel Wedge Validity Assessment v1

Status: `draft research note`

Package root:

- `docs/vision/pharma-control-plane/README.md`

## Purpose

This note pressure-tests the central Sentinel thesis at the level that matters most:

is the promising version of Sentinel actually a valid wedge, or is it just a good-sounding abstraction?

The wedge under test is:

> Sentinel is a narrow, painful, cross-system orchestration wedge for a buyer who already has serious systems and still cannot cleanly manage ownership, obligations, evidence, and decisions across them.

This note is intentionally blunter than the main vision draft.

It separates:

- whether the underlying buyer problem is real
- whether it appears repeatable
- whether it looks productizable
- whether incumbents are already absorbing the same space
- whether Sentinel can plausibly enter without pretending the market is empty

## Short Verdict

This wedge looks **conditionally valid**.

More specifically:

- the underlying problem appears real
- it appears repeatable in large, multinational, highly regulated operating environments
- it appears more urgent because of AI, but it did not originate with AI
- it is only product-valid if Sentinel stays narrow and matter-centric
- it is not obviously category-empty or commercially easy

So the right reading is:

the wedge is promising enough to keep pursuing, but only as a disciplined control-plane overlay on top of existing systems.

## Why The Problem Looks Real

### 1. Official vendor materials repeatedly describe silo and coordination pain

Veeva's recent PV transformation write-up says the industry is moving beyond manual and siloed compliance systems and processes. The same page says MSD was managing more than 30 siloed technology systems, requiring reconciliation and costly upgrades, while Novo Nordisk was pursuing a global safety database to automate data flow, eliminate custom integrations, and reduce manual reconciliation.

Relevant source:

- [Veeva - 4 Insights on PV Transformation](https://www.veeva.com/resources/4-insights-on-pv-transformation/)

### 2. Global-local affiliate coordination still shows up as a real operational burden

Veeva's regulatory affiliate-collaboration article says traditional document-package distribution to affiliates in non-eCTD markets limits downstream visibility and increases compliance risk. It highlights the importance of clearer roles, responsibilities, and accountability with local affiliates and partners.

ArisGlobal's regulatory white paper similarly says affiliates may fail to record actions promptly because of low local adoption of a global RIMS, which leaves headquarters struggling to see current submission and approval status.

Relevant sources:

- [Veeva - Improve Regulatory Processes with Affiliates and Partners](https://www.veeva.com/blog/increase-affiliate-and-partner-engagement-to-improve-regulatory-processes/)
- [ArisGlobal - Regulatory 2025 white paper](https://lifesphere.arisglobal.com/wp-content/uploads/2022/06/LifeSphere_WhitePaper_Regulatory_2025.pdf)

### 3. Best-of-breed platforms still sell visibility, harmonization, and workflow alignment as ongoing needs

ServiceNow IRM explicitly sells a single data model, workflow automation, integrated risk/compliance views, and certified integrations.

That matters because even an incumbent horizontal workflow and GRC platform is still selling the elimination of information silos and the acceleration of cross-functional response as live problems.

Relevant source:

- [ServiceNow Integrated Risk Management](https://www.servicenow.com/products/integrated-risk-management.html)

## Why The Problem Looks Repeatable

The same pattern shows up across:

- pharmacovigilance
- regulatory operations
- affiliate and partner management
- quality and compliance operations
- enterprise risk/governance platforms

The recurring pattern is not "lack of tools."

It is:

- multiple systems of record
- multiple teams
- multiple jurisdictions or local market requirements
- multiple handoffs
- fragmented visibility
- duplicate entry or reconciliation
- unclear ownership at system boundaries

That makes the Sentinel thesis more credible than a domain-specific replacement pitch.

The problem appears when work crosses boundaries, not just when one system is weak.

## Why AI Strengthens The Wedge Without Creating It

This is not a purely AI-born problem.

The cross-system pain predates the current GenAI cycle, as shown in the separate timing audit and older vendor materials around connections, affiliate coordination, and local-global process management.

What AI changes is the operational pressure:

- more unstructured data is being automated
- more AI-assisted outputs need review and provenance
- more enterprise stakeholders now care about the same flow
- AI governance is becoming a distinct layer above workflow and data tooling

ServiceNow's May 6, 2025 AI Control Tower launch is a strong signal here: it explicitly positions AI governance as a centralized command problem across first- and third-party agents, models, and workflows.

Relevant source:

- [ServiceNow AI Control Tower launch](https://www.servicenow.com/fr/company/media/press-room/ai-control-tower-knowledge-25.html)

## Why The Wedge Is Still Hard

### 1. Incumbents are not standing still

Veeva, ArisGlobal, IQVIA, ServiceNow, and others are all moving toward:

- better connected workflows
- stronger cross-suite integration
- more automation
- more analytics
- more AI governance or AI-assisted operations

That means Sentinel is not entering an ignored space.

It is entering a space where incumbents are already expanding their control surfaces.

### 2. Customers may prefer suite consolidation over another layer

Some large buyers may conclude:

- "we should finish our Veeva rollout"
- "we should standardize more work on ServiceNow"
- "we should use our existing internal data platform"

If that happens, Sentinel may look like extra architecture rather than reduced complexity.

### 3. The wedge can easily collapse into services

If the domain model is too abstract, every customer ends up needing:

- custom matter types
- custom obligation logic
- custom routing rules
- custom evidence semantics
- custom reporting structures

At that point Sentinel stops being a product and starts becoming an implementation program.

### 4. Budget ownership may be blurry

The problem spans:

- safety
- regulatory
- quality
- local affiliates
- enterprise architecture
- compliance or risk
- sometimes AI governance

That makes the pain real, but it can make the buying center messy.

## Conditions That Must Be True For The Wedge To Be Valid

The Sentinel wedge is only truly valid when most of these conditions are present in the same buyer environment.

### Environment conditions

- the buyer already runs multiple serious incumbent systems
- at least one important compliance workflow crosses more than one of them
- the workflow also crosses functions, affiliates, vendors, or partners
- local-market or jurisdictional differences materially affect deadlines, routing, or accountability

### Pain conditions

- reconciliation or duplicate entry is not a minor annoyance but a recurring operating burden
- people lose time answering basic status questions because no single trusted thread exists
- inspection or audit readiness depends on reconstructing history from multiple places
- ownership becomes ambiguous at handoff points

### Product-fit conditions

- the recurring pain can be represented by stable core primitives such as `Signal`, `ComplianceMatter`, `Obligation`, `WorkItem`, `Decision`, `EvidenceArtifact`, and `Transmission`
- the first workflow can be solved with a thin overlay rather than replacing a core domain system
- the first integrations can stay limited and purposeful

### Commercial conditions

- a buyer has authority and budget to add a coordination layer
- the promised value is stronger than "better reporting"
- the win can be framed as reduced operational risk, faster coordination, and stronger inspection readiness

## Conditions That Would Weaken Or Invalidate The Wedge

The wedge gets weak fast if any of these dominate.

- one incumbent suite already covers the workflow well enough end to end
- the real customer pain is only dashboarding or analytics
- the workflow volume is too low to justify another platform
- the customer is unwilling to support any new integration surface
- the first use case requires broad domain coverage before any narrow value can be delivered
- the product needs a different data model for every customer before it becomes useful

## Working Validity Scorecard

This scorecard is internal judgment, not external benchmarking.

| Dimension | Working read | Why |
|---|---|---|
| problem existence | high | official vendor and customer-facing materials repeatedly describe silos, reconciliation, and visibility gaps |
| repeatability | medium-high | the pattern appears across safety, regulatory, affiliate, and risk/compliance contexts |
| urgency without AI | medium-high | the pain existed before the current AI cycle and already drove platform and integration investment |
| urgency with AI | high | AI increases provenance, review, governance, and cross-system coordination needs |
| productability | medium | the domain primitives look real, but there is strong risk of over-customization |
| adoption difficulty | high | enterprise trust, integration work, and change management are significant |
| competition intensity | high | incumbents and internal-platform strategies are already active in adjacent space |
| budget clarity | medium-low | the pain is cross-functional, which can dilute ownership |

### Interpretation

This is not a weak idea.

It is a strong-but-narrow idea in a hard market.

That is an important distinction.

## The Strongest Reasons To Keep Pursuing It

- the problem appears old enough to be real, not hype-driven
- the pain appears broad enough to recur, but narrow enough to describe clearly
- AI and international complexity are increasing the need for governed coordination
- the current Sentinel backbone is better aligned with an orchestration product than with a monolithic suite strategy

## The Strongest Reasons To Be Careful

- incumbents are already selling "connected" and "unified" narratives
- many buyers may choose consolidation over overlay
- the product can drift into implementation-heavy abstraction very quickly
- the first buyer segment must be chosen with unusual precision

## What This Means For Sentinel

If Sentinel keeps pursuing this wedge, the project should assume:

- the first product is not "AI compliance"
- the first product is not "global compliance unification"
- the first product is not "replace the existing stack"

The first product is closer to:

- open one governed cross-system matter
- derive and track obligations
- assign and escalate work
- preserve evidence and attestation
- route required downstream actions
- keep a trusted timeline across systems and jurisdictions

That is narrow enough to be meaningful and broad enough to matter.

## Next Validation Questions

These are the questions most worth answering with future design-partner interviews or sharper market inspection.

### Buyer questions

- Who actually feels this pain enough to sponsor it: safety operations, regulatory operations, quality, enterprise architecture, or compliance leadership?
- Who already owns the budget for cross-system coordination failures?
- Which workflow is painful enough that the buyer would adopt an overlay instead of waiting for incumbent roadmap improvements?

### Product questions

- Can one stable matter model cover the first three likely customer scenarios?
- Can the first release deliver value with only two or three integrations?
- Can obligation logic be productized without becoming a consulting exercise?

### Competitive questions

- When does Sentinel beat "finish the current Veeva or ServiceNow rollout"?
- When does Sentinel beat "build it internally on our data and workflow stack"?
- Which incumbent partnership path, if any, makes go-to-market easier rather than harder?

## References

- [Veeva - 4 Insights on PV Transformation](https://www.veeva.com/resources/4-insights-on-pv-transformation/)
- [Veeva - Improve Regulatory Processes with Affiliates and Partners](https://www.veeva.com/blog/increase-affiliate-and-partner-engagement-to-improve-regulatory-processes/)
- [ArisGlobal - Regulatory 2025 white paper](https://lifesphere.arisglobal.com/wp-content/uploads/2022/06/LifeSphere_WhitePaper_Regulatory_2025.pdf)
- [ServiceNow Integrated Risk Management](https://www.servicenow.com/products/integrated-risk-management.html)
- [ServiceNow AI Control Tower launch](https://www.servicenow.com/fr/company/media/press-room/ai-control-tower-knowledge-25.html)
