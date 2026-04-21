# UI Shell Content Inspection

Last updated: 2026-03-17

## Purpose

This document merges the current operator-shell inspection notes into one working reference for the next UI refinement pass.

It is intentionally focused on:

- content meaning
- information hierarchy
- operator comprehension
- what to refine before another planning phase

This is not a styling spec or component inventory. It is a content-and-structure review of the current `S3.1` / `S3.2` Blazor shell.

## Current Shared Read

The first Blazor shell is a good structural start.

What is already true:

- the shell is mobile-friendly
- the content islands are coherent
- the panel typography is highly readable
- the operator-first workspace shape is visible
- queue selection updates the visible state correctly

What is not yet true:

- the page does not yet guide understanding naturally enough
- the content is still too synthetic and repetitive to make scenario differences obvious at a glance
- the matter workspace is too congested relative to the importance of the information it carries
- some labels sound implementation-driven rather than operator-driven

## Shared Conclusions

### S3.3 Resolution Notes

- the shell now grounds `matter` in-product as a compliance follow-up that still needs human decision, handoff, or confirmation
- queue lenses now explain operator intent, not just taxonomy
- the selected matter workspace is now split more clearly into:
  - current state
  - why in focus
  - next move
- `Deterministic operator summary` is now resolved into an operator-facing brief pattern
- timeline timestamps now favor local, human-readable phrasing and the latest event receives explicit emphasis

### S3.3b Resolution Notes

- the three proof scenarios now use scenario-faithful queue signals instead of generic heuristics
- `Why it surfaced` now reads in operator language rather than echoing raw queue-view values such as `active-clock` or `all`
- the delay-path, downstream-retry, and happy-path matters now differentiate clearly as:
  - deadline and evidence pressure
  - downstream retry follow-through
  - settled acknowledgement context
- selected-matter subtitles and brief copy now reinforce why each scenario is distinct instead of repeating generic handoff language
- the settled happy-path matter no longer presents with an implied urgency cue when viewed in the full queue

### Keep

- keep the overall four-part shell:
  - queue
  - matter workspace
  - timeline
  - context window
- keep the mobile-friendly layout behavior
- keep the readable panel markup and label/value rhythm
- keep the question-and-answer style in the context window
- keep the timeline as a critical explanatory surface

### Core Problems To Solve

- improve natural flow from top-level triage into detailed understanding
- make state differences between matters immediately legible
- reduce congestion in the matter workspace without flattening useful information
- replace internal-feeling language with operator-facing language
- define what a `matter` is inside the product

### Important Constraint

The product should stay operator-first.

The shell should not drift into:

- graph-first UX
- generic dashboarding
- generic workflow chrome

The expert graph mode remains a later, secondary surface.

## Section Review

### Hero Panel

Current role:

- establish the shell identity
- orient the user to what the page is

What works:

- clearly frames the page as a dedicated workspace
- gives useful top-level context

What feels muddy:

- it occupies more cognitive space than it has earned
- `Operator matter workspace` is not self-explanatory for a newcomer
- the right-side summary bubbles repeat information that is better owned by the page below

Decision:

- keep the hero panel
- shorten it
- make it explain the page job more plainly

Recommended refinement:

- reduce the amount of one-and-done text
- replace internal language with clearer operator-facing framing
- avoid repeated summary chips unless they carry unique value

### Queue Views

Current role:

- allow the user to change the queue lens

What works:

- highly discoverable
- concise supporting text
- the repeated queue-language acts as useful symbolic anchors

What feels muddy:

- the controls explain what they filter, but not strongly enough why the operator would use them
- some labels still feel taxonomy-like rather than decision-like

Decision:

- keep the queue view control structure
- improve the decision language around each filter

Recommended refinement:

- move labels toward operator intent and urgency
- strengthen the supporting text so each filter communicates when to use it

### Matter Queue

Current role:

- primary selection surface for the workspace

What works:

- clearly the main action list
- status bubbles help anchor meaning
- high-level surfaced data gives the user somewhere to start

What feels muddy:

- the three matters still read too similarly
- `clock` and `active-clock` language is ambiguous on first contact
- the selected state works but should feel more obvious

Decision:

- keep the queue as the primary navigation surface
- increase scannability before adding more information

Recommended refinement:

- make urgency, blockage, and resolution differences more visually obvious
- clarify the clock language
- strengthen the selected-state treatment

### Matter Workspace

Current role:

- deeper current-state summary for the selected matter

What works:

- contains the right categories of information
- is clearly intended as the main explanatory area

What feels muddy:

- most congested panel on the page
- not enough hierarchy between state, risk, and next responsibility
- `workspace` implies action, but the current slice is read-only
- some repeated values are acceptable, but the layout does not yet justify the repetition

Decision:

- keep the content categories
- redesign the hierarchy before broadening the surface

Recommended refinement:

