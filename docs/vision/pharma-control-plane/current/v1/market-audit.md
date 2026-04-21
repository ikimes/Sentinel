# Sentinel Pharma Control Plane Market Audit v1

Status: `draft research note`

Package root:

- `docs/vision/pharma-control-plane/README.md`

## Purpose

This note captures the devil's-advocate feedback gathered before revising the main vision package.

It has two jobs:

1. record what existing tools already do well
2. test whether a repeatable cross-system gap still exists across different companies and platforms

The goal is to avoid building a vision around a problem that best-of-breed tools already solve well enough on their own.

## Captured Feedback From the First Pass

The first market pass suggested five hard truths:

- many current tools are already strong at their core jobs
- large pharma companies may not want another layer unless it removes a very specific kind of friction
- Sentinel should not position itself as a replacement for RIM, PV, EDC, eQMS, EDI, or BI platforms
- the strongest wedge is the governed thread across systems, not the system of record inside one domain
- in some customer environments, Sentinel may add little value if a single vendor stack already covers the workflow end-to-end well enough

That initial feedback remains valid after the second pass.

## Second Market Pass Across Different Companies and Platforms

The second pass looked across a different set of vendors and adjacent operating models:

- [Veeva Safety](https://www.veeva.com/products/veeva-safety/)
- [ArisGlobal LifeSphere Safety](https://www.arisglobal.com/lifesphere/safety/)
- [Oracle Argus Safety](https://docs.oracle.com/en/industries/life-sciences/argus-safety/index.html)
- [MasterControl Quality Event Management](https://www.mastercontrol.com/quality/quality-event-management/)
- [ServiceNow Integrated Risk Management](https://www.servicenow.com/products/integrated-risk-management.html)
- [MetricStream Connected GRC](https://www.metricstream.com/products/connected-grc.htm)

### What they do well

| Company / product | What it clearly does well | What that means for Sentinel |
|---|---|---|
| [Veeva Safety](https://www.veeva.com/products/veeva-safety/) | Adverse-event intake, processing, submission, built-in gateway connections, oversight, AI-assisted intake, and connected safety operations | Sentinel should not pitch itself as a better safety case system. |
| [ArisGlobal LifeSphere Safety](https://www.arisglobal.com/lifesphere/safety/) | End-to-end safety operations, AI-forward intake and signal capabilities, global compliance support, reporting and analytics, and a unified safety platform | Sentinel should not compete as another end-to-end PV suite. |
| [Oracle Argus Safety](https://docs.oracle.com/en/industries/life-sciences/argus-safety/index.html) | Core adverse-event intake, coding, medical and quality assessment, and regulatory report generation | Sentinel should not try to replace established case-processing infrastructure. |
| [MasterControl Quality Event Management](https://www.mastercontrol.com/quality/quality-event-management/) | Closed-loop quality event management, QMS-connected investigation, CAPA escalation, quality event coordination, and shared data across functional areas | Sentinel should not pitch as a superior eQMS or quality-event engine. |
| [ServiceNow IRM](https://www.servicenow.com/products/integrated-risk-management.html) | Cross-functional workflows, single data model, policy/compliance management, regulatory change workflows, audit support, and broad enterprise risk automation | Sentinel should not market itself as a generic enterprise workflow platform. |
| [MetricStream Connected GRC](https://www.metricstream.com/products/connected-grc.htm) | Integrated GRC, collaboration across risk/compliance/audit/cyber teams, AI-first compliance and regulatory change support, and unified risk intelligence | Sentinel should not position itself as a general-purpose GRC suite. |

### Similar customer-side signals

Across vendor positioning and customer examples, a strikingly similar demand pattern shows up:

- unify fragmented data and workflows
- reduce silos and reconciliation
- increase real-time visibility
- streamline end-to-end operations
- connect neighboring business domains
- use AI and automation to reduce manual effort

Examples:

- [LEO Pharma's Veeva Safety story](https://www.veeva.com/resources/leo-pharma-connects-affiliates-with-veeva-vault-safety-to-transform-safety-operations/) emphasizes eliminating data silos, real-time oversight, simpler workflows, and stronger connection across safety, clinical, regulatory, and quality.
- [Nippon Shinyaku's ArisGlobal announcement](https://www.arisglobal.com/media/press-release/nippon-shinyaku-selects-lifesphere-safety/) emphasizes a global single database, streamlined workflow, clearer visibility into global safety data, and support for both local and global compliance.
- [MasterControl's quality-event materials](https://www.mastercontrol.com/quality/quality-event-management/) emphasize closed-loop quality management, cross-functional sharing, event coordination, and escalation to CAPA when needed.
- [ServiceNow IRM](https://www.servicenow.com/products/integrated-risk-management.html) emphasizes one platform, one data model, workflow automation, compliance requests, case types, and cross-functional risk and compliance workflows.
- [MetricStream Connected GRC](https://www.metricstream.com/products/connected-grc.htm) emphasizes integrated collaboration across risk, compliance, audit, cyber, and sustainability with AI-assisted intelligence and regulatory-change support.

## Repeating Market Pattern

The repeating pattern is not that the market lacks software.

The repeating pattern is that each major vendor promises some combination of:

- unification
- workflow
- visibility
- analytics
- AI-assisted efficiency

That is important because it means a weak Sentinel pitch would sound redundant almost immediately.

The better reading is this:

these platforms are very good at unifying work inside their own product boundary or their natural domain boundary.

That still leaves a narrower, more credible opening for Sentinel.

## The Similar Slice That Still Appears to Exist

The slice that still appears across these different companies is:

### 1. Cross-system matter ownership

Many platforms manage records, cases, quality events, risk items, or safety workflows well.

Fewer appear designed to own one cross-system compliance matter that can span:

- PV
- regulatory
- quality
- clinical
- partner exchange
- governance and AI oversight

### 2. One obligation model across domains

Many platforms can track obligations within their own domain.

The thinner slice is a cross-domain obligation model that can answer:

- what must happen next
- under which policy or regulation
- by when
- who owns it
- what downstream systems must be informed

### 3. Shared evidence and attestation thread

Many platforms preserve data and some workflow history.

The wedge is a single trusted thread of:

- signal
- enrichment
- obligation
- review
- decision
- evidence
- transmission

especially when those steps happen across more than one platform.

### 4. AI governance above AI-enabled tools

Several vendors now claim AI-first or AI-assisted capabilities.

That suggests customers may soon need a layer that governs:

- provenance
- confidence
- approval checkpoints
- escalation rules
- traceable human acceptance or override

even when the AI itself is embedded in other products.

## Where Sentinel Could Still Be Unnecessary

This is the strongest caution signal and should remain attached to the vision package.

Sentinel may not be compelling if:

- the customer is highly standardized on one suite that already covers the required workflow well enough
- the primary pain is only BI and dashboarding
- the primary pain is only PV case processing
- the organization already built a strong internal control layer across its stack

Any future Sentinel positioning should acknowledge this rather than pretending every large pharma company automatically needs another orchestration layer.

## Implications for the Draft Vision

The draft vision should be sharpened in four ways:

### 1. Narrow the wedge language

Do not say Sentinel "unifies compliance."

Instead say Sentinel governs the cross-system matter, obligation, evidence, and decision thread when existing tools each do their own jobs well.

### 2. Avoid direct competition framing

Do not imply Sentinel is:

- a better PV suite
- a better RIM suite
- a better eQMS
- a better EDI network
- a better BI platform
- a better GRC platform

### 3. Make the matter model central

The cross-system wedge becomes more credible when the language centers on:

- `Signal`
- `ComplianceMatter`
- `Obligation`
- `WorkItem`
- `Decision`
- `EvidenceArtifact`
- `Transmission`
- `TimelineEvent`

### 4. Treat AI governance as a layer, not a feature bullet

The stronger claim is not "Sentinel uses AI."

The stronger claim is that Sentinel can govern AI-assisted intake, routing, triage, and summarization across a fragmented enterprise environment.

## Provisional Conclusion

The second pass reinforces, rather than weakens, the basic thesis:

there may still be a real market wedge for Sentinel, but only if the positioning is narrow and honest.

The credible pitch is not:

"replace the existing stack."

The credible pitch is:

"when your existing stack already does many things well, Sentinel becomes the control plane for the governed thread across them."

## References

- [Veeva Safety](https://www.veeva.com/products/veeva-safety/)
- [Veeva Safety Suite](https://www.veeva.com/products/veeva-safety-suite/)
- [LEO Pharma and Veeva Safety](https://www.veeva.com/resources/leo-pharma-connects-affiliates-with-veeva-vault-safety-to-transform-safety-operations/)
- [ArisGlobal LifeSphere Safety](https://www.arisglobal.com/lifesphere/safety/)
- [Nippon Shinyaku selects LifeSphere Safety](https://www.arisglobal.com/media/press-release/nippon-shinyaku-selects-lifesphere-safety/)
- [Oracle Argus Safety documentation](https://docs.oracle.com/en/industries/life-sciences/argus-safety/index.html)
- [MasterControl Quality Event Management](https://www.mastercontrol.com/quality/quality-event-management/)
- [ServiceNow Integrated Risk Management](https://www.servicenow.com/products/integrated-risk-management.html)
- [MetricStream Connected GRC](https://www.metricstream.com/products/connected-grc.htm)
