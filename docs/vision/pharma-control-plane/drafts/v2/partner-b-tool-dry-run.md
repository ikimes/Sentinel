# Sentinel v2 Tool Dry Run: Partner B

Status: `working exercise`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Related notes:

- `docs/vision/pharma-control-plane/current/v1/hypothetical-design-partner-assessment-weaker.md`
- `docs/vision/pharma-control-plane/drafts/v2/partner-a-tool-dry-run.md`
- `docs/vision/pharma-control-plane/drafts/v2/overlay-buying-path-interview-rubric.md`
- `docs/vision/pharma-control-plane/drafts/v2/internal-build-comparison-scorecard.md`

## Purpose

This exercise dry-runs the two new `v2` field tools against the weaker hypothetical prospect from `v1`.

The goal is to make the failure boundary as explicit as the stronger benchmark case.

## Partner B Summary

Partner B is the weaker hypothetical candidate from `v1`:

- mid-sized biotech
- one incumbent safety platform
- limited local-market complexity
- small central safety operations team
- basic reporting already in place
- a light internal workflow team that can extend current tools

The prior `v1` read was:

- overall score: `23 / 50`
- qualification: `do not pursue as a first design partner`
- biggest weaknesses: low recurrence, low overlay appetite, and a credible internal-build alternative

## Tool 1: Overlay Buying Path Interview Rubric

### Scorecard

| Dimension | Score | Reason |
|---|---|---|
| `Workflow visibility to leadership` | `2` | leadership notices some exceptions, but not as a recurring control problem |
| `Sponsor clarity` | `3` | a director of safety operations or systems manager is plausible, but the sponsor likely lacks real purchasing force |
| `Budget clarity` | `1` | no credible budget path is visible from the current facts |
| `Approval clarity` | `2` | likely stakeholders are visible, but the approval path looks more obstructive than legible |
| `Overlay appetite` | `2` | internal extension still feels safer and more proportional than a new overlay |
| `Incumbent resistance` | `2` | incumbent and enterprise-tooling owners likely have little reason to welcome another layer |
| `Commercial wrapper fit` | `2` | a smaller control-surface framing might sound acceptable, but not strongly enough to unlock a buy |

### Total

`14 / 35`

### Interpretation

This lands in:

`overlay path is weak`

The product can still sound useful here, but the buying motion is not credible enough for a first-customer pursuit.

The biggest weaknesses are:

- no clear budget path
- low overlay appetite
- limited leadership visibility
- insufficient commercial leverage for even the smallest first framing

### What This Tool Says

Partner B is exactly the kind of account where a workflow can be real and the overlay still should not be pursued.

The sponsor path is too weak, the budget path is too vague, and the first purchase never feels necessary enough.

## Tool 2: Internal Build Comparison Scorecard

### Scorecard

| Dimension | Score | Reason |
|---|---|---|
| `Matter-model stability need` | `2` | the workflow is not broad enough to make a stable shared matter model feel essential |
| `Evidence and provenance rigor` | `3` | some evidence reconstruction matters, but not consistently enough to force a dedicated product |
| `Operator workspace gap` | `2` | a better workspace would help, but incumbent screens plus reporting are still mostly serviceable |
| `Downstream-state fragmentation` | `2` | some fragmentation exists, but not at a severity that dominates operations |
| `Cross-system and cross-team breadth` | `2` | most work remains local and contained |
| `Internal workflow team strength` | `2` | internal extension looks reasonably plausible for this scope |
| `Internal-build drift risk` | `2` | drift risk exists, but the workflow is light enough that the buyer may tolerate it |
| `Time-to-proof advantage` | `2` | Sentinel may still be fast, but not clearly faster than a local extension path that feels good enough |
| `Repeatability beyond the first workflow` | `2` | the workflow does not look central enough to imply strong adjacent reuse |
| `Buyer confidence in buying versus building` | `1` | build or extension still feels safer and more proportional |

### Total

`20 / 50`

### Interpretation

This lands in:

`internal build likely remains the stronger substitute`

The workflow is not broad or painful enough for Sentinel's deeper product strengths to outweigh the comfort of local extension.

### What This Tool Says

Partner B does not fail because Sentinel lacks value in the abstract.

It fails because Sentinel's value is not sufficiently stronger than the internal alternative for this workflow.

The account can plausibly say:

- better reports may be enough
- a small internal queue may be enough
- a local workflow extension may be enough

That is exactly the environment where Sentinel should stay out.

## Where The Two Tools Converge

They agree on four core points:

### 1. The workflow is real but not commercially dense enough

Neither tool says the workflow is imaginary.

Both say it is too light to anchor a first-customer motion.

### 2. The buying path is weaker than the product story

Even if the UI or workspace sounds attractive, the actual path to a first purchase is too thin.

### 3. Internal build or extension feels more proportionate than Sentinel

This is the clearest failure signal.

The buyer would not need to deny the value of Sentinel.

They only need to decide that internal extension is "good enough."

### 4. The account fails because the pain does not concentrate

Partner B does not fail on complexity alone.

It fails because recurrence, severity, leadership visibility, overlay appetite, and reuse potential are all only moderate or low at the same time.

## Comparison With Partner A

Partner A and Partner B do not differ only by size.

They differ by concentration of pain.

### Partner A

- workflow qualifies strongly
- product fit is strong
- buying path is still fragile
- internal-build pressure is real but contestable

### Partner B

- workflow is real but weakly concentrated
- product fit is partial
- buying path is weak
- internal build is still the more credible answer

### What Actually Flips The Result

The flip points are:

- recurrence moves from frequent to occasional
- cross-system breadth moves from meaningful to limited
- leadership visibility moves from noticeable to background
- overlay appetite moves from plausible to weak
- internal build moves from respectable substitute to clearly more proportional choice

## Combined Verdict

Partner B is a useful failure-boundary benchmark.

The combined read is:

- `workflow qualification`: weak-to-moderate
- `overlay buying path`: weak
- `internal-build pressure`: internal build favored
- `overall`: do not pursue as a first-customer candidate

## Practical Use

Use Partner B as the lower-bound warning case.

If a real prospect scores near Partner B on either tool, Sentinel should not rationalize its way into a pilot.

The account may still be interesting later, but it should not be treated as a near-term proving ground.
