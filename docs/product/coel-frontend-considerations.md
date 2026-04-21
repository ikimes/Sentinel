# COEL Frontend Technology Decision
## Current Decision

Status: `decided`

Decision date: `2026-03-16`

Decision:

- Sentinel will use `Blazor` for the first engagement-layer implementation.
- The default product experience remains:
  - matter workspace
  - queue
  - timeline
  - context window
- An expert graph view remains in scope, but it is not the default screen.
- The expert graph view will likely require targeted `JavaScript interop` for visualization libraries.

Canonical product and vision references:

- `docs/vision/pharma-control-plane/current/v1/frontend-decision.md`
- `docs/vision/pharma-control-plane/current/v1/system-design.md`
- `docs/vision/pharma-control-plane/current/v1/ui-low-fidelity-wireframes.md`
- `docs/vision/pharma-control-plane/current/v1/design-partner-pilot-scorecard.md`
- `docs/vision/pharma-control-plane/current/v1/build-vs-buy-teardown.md`

## Why Blazor

Sentinel's main product value is not generic workflow polish. It is explicit coordination across systems with fast, accurate drill-down into the exact interaction, handoff, or downstream step that failed.

That pushes the frontend choice toward the framework that best preserves fidelity with the backend coordination model:

- message and service interactions should be represented without unnecessary translation drift
- matter state, evidence, and downstream outcomes should stay structurally close to the .NET backend model
- diagnostic drill-down should feel like a faithful view into the system, not a second interpretation of it

Blazor is the better fit for that product shape.

## Why Not Angular

Angular remains a strong option for a disciplined, long-lived enterprise operator application.

It loses here for one specific reason:

- Sentinel's differentiation is not only that it has a structured workspace
- Sentinel's differentiation is that it binds multiple systems into visible coordination and can surface findings quickly and accurately when those interactions fail

If the core product requirement is rapid, explicit drill-down into failed coordination paths, Blazor's tighter .NET continuity is more valuable than Angular's stronger standalone frontend structure.

## Guardrails

This decision is not permission to turn Sentinel into a graph-first product.

Keep these rules:

- the default user experience is the matter workspace
- queue, timeline, and context remain first-class default surfaces
- expert graph mode is a secondary investigation tool
- graph views should explain coordination reality, not replace operator workflow
- use JavaScript interop only where browser-native visualization is materially better than native Blazor rendering

## Implementation Direction

For `S3.1` and later frontend work:

- build the operator workspace in `Blazor`
- keep the current API and projection contracts matter-first
- prefer straightforward Blazor components for workspace, queue, timeline, and context surfaces
- reserve JS interop for the expert graph layer and other clearly visualization-specific needs

Hosting-model note:

- the framework choice is locked as `Blazor`
- the exact hosting shape can still be validated during implementation
- if internal operator usage and infrastructure support it, server-side interactivity is attractive
- if deployment or connection constraints make that unattractive, keep the product choice and revisit hosting, not the framework

## Revisit Criteria

Reopen this decision only if one of these becomes true:

- the product stops needing system-faithful coordination drill-down as a core differentiator
- frontend staffing grows enough that Angular's standalone enterprise structure becomes more valuable than backend/frontend continuity
- hosting constraints prove incompatible with the chosen Blazor delivery shape and cannot be resolved without harming operator usability
