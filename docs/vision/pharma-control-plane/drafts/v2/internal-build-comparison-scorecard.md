# Sentinel v2 Internal Build Comparison Scorecard

Status: `field tool`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Related notes:

- `docs/vision/pharma-control-plane/drafts/v2/internal-build-superiority.md`
- `docs/vision/pharma-control-plane/drafts/v2/executive-readout.md`
- `docs/vision/pharma-control-plane/current/v1/build-vs-buy-teardown.md`
- `docs/vision/pharma-control-plane/current/v1/design-partner-pilot-scorecard.md`

## Purpose

This scorecard operationalizes the hardest substitute question:

is Sentinel more credible to buy than building a local answer internally?

It is designed for real prospect qualification, not abstract strategy discussion.

## How To Use It

Use this scorecard only after:

- one recurring matter type is already clear
- the workflow already looks commercially meaningful
- there is at least some plausible overlay path

The score is not "how much the prospect likes Sentinel."

The score is:

how strong is the case that Sentinel should win against internal build for this workflow?

## Core Comparison Standard

Sentinel does not win by being more visionary.

It wins only if it looks more credible on:

- product coherence
- repeatability
- evidence quality
- operator usefulness
- speed to useful proof

## Scoring Method

Score each dimension from `1` to `5`.

- `1`
  - internal build clearly favored
- `3`
  - mixed or uncertain
- `5`
  - Sentinel advantage looks strong

Record notes for every score.

## Dimensions

### 1. Matter-Model Stability Need

Question:

Does this workflow need a stable shared matter model, or would a local project model be good enough?

- `1`: local workflow state is enough
- `3`: some stable model value, but not critical
- `5`: stable matter model looks essential across teams and systems

### 2. Evidence And Provenance Rigor

Question:

How important is reconstructable evidence and decision history for this workflow?

- `1`: light documentation is enough
- `3`: useful but inconsistent need
- `5`: evidence rigor is operationally important

### 3. Operator Workspace Gap

Question:

Would operators materially benefit from a purpose-built workspace, or can they work fine from incumbent screens plus reports?

- `1`: incumbent screens plus reports are enough
- `3`: workspace would help, but not decisively
- `5`: operators clearly need one shared workspace

### 4. Downstream-State Fragmentation

Question:

How fragmented is the current view of downstream actions across systems?

- `1`: downstream state is mostly obvious already
- `3`: fragmented sometimes
- `5`: downstream completion is routinely reconstructed manually

### 5. Cross-System And Cross-Team Breadth

Question:

How much real coordination crosses system and team boundaries?

- `1`: mostly local and contained
- `3`: moderate cross-boundary coordination
- `5`: repeated cross-boundary coordination is central to the workflow

### 6. Internal Workflow Team Strength

Question:

How strong is the internal team that would likely build this instead?

- `1`: very strong and already trusted
- `3`: capable but uneven
- `5`: weak, overloaded, or not well positioned for this problem

Note:

Higher score means better for Sentinel.

### 7. Internal-Build Drift Risk

Question:

How likely is an internal solution to drift into tickets, reports, and custom exceptions instead of a stable product shape?

- `1`: low drift risk
- `3`: moderate drift risk
- `5`: high drift risk is very likely

### 8. Time-To-Proof Advantage

Question:

Can Sentinel likely prove value faster than a credible internal project could?

- `1`: internal project likely faster or equal
- `3`: unclear
- `5`: Sentinel likely much faster to useful proof

### 9. Repeatability Beyond The First Workflow

Question:

If the first workflow succeeds, would Sentinel have a plausible advantage on the next adjacent workflow too?

- `1`: next workflow would still require a mostly new local build
- `3`: some reuse possible
- `5`: strong reuse of model and workspace seems likely

### 10. Buyer Confidence In Buying Versus Building

Question:

Can the prospect plausibly say buying Sentinel feels more credible than stitching the answer together internally?

- `1`: build still feels safer
- `3`: mixed
- `5`: buying now feels more credible

## Total Interpretation

- `40-50`
  - strong Sentinel advantage over internal build
- `30-39`
  - promising but not yet decisive
- `20-29`
  - internal build likely remains the stronger substitute
- `below 20`
  - Sentinel should not treat this workflow as a near-term buy case

## Automatic Caution Flags

Even with a decent score, slow down if any of these are true:

- the prospect says dashboards would solve most of the problem
- the prospect mainly wants nicer visibility, not a new workspace
- the prospect has a strong internal platform team already committed to solving this
- the matter mostly stays inside one incumbent system
- the second adjacent workflow does not appear any easier than the first

## Capture Template

- `workflow`
- `likely internal alternative`
- `internal team strength`
- `main incumbent systems`
- `operator pain today`
- `where internal build would likely be strong`
- `where internal build would likely drift`
- `Sentinel's clearest advantage`
- `Sentinel's weakest point`
- `score total`
- `decision`

## Decision Guidance

### Advance

Advance when:

- total score is `40+`
- no major caution flag dominates
- the buyer can plausibly imagine buying rather than stitching

### Keep Qualifying

Keep qualifying when:

- total score is `30-39`
- one or two dimensions remain unclear
- the workflow is real, but the internal alternative still feels respectable

### Walk Away

Walk away when:

- total score is below `30`
- internal build is favored on product coherence or time to proof
- the buyer still sounds more interested in reports or local workflow than in a matter workspace

## Most Important Output

The most important output is not the number by itself.

It is whether the prospect can say something close to:

"We could build this ourselves, but buying Sentinel looks more coherent, more repeatable, and faster to value than stitching it together again."
