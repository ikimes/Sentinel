# Sentinel Feasibility and Entry Framework v1

Status: `draft research note`

Package root:

- `docs/vision/pharma-control-plane/README.md`

## Purpose

This note captures a blunt feasibility read of the Sentinel thesis after the market and regulatory inspections.

It addresses:

- how difficult the product is to build
- how much money it likely takes to start credibly
- which tech stack is best suited
- who is already in or adjacent to the market
- where Sentinel should enter first
- which growth paths should not be chased initially
- what "empty market" means in practical terms

## Feasibility Findings

### Short version

The narrow Sentinel wedge is feasible.

The full long-term vision is not an easy first-company problem.

### Feasible version

A credible first product is:

- PV-first
- cross-system
- jurisdiction-aware
- matter-centric
- evidence- and obligation-driven

That means Sentinel v1 should focus on:

- signal normalization
- `ComplianceMatter`
- obligation and reporting-clock derivation
- evidence and attestation thread
- work assignment and escalation
- downstream routing into existing systems

This is difficult, but realistic.

### Hard version

A full "global compliance control plane" spanning safety, regulatory, clinical, quality, partner exchange, governance, and AI control as a broad initial product is extremely hard.

That difficulty comes from:

- domain-model breadth
- regulatory-content and rule maintenance
- enterprise integrations
- buyer trust requirements
- long implementation cycles
- the need for both software and deep domain expertise

### Practical conclusion

Sentinel is feasible only if it starts as a thin orchestration layer over existing systems rather than as a suite replacement.

## Startup Difficulty and Capital

This section is engineering and market judgment, not an externally sourced pricing benchmark.

### Difficulty rating

| Stage | Difficulty | Why |
|---|---|---|
| design-partner prototype | high but achievable | narrow wedge, limited integrations, mostly product-definition and workflow risk |
| first enterprise pilot | very high | integration, buyer trust, compliance posture, and implementation effort become real |
| multi-domain control plane company | extremely high | expansion pressure collides with entrenched vendors and broad domain expectations |

### Cost profile

Roughly:

- design-partner wedge: about `$1.5M-$3M`
- credible enterprise v1: about `$5M-$15M+`

The hidden costs are not mostly cloud infrastructure.

They are:

- senior product and engineering talent
- life-sciences domain expertise
- implementation and integration work
- enterprise security/compliance work
- customer onboarding and services effort

### Meaning for Sentinel

Sentinel is not a low-cost "weekend SaaS" opportunity.

It is more like:

- viable as a venture-backed or strongly funded design-partner product
- difficult to bootstrap into a broad platform
- possible to bootstrap into a narrow proving wedge if scope stays disciplined

## Recommended Technical Position

### Best-fit stack for the Sentinel wedge

The most suitable stack for the current product direction is:

- backend: modern `.NET`
- API: REST first, event-driven internally
- persistence: `PostgreSQL`
- messaging and background orchestration: `RabbitMQ` + `MassTransit`
- evidence artifact storage: `S3-compatible object storage`
- observability: `OpenTelemetry`
- frontend: `Blazor` for the operator workspace and coordination-faithful drill-down, with targeted JS interop reserved for the expert graph mode
- auth: enterprise `OIDC/SAML`

### Why this stack fits

- The current Sentinel backbone already proves the right kind of durable async foundation.
- A modular-monolith architecture is a better fit than premature microservices.
- PostgreSQL is strong enough to back early workflow, matter, evidence, and projection models.
- RabbitMQ plus MassTransit fits the ingestion, enrichment, and routing profile well.
- Blazor better matches the product's need to stay explicit about cross-system coordination and failed interaction drill-down without turning the default experience into a graph-first tool.

### What should not be overbuilt early

- a giant workflow engine
- a full authority gateway stack
- a large search platform before query pressure proves it necessary
- a broad AI platform before matter/evidence/obligation primitives are stable
- many microservices before the domain seams are proven

## Competition Now

The market is not empty.

### Direct and near-direct domain competitors