- separate current state, why this matter is in focus, and next responsibility more clearly
- make blocker and next expected move visually stronger
- treat this panel as the highest-priority refinement target

### Context Window

Current role:

- anchor the selected matter into a compressed operator brief

What works:

- excellent question-and-answer flow
- useful framing device for the rest of the page
- low redundancy

What feels muddy:

- `Deterministic operator summary` is implementation language, not user language
- the copy is accurate but still reads machine-composed
- it may need to evolve after the rest of the shell becomes semantically sharper

Decision:

- keep the panel and its three-part structure
- rename it
- refine it later in the sequence, after the workspace content improves

Recommended refinement:

- rename to something like `Operator brief`, `Current situation`, or `Matter brief`
- preserve the current question-and-answer pattern

### Timeline

Current role:

- tell the story of what happened in sequence

What works:

- one of the strongest current surfaces
- supports both technical and newcomer understanding
- naturally answers `what happened?`

What feels muddy:

- raw UTC presentation is not ideal for the default operator experience
- event naming and placement work, but are not yet satisfying visually
- future refinement will likely want more detail and some interaction

Decision:

- keep timeline as a core explanatory surface
- do not de-emphasize it

Recommended refinement:

- move toward localized or human-readable time presentation
- make the latest event more visually prominent
- refine the event label treatment

## Naming Problem: What Is A Matter?

This is a real product issue, not a copy-edit issue.

Current problem:

- `matter` is loaded internal language
- the shell assumes the user already knows what it means
- nowhere on the page grounds the term

Working requirement:

- the product must explain `matter` in-product, even if only once and briefly

Possible direction:

- define a matter as the governed follow-up unit Sentinel is coordinating across systems, people, clocks, and downstream actions

This should be clarified in the UI itself, not only in docs.

Current narrowed direction after `S3.3`:

- keep `matter` as the domain term
- ground it once near the top of the shell in plain operator language
- let the queue and workspace headings explain what the operator should do with the selected matter

## Visual Hierarchy Notes

These are not the full styling pass, but they matter enough to preserve now.

### Grayscale Direction

- the grayscale-first direction is good
- it currently reads more neutral than intentional
- later refinement should keep the restrained base while introducing a very small number of semantic accent colors

Recommended semantic accents later:

- urgency / active clock
- blocked
- resolved / acknowledged
- selected / current focus

### Light / Dark Requirement

Future styling work must support both:

- light mode
- dark mode

This should be treated as a hard requirement for the styling enhancement pass, not an optional later add-on.

The later styling pass should use theme tokens so semantic colors work in both modes.

### Panel Function Vocabulary

The current inspection suggests a useful panel taxonomy:

- `Static`
  - purpose: stable context once the page or current matter is set
  - suggested visual feel: sharper edges, lower emphasis
- `Dynamic`
  - purpose: content that updates as context changes
  - suggested visual feel: slightly more shaped, visibly reactive
- `Interactable`
  - purpose: user can click or otherwise invoke a state change
  - suggested visual feel: higher bevel or stronger click affordance
- `Status/Bubble`
  - purpose: compact, readable status information or filter anchors
  - suggested visual feel: high bevel and strong compact identity

This should inform the styling enhancement pass later.

## Priority Fix Order

Before another planning phase, the current best refinement order is:

1. content inspection follow-through
2. matter workspace hierarchy pass
3. queue meaning/scannability pass
4. context-window rename and copy pass
5. timeline time-format and event-emphasis pass
6. styling enhancement pass with light/dark support

## Practical Refinement Tasks

### Content Inspection Prototype

Goal:

- verify that each visible field earns its place

Tasks:

- mark each field as:
  - keep
  - compress
  - clarify
  - de-emphasize
  - missing
- identify duplicated information that is useful versus duplicated information that is just noise
- identify which labels are internal-facing rather than operator-facing

### Styling Enhancement Prototype

Goal:

- improve hierarchy without widening scope

Tasks:

- preserve the grayscale foundation
- add a small semantic color system
- improve selected-state clarity
- differentiate static, dynamic, interactable, and status surfaces
- design for both light and dark mode from the start

### Dashboard Decongestion Prototype

Goal:

- let the user understand the page piece by piece

Tasks:

- restructure the matter workspace
- separate summary, risk, and next move more clearly
- reduce visual competition across panels

## Open Questions

- what operator-facing term, if any, should supplement or partially replace `matter` in the UI?
- should queue-view labels remain domain-taxonomy terms or shift toward action-oriented labels?
- how much of the context window should feel like a summary versus a handoff note?
- when the shell becomes less read-only, what will count as the first true workspace action?

## Immediate Working Guidance

Until the next planning phase, use this document as the content inspection reference for the current shell.

The current recommendation is:

- do not widen feature scope yet
- refine meaning, hierarchy, and legibility first
- treat light/dark support as a future styling requirement
