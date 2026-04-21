# Sentinel International Market and Regulation Audit v1

Status: `draft research note`

Package root:

- `docs/vision/pharma-control-plane/README.md`

## Purpose

This note records two additional inspections requested after the first two market passes:

1. a fresh company scan focused on vendors not previously targeted
2. an international regulation scan focused on how compliance varies across governments even where harmonisation exists

The point is not to prove that international complexity automatically creates a product.

The point is to test whether the same narrow Sentinel wedge still appears when we leave the original US-centric vendor set and consider cross-border compliance reality more seriously.

## Inspection 1: Fresh Company Scan

This pass focused on companies not targeted in the earlier notes, with an intentional bias toward international and non-US-origin players where possible.

### Companies reviewed

- [Ennov Pharmacovigilance Suite](https://en.ennov.com/solutions/pharmacovigilance/)
- [IQVIA Vigilance Platform](https://www.iqvia.com/solutions/safety-regulatory-compliance/safety-and-pharmacovigilance/iqvia-vigilance-platform)
- [CARA Life Sciences Platform - Regulatory Overview](https://www.caralifesciences.generiscorp.com/regulatory-overview/)
- [EXTEDO SafetyEasy](https://www.extedo.com/software/pharmacovigilance-and-drug-safety)

### What they do well

| Company / product | What it appears to do well | What that implies |
|---|---|---|
| [Ennov Pharmacovigilance Suite](https://en.ennov.com/solutions/pharmacovigilance/) | End-to-end PV from case intake to signal detection, configurable workflows, unified database, global usage across pharma companies, CROs, and health authorities | The PV-suite category is crowded with credible global players; Sentinel should not frame itself as another end-to-end PV suite. |
| [IQVIA Vigilance Platform](https://www.iqvia.com/solutions/safety-regulatory-compliance/safety-and-pharmacovigilance/iqvia-vigilance-platform) | Broad safety lifecycle coverage, automation, analytics, AI-assisted touchless processing, and global footprint across more than 100 countries | Large global vendors are already selling safety modernisation, efficiency, and compliance at scale. |
| [CARA Life Sciences Platform](https://www.caralifesciences.generiscorp.com/regulatory-overview/) | Data-driven regulatory process support for applications, registrations, submission planning, commitments, SPOR, xEVMPD, correspondence, and archival | Regulatory information management and authority-facing lifecycle orchestration are already strong categories on their own. |
| [EXTEDO SafetyEasy](https://www.extedo.com/software/pharmacovigilance-and-drug-safety) | Cloud pharmacovigilance and multivigilance management with E2B(R3), EMA-certified gateway connections, and explicit global regulatory-compliance positioning | Even smaller or specialist international players are already selling compliant reporting and regulatory connectivity as a core capability. |

### Similar slice of analysis

The same pattern appears here as in the earlier passes:

- each vendor is strong inside a natural domain boundary
- each vendor promises workflow, compliance, visibility, and efficiency
- several explicitly promise international coverage or gateway-ready reporting

The repeatable remaining slice is still narrower than a whole suite:

- cross-system matter ownership
- cross-domain obligation tracking
- shared evidence and attestation across systems
- jurisdiction-aware orchestration above domain systems

That means the fresh company scan does **not** reveal a missing market for "more compliance software" in general.

It reinforces a narrower proposition:

Sentinel could matter only if it becomes a control plane for the governed thread across systems that already perform well in their own domains.

## Inspection 2: International Regulation and Cross-Government Complexity

The international picture is more complex than "everyone follows the same rules."

There is genuine harmonisation, but it is incomplete in implementation and heavily shaped by local authority processes.

### Harmonisation exists

The International Council for Harmonisation (ICH) provides shared guidance for safety reporting and clinical safety data management:

- [ICH E2D(R1)](https://database.ich.org/sites/default/files/ICH_E2D%28R1%29_Step4_FinalGuideline_2025_0819.pdf) covers post-approval safety data definitions and standards for the management and reporting of individual case safety reports
- [ICH E2B(R3) Q&As](https://database.ich.org/sites/default/files/ICH_E2B-R3_QA_v2_4_Step4_2022_1202.pdf) support structured electronic safety reporting
- [ICH implementation guidance](https://admin.ich.org/page/ich-guideline-implementation) makes clear that guidelines are implemented according to applicable national, local, or regional rules

This is a critical point:

harmonisation reduces friction, but it does not remove regional and local variation.

### Regional and national variation still matters

#### European Union

- [EMA GVP](https://www.ema.europa.eu/en/human-regulatory-overview/post-authorisation/pharmacovigilance-post-authorisation/good-pharmacovigilance-practices-gvp) defines a broad pharmacovigilance operating framework that includes case collection and submission, duplicate management, PSURs, signal management, safety communication, and risk minimisation.
- EMA's GVP materials now also include newer local/legal layers such as the 2025 addendum on masking personal data in ICSRs submitted to EudraVigilance.

Implication:

the EU already has a mature, multi-layer safety framework with structured obligations beyond simple case reporting.

#### United States

- [FDA AEMS / FAERS electronic submissions](https://www.fda.gov/drugs/fda-adverse-event-monitoring-system-aems/fda-adverse-event-monitoring-system-aems-electronic-submissions) requires electronic postmarketing safety reporting and is moving IND safety reports to electronic E2B submission by April 1, 2026.
- [FDA field alert reports](https://www.fda.gov/drugs/surveillance/field-alert-reports) create additional quality-defect reporting obligations, including a 3-day expectation for certain significant quality problems.
- [FDA real-time FAERS publication](https://www.fda.gov/news-events/press-announcements/fda-begins-real-time-reporting-adverse-event-data) shows active modernization in public adverse-event transparency.

Implication:

US obligations are not just about adverse-event case handling. Quality, transparency, and premarket/postmarket reporting channels create overlapping operational duties.

#### United Kingdom

- [MHRA GPvP](https://www.gov.uk/guidance/good-pharmacovigilance-practice-gpvp) still follows a risk-based inspection programme but explicitly applies UK-specific exceptions and modifications to former EU-derived guidance.

Implication:

even where UK and EU expectations remain closely related, post-Brexit local divergence matters operationally.

#### Australia

- [TGA pharmacovigilance responsibilities](https://www.tga.gov.au/resources/guidance/pharmacovigilance-responsibilities-medicine-sponsors) makes sponsors legally responsible for local reporting, records, safety issues, local contact details, and response timelines.
- TGA explicitly expects awareness of international safety information, strong contractual arrangements with third parties, and duplicate-prevention processes.

Implication:

Australia highlights how local accountability, contracts, local contacts, and global information flow all have to work together.

#### Canada

- [Health Canada industry adverse reaction reporting](https://www.canada.ca/en/health-canada/services/drugs-health-products/medeffect-canada/adverse-reaction-reporting/drug/industry.html) requires serious or unexpected adverse reactions to be reported within 15 calendar days and supports electronic trading-partner enrollment.

Implication:

even where the high-level pattern resembles other markets, timelines, submission channels, and operating processes remain market-specific.

#### Japan

- [PMDA Risk Management Plan](https://www.pmda.go.jp/english/safety/info-services/drugs/rmp/0001.html) places strong emphasis on RMP as a published, development-through-postmarketing risk framework with both routine and additional activities.
- [PMDA scientific safety analyses](https://www.pmda.go.jp/english/safety/surveillance-analysis/0002.html) describe data mining, EMR-based analyses, and active post-marketing safety evaluation methods.
- [PMDA risk communications](https://www.pmda.go.jp/english/safety/info-services/drugs/risk-communications/0001.html) and [PMDA post-marketing safety measures](https://www.pmda.go.jp/english/safety/) show a mature communication and corrective-action posture.

Implication:

Japan is a strong example of a market where reporting is only part of the system; risk management, published materials, and post-marketing safety measures are central.

#### Switzerland

- [Swissmedic ElViS](https://www.swissmedic.ch/swissmedic/en/home/services/egov-services/elvis.html) shows a dedicated electronic vigilance submission route with support for case-related documents.
- [Swissmedic market surveillance](https://www.swissmedic.ch/swissmedic/en/home/humanarzneimittel/market-surveillance.html) covers safety signals, international safety data assessment, quality defects, recalls, and illegal products.

Implication:

small and medium markets still add their own reporting channels, document expectations, and market-surveillance duties.

#### China

- [NMPA's National Center for ADR Monitoring](https://english.nmpa.gov.cn/2019-07/19/c_389171.htm) is explicitly responsible for standards and norms on adverse drug reactions, medical-device adverse events, cosmetics adverse reactions, and post-market safety evaluation.
- [China's revised drug-administration regulations](https://english.nmpa.gov.cn/2026-01/28/c_1157477.htm) show continued tightening of supervision and drug-safety oversight in 2026.

Implication:

China adds another major jurisdiction where safety supervision, post-market controls, and evolving implementation expectations increase cross-border complexity.

## Cross-Government Reality

The international compliance problem is not simply "learn one standard."

It is more like:

- implement shared ICH concepts
- map them into local authority rules
- maintain local contacts, local contracts, and local workflows
- submit through different authority channels and databases
- avoid duplicate reporting
- keep product information and safety communications current in each market
- maintain evidence that will survive inspections across different regions

### Recurring operational burdens

Across the sources above, a multinational pharma company has to manage:

- multiple authority gateways or electronic submission channels
- different reporting clocks and reporting categories
- local responsible persons or local contact expectations
- region-specific safety communication or labeling consequences
- quality-defect and market-surveillance obligations in addition to PV case handling
- contractual safety-data exchange with affiliates, partners, vendors, and licensors
- duplicate detection across authorities, systems, and reporting parties
- evolving data-privacy and masking expectations

## Similar Slice of Analysis in the International Context

The international inspection sharpens the same wedge again.

If Sentinel has value internationally, it is probably **not** because global pharma needs one more safety system.

It is because global pharma may need:

- one jurisdiction-aware compliance matter model
- one obligation engine that can encode local and global duties
- one evidence and attestation thread across affiliates, vendors, and regulators
- one orchestration layer that can coordinate downstream submissions and updates without becoming the authority-facing system of record itself

## What This Means for Sentinel

A credible international Sentinel wedge would need to support concepts such as:

- `Jurisdiction`
- `Authority`
- `LocalRequirement`
- `ReportingClock`
- `ResponsibleParty`
- `TransmissionRoute`
- `RiskManagementArtifact`
- `LabelOrCommunicationImpact`
- `DuplicateLinkage`

That does **not** mean building every authority submission stack.

It means that if Sentinel aspires to be a real control plane, the domain model will eventually need to understand:

- which market a matter affects
- what obligations apply there
- who is accountable locally and globally
- what evidence is required
- which downstream systems or authorities must receive updates

## Strong Devil's-Advocate Conclusion

The international pass makes the challenge clearer:

- harmonisation exists
- but cross-border compliance is still operationally fragmented
- existing suites already handle large portions of the work
- the only credible Sentinel wedge remains the governed thread across systems, domains, and jurisdictions

If Sentinel tries to be broader than that, it will run directly into deeply entrenched vendors with much more mature domain coverage.

If Sentinel stays narrow and jurisdiction-aware, the international market actually makes the control-plane argument stronger.

## References

### Market vendors

- [Ennov Pharmacovigilance Suite](https://en.ennov.com/solutions/pharmacovigilance/)
- [IQVIA Vigilance Platform](https://www.iqvia.com/solutions/safety-regulatory-compliance/safety-and-pharmacovigilance/iqvia-vigilance-platform)
- [CARA Life Sciences Platform - Regulatory Overview](https://www.caralifesciences.generiscorp.com/regulatory-overview/)
- [EXTEDO SafetyEasy](https://www.extedo.com/software/pharmacovigilance-and-drug-safety)

### International standards and regulators

- [ICH E2D(R1)](https://database.ich.org/sites/default/files/ICH_E2D%28R1%29_Step4_FinalGuideline_2025_0819.pdf)
- [ICH E2B(R3) Q&As](https://database.ich.org/sites/default/files/ICH_E2B-R3_QA_v2_4_Step4_2022_1202.pdf)
- [ICH Guideline Implementation](https://admin.ich.org/page/ich-guideline-implementation)
- [EMA Good Pharmacovigilance Practices](https://www.ema.europa.eu/en/human-regulatory-overview/post-authorisation/pharmacovigilance-post-authorisation/good-pharmacovigilance-practices-gvp)
- [FDA AEMS / FAERS Electronic Submissions](https://www.fda.gov/drugs/fda-adverse-event-monitoring-system-aems/fda-adverse-event-monitoring-system-aems-electronic-submissions)
- [FDA Field Alert Reports](https://www.fda.gov/drugs/surveillance/field-alert-reports)
- [FDA Begins Real-Time Reporting of Adverse Event Data](https://www.fda.gov/news-events/press-announcements/fda-begins-real-time-reporting-adverse-event-data)
- [MHRA Good Pharmacovigilance Practice](https://www.gov.uk/guidance/good-pharmacovigilance-practice-gpvp)
- [TGA Pharmacovigilance Responsibilities of Medicine Sponsors](https://www.tga.gov.au/resources/guidance/pharmacovigilance-responsibilities-medicine-sponsors)
- [Health Canada Industry Adverse Reaction Reporting](https://www.canada.ca/en/health-canada/services/drugs-health-products/medeffect-canada/adverse-reaction-reporting/drug/industry.html)
- [PMDA Risk Management Plan](https://www.pmda.go.jp/english/safety/info-services/drugs/rmp/0001.html)
- [PMDA Scientific Research and Analyses](https://www.pmda.go.jp/english/safety/surveillance-analysis/0002.html)
- [PMDA Risk Communications](https://www.pmda.go.jp/english/safety/info-services/drugs/risk-communications/0001.html)
- [Swissmedic ElViS](https://www.swissmedic.ch/swissmedic/en/home/services/egov-services/elvis.html)
- [Swissmedic Market Surveillance](https://www.swissmedic.ch/swissmedic/en/home/humanarzneimittel/market-surveillance.html)
- [NMPA National Center for ADR Monitoring](https://english.nmpa.gov.cn/2019-07/19/c_389171.htm)
- [China revises drug administration regulations to spur innovation, tighten oversight](https://english.nmpa.gov.cn/2026-01/28/c_1157477.htm)
