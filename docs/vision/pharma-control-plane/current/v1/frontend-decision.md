# Sentinel Frontend Decision

Status: `decided`

Decision date: `2026-03-16`

## Decision

Sentinel will use `Blazor` for the first engagement-layer frontend.

The default product experience remains:

- matter workspace
- queue
- timeline
- context window

The expert graph view stays in scope, but it is not the default product surface. It is a secondary investigation mode for outages, routing failures, and failed downstream interactions.

## Why This Is The Right Choice

Sentinel's differentiator is explicit coordination across systems.

The highest-value user outcome is not generic workflow completion. It is:

- seeing where coordination is currently held
- understanding which interaction or handoff failed
- delivering findings quickly
- doing that accurately enough that the UI can be trusted during operational incidents

That means the frontend should stay as close as practical to the real coordination model exposed by the .NET backend.

Blazor is the better fit because it supports:

- tighter frontend/backend semantic continuity
- lower drift between coordination truth and UI representation
- a more faithful drill-down experience when operators need to inspect the exact interaction path that failed

## Why Angular Was Not Chosen

Angular remains a credible alternative.

It is stronger if the primary goal is a highly structured standalone enterprise frontend with its own strong architectural guardrails.

It was not chosen because Sentinel's main product value is closer to:

- explicit coordination binding
- message and handoff visibility
- rapid and accurate incident explanation

That makes frontend/backend continuity more valuable than Angular's independent app-shell strengths.

## Product Guardrails

Choosing Blazor does not change the product shape.

Non-negotiable rules:

- default experience stays operator-first
- matter workspace remains the primary screen
- queue, timeline, and context remain first-class
- expert graph mode is secondary
- the graph must clarify the system, not become the product

## JavaScript Interop

The expert graph layer will likely require `JavaScript interop`.

That is acceptable and expected.

Use interop only when:

- the visualization requirement is materially better served by a browser-native graphing library
- the interaction is genuinely investigative rather than standard workspace UI

Do not use interop to reimplement ordinary application surfaces that Blazor can handle directly.

## Implementation Direction

For the first frontend slice:

- build the default operator surfaces in Blazor
- consume the matter-first backend projections already being created in Stage 4
- treat the graph layer as a later expert-mode enhancement
- preserve the current product rule that operational questions come before structural exposure

## Relationship To Existing Vision

This decision is consistent with the current v1 vision:

- `docs/vision/pharma-control-plane/current/v1/system-design.md`
- `docs/vision/pharma-control-plane/current/v1/ui-low-fidelity-wireframes.md`
- `docs/vision/pharma-control-plane/current/v1/design-partner-pilot-scorecard.md`
- `docs/vision/pharma-control-plane/current/v1/build-vs-buy-teardown.md`
- `docs/vision/pharma-control-plane/current/v1/hypothetical-design-partner-assessment.md`

These documents all point to the same product standard:

- make coordination reality legible
- keep the workspace operator-first
- support precise drill-down when issues occur