- [Veeva Safety](https://www.veeva.com/products/veeva-safety/)
- [ArisGlobal LifeSphere Safety](https://www.arisglobal.com/lifesphere/safety/)
- [IQVIA Vigilance Platform](https://www.iqvia.com/solutions/safety-regulatory-compliance/safety-and-pharmacovigilance/iqvia-vigilance-platform)
- [Oracle Argus Safety](https://docs.oracle.com/en/industries/life-sciences/argus-safety/index.html)
- [Ennov Pharmacovigilance Suite](https://en.ennov.com/solutions/pharmacovigilance/)
- [EXTEDO SafetyEasy](https://www.extedo.com/software/pharmacovigilance-and-drug-safety)
- [CARA Life Sciences Platform - Regulatory Overview](https://www.caralifesciences.generiscorp.com/regulatory-overview/)

### Adjacent platform competitors

- [Veeva RIM](https://www.veeva.com/products/veeva-rim/)
- [Medidata Rave EDC](https://www.medidata.com/en/clinical-trial-products/clinical-data-management/edc-systems/)
- [Informatica Cloud Data Governance and Catalog](https://www.informatica.com/products/data-governance/cloud-data-governance-and-catalog.html)
- [MasterControl Quality Event Management](https://www.mastercontrol.com/quality/quality-event-management/)
- [ServiceNow Integrated Risk Management](https://www.servicenow.com/products/integrated-risk-management.html)
- [MetricStream Connected GRC](https://www.metricstream.com/products/connected-grc.htm)
- [TrueCommerce Fully Managed EDI](https://www.truecommerce.com/products/edi-software/fully-managed-service/)
- [Power BI](https://www.microsoft.com/en-us/power-platform/products/power-bi)
- [KNIME for Enterprise](https://www.knime.com/knime-for-enterprise)

### What they do that matters strategically

- [Veeva Safety](https://www.veeva.com/products/veeva-safety/) already positions around adverse-event intake, case management, submission, and connected safety operations.
- [ArisGlobal LifeSphere Safety](https://www.arisglobal.com/lifesphere/safety/) positions around unified global workflows, end-to-end PV operations, and AI-forward safety automation across more than 220 global organizations.
- [IQVIA Vigilance Platform](https://www.iqvia.com/solutions/safety-regulatory-compliance/safety-and-pharmacovigilance/iqvia-vigilance-platform) positions around end-to-end safety lifecycle support, AI-assisted near-touchless processing, and support from more than 3,000 safety professionals in more than 100 countries.
- [ServiceNow IRM](https://www.servicenow.com/products/integrated-risk-management.html) positions around a single data model, workflow automation, unlimited compliance case types, and integrated enterprise risk/compliance workflows.
- [MetricStream](https://www.metricstream.com/pressNews/grc-with-ai-first-strategy-new-brand.html) positions around AI-first connected GRC and integrated risk/compliance management at enterprise scale.

### Hidden competitor

The most dangerous competitor may be:

internal build plus systems integrator

Especially when the customer already has:

- ServiceNow
- Snowflake
- Azure
- Power BI
- Veeva
- a strong internal enterprise architecture team

## Blunt Go / No-Go Framework

### Best position to enter from

The best market-entry position is:

PV-first cross-system matter orchestration for multinational pharma companies that already have serious incumbent systems.

That means Sentinel enters as:

- a thin orchestration layer
- not a suite replacement
- not a pure dashboard product
- not a generic workflow engine

The strongest initial buyer pain is likely:

- one event creates work across safety, regulatory, quality, and local affiliate teams
- obligations and reporting clocks vary by market
- evidence and decisions are fragmented across systems
- management wants one governed thread without ripping out incumbents

### GO if these conditions are true

- a design partner has visible cross-system pain that incumbents are not solving well
- the first use case can stay PV-first and narrow
- the team is willing to sell orchestration, not suite replacement
- jurisdiction-aware obligation logic is treated as a product primitive
- the company can fund enterprise-grade implementation, not just product coding
- success can be measured by clearer ownership, faster coordination, and better inspection readiness, not just "more dashboards"

### NO-GO if these conditions are true

- the strategy depends on replacing Veeva Safety, ArisGlobal, Argus, or RIM suites directly
- the pitch depends on "empty market" assumptions
- the first product tries to cover PV, regulatory, clinical, quality, and GRC at once
- the team cannot support enterprise implementation and integration effort
- the product depends on broad AI promises before matter/evidence/obligation control exists
- the company cannot identify a very specific first workflow that customers already struggle to coordinate across systems

## Growth Opportunities Not Initially Chased

These may be real later, but they should not be chased in the first wedge:

- full safety-case processing suite behavior
- full regulatory-information-management behavior
- full eQMS or CAPA platform behavior
- full authority gateway / submission transport ownership
- generalized enterprise GRC platform behavior
- full analytics warehouse replacement
- broad partner-exchange network ownership
- large-scale generic AI platform positioning

The early product should instead keep proving the same narrow idea:

Sentinel owns the governed thread across systems, not the full record system inside each domain.

## What "Empty Market" Means

An empty market would mean something like this:

- there are few or no credible incumbents
- buyers are clearly underserved by current tools
- there is little established budget already captured by adjacent vendors
- customers do not already have entrenched workflows and systems for the problem
- switching or adoption pressure is low because there is not much to replace

That is **not** the market Sentinel would enter.

### Why Sentinel's market is not empty

- there are multiple strong incumbents in PV, safety, regulatory, quality, workflow, governance, and analytics
- many of them already promise unification, automation, AI, and operational visibility
- customers often already have complex stacks and existing investments
- buyers can choose between vendor expansion, systems integrators, and internal build paths

So when I said:

`Empty market: definitely not`

I meant:

Sentinel would be entering a crowded, well-funded, and highly opinionated enterprise market where the opportunity is a narrow whitespace between strong existing systems, not a blank field with no alternatives.

## Practical Conclusion

The most honest strategy is:

- enter narrow
- prove cross-system matter orchestration
- make jurisdiction-aware obligation logic real
- win where incumbents stop at their own boundary
- delay broader platform ambition until the wedge is truly validated

## References

- [Veeva Safety](https://www.veeva.com/products/veeva-safety/)
- [ArisGlobal LifeSphere Safety](https://www.arisglobal.com/lifesphere/safety/)
- [IQVIA Vigilance Platform](https://www.iqvia.com/solutions/safety-regulatory-compliance/safety-and-pharmacovigilance/iqvia-vigilance-platform)
- [Oracle Argus Safety documentation](https://docs.oracle.com/en/industries/life-sciences/argus-safety/index.html)
- [Ennov Pharmacovigilance Suite](https://en.ennov.com/solutions/pharmacovigilance/)
- [EXTEDO SafetyEasy](https://www.extedo.com/software/pharmacovigilance-and-drug-safety)
- [CARA Life Sciences Platform - Regulatory Overview](https://www.caralifesciences.generiscorp.com/regulatory-overview/)
- [Veeva RIM](https://www.veeva.com/products/veeva-rim/)
- [Medidata Rave EDC](https://www.medidata.com/en/clinical-trial-products/clinical-data-management/edc-systems/)
- [Informatica Cloud Data Governance and Catalog](https://www.informatica.com/products/data-governance/cloud-data-governance-and-catalog.html)
- [MasterControl Quality Event Management](https://www.mastercontrol.com/quality/quality-event-management/)
- [ServiceNow Integrated Risk Management](https://www.servicenow.com/products/integrated-risk-management.html)
- [MetricStream AI-first Connected GRC](https://www.metricstream.com/pressNews/grc-with-ai-first-strategy-new-brand.html)
- [TrueCommerce Fully Managed EDI](https://www.truecommerce.com/products/edi-software/fully-managed-service/)
- [Microsoft Power BI](https://www.microsoft.com/en-us/power-platform/products/power-bi)
- [KNIME for Enterprise](https://www.knime.com/knime-for-enterprise)
- [ICH Guideline Implementation](https://admin.ich.org/page/ich-guideline-implementation)
- [EMA Good Pharmacovigilance Practices](https://www.ema.europa.eu/en/human-regulatory-overview/post-authorisation/pharmacovigilance-post-authorisation/good-pharmacovigilance-practices-gvp)
- [FDA AEMS Electronic Submissions](https://www.fda.gov/drugs/fdas-adverse-event-reporting-system-faers/fda-adverse-event-reporting-system-faers-electronic-submissions)
- [MHRA Good Pharmacovigilance Practice](https://www.gov.uk/guidance/good-pharmacovigilance-practice-gpvp)
- [TGA Pharmacovigilance Responsibilities of Medicine Sponsors](https://www.tga.gov.au/resources/guidance/pharmacovigilance-responsibilities-medicine-sponsors)
