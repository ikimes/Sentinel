# v2 Avoid

Status: `three-pass working draft`

Package root:

- `docs/vision/pharma-control-plane/README.md`

Discovery baseline:

- `docs/vision/pharma-control-plane/current/v1/`

## Purpose

Identify what Sentinel should avoid so the product does not collapse into suite replacement, generic workflow, generic AI, or generic reporting.

This axis matters because `v1` made the product more coherent mostly by subtraction.

`v2` should preserve that discipline.

## Inputs from current/v1

- `docs/vision/pharma-control-plane/current/v1/v1-discovery-wrap-and-strategic-thesis.md`
- `docs/vision/pharma-control-plane/current/v1/beliefs-doubts-and-must-prove-next.md`
- `docs/vision/pharma-control-plane/current/v1/competitive-positioning-comparison.md`
- `docs/vision/pharma-control-plane/current/v1/analog-market-entry-and-lessons.md`
- `docs/vision/pharma-control-plane/current/v1/hypothetical-design-partner-assessment.md`
- `docs/vision/pharma-control-plane/current/v1/hypothetical-design-partner-assessment-weaker.md`
- `docs/vision/pharma-control-plane/current/v1/build-vs-buy-teardown.md`

## Pass 1: Wide-Range Initial Pass

The broad set of traps to avoid from `v1` is:

### 1. Avoid broad control-plane or platform-first entry language

This weakens the wedge by making Sentinel sound bigger than the first proof.

### 2. Avoid suite-replacement ambition

If Sentinel starts trying to become the safety suite, the system of record, or the authority gateway, it walks directly into incumbent strength.

### 3. Avoid generic workflow and ticketing drift

If the workspace degrades into tasks, queues, and status fields without a strong matter model, Sentinel becomes easy to imitate.

### 4. Avoid graph-first product identity

The graph can be useful as expert drill-down.

It should not be the front door.

### 5. Avoid AI-first positioning

AI may improve timing and interaction quality.

It should not be the reason the product exists.

### 6. Avoid visibility-only or analytics-only value

If the product becomes "one more place to see status," it loses to dashboards and incumbent reports.

### 7. Avoid integration-heavy first proof

If value appears only after many systems and long implementation work, the wedge becomes commercially weak.

### 8. Avoid a broad regulatory-content engine too early

Jurisdictions, clocks, and obligations matter.

But a full content and rules program too early risks services drift and platform inflation.

### 9. Avoid buyer diffusion

If the pain spans many teams but no one owns the budget or approval path, the product remains believable and unbuyable.

### 10. Avoid choosing customers whose pain is real but too light

The weak hypothetical partner shows that Sentinel can look good and still not matter enough.

### 11. Avoid proving elegance instead of proving necessity

Good doctrine, clean diagrams, and good UI can still mask weak demand.

### 12. Avoid over-constraining the first proof for strategic beauty

The current docs already question whether cross-jurisdiction complexity must exist on day one.

Sentinel should avoid making the first proof harder than necessary just to preserve narrative elegance.

## Pass 2: Narrow-Hardening Pass

Using the `copy` and `uniquely-prove` pass-1 outputs, the avoid set narrows into a smaller number of high-risk failure modes.

### 1. Avoid any move that makes Sentinel look like a replacement platform

This remains the most strategically dangerous drift because it destroys the overlay advantage and invites the strongest competition.

### 2. Avoid any product shape that can be mistaken for generic workflow, dashboards, or graph visualization

This survives because `copy` pass-1 says operator workspace and context compression only matter when they support governed action, and `uniquely-prove` pass-1 says the product must beat ServiceNow and analytics on substance, not just presentation.

### 3. Avoid first proofs that depend on too much implementation, too many systems, or too much rule authoring

This survives because minimal-footprint proof is one of the strongest copied behaviors and one of the strongest unique proof needs.

### 4. Avoid customer-specific model sprawl and services drift

This survives because the stable-core-model question is one of the central unresolved risks from `v1`.

### 5. Avoid buyers whose pain does not concentrate into a real software decision

This survives because the weak hypothetical partner fails precisely here.

### 6. Avoid over-optimizing the first version for international elegance if a simpler first proof would validate faster

This becomes more important in `v2`.

It is the clearest near-new emphasis that emerges from `v1`:

Sentinel should not force the strategically cleanest narrative if it weakens the first commercial proof.

## Pass 3: Final Narrow-Hardening Pass

The final avoid set should be treated as no-go rules.

### Rule 1: Avoid entering as a broad platform or suite-replacement story

Why it survives:

- It collides with incumbent strength and destroys the overlay thesis.
- It is directly contradicted by the healthiest `v1` learning.

Evidence:

- `v1-discovery-wrap-and-strategic-thesis.md`
- `competitive-positioning-comparison.md`
- `analog-market-entry-and-lessons.md`

Failure mode it prevents:

- Sentinel becoming strategically incoherent and commercially non-credible

### Rule 2: Avoid any product surface that can be summarized as workflow, dashboards, graphing, or AI summaries

Why it survives:

- Sentinel only has a reason to exist when the workspace, evidence trail, and coordination state stay tightly bound.

Evidence:

- `competitive-positioning-comparison.md`
- `build-vs-buy-teardown.md`
- `product-doctrine-options.md`

Failure mode it prevents:

- collapsing into adjacent categories with weaker distinctness and higher substitutability

### Rule 3: Avoid first proofs that require many integrations or a large rules engine before value appears

Why it survives:

- Buyers will not endure a large implementation just to test whether the wedge is real.

Evidence:

- `minimal-integration-proof.md`
- `hypothetical-design-partner-assessment.md`
- `beliefs-doubts-and-must-prove-next.md`

Failure mode it prevents:

- turning the MVP into an enterprise program instead of a product proof

### Rule 4: Avoid model drift into bespoke services and customer-specific ontology sprawl

Why it survives:

- Stable primitives are required for both the buy case and the expansion law.

Evidence:

- `beliefs-doubts-and-must-prove-next.md`
- `build-vs-buy-teardown.md`
- `system-design.md`

Failure mode it prevents:

- winning only through consulting effort and losing repeatability

### Rule 5: Avoid weakly qualified customers whose pain is visible but not concentrated

Why it survives:

- The weak hypothetical partner shows how easily Sentinel can become a nice improvement instead of a must-buy tool.

Evidence:

- `hypothetical-design-partner-assessment-weaker.md`
- `matter-frequency-and-pain-scorecard.md`
- `economic-buyer-map.md`

Failure mode it prevents:

- false-positive demand signals and weak early design partners

### Rule 6: Avoid preserving strategic elegance at the expense of fast proof

Why it survives:

- The first proof must earn the right to a broader or more international story.

Evidence:

- `beliefs-doubts-and-must-prove-next.md`
- `minimal-integration-proof.md`
- `v1-discovery-wrap-and-strategic-thesis.md`

Failure mode it prevents:

- building the hardest version first and mistaking ambition for validation

## Locked Conclusions

- The biggest things to avoid are not cosmetic mistakes. They are category-collapse mistakes and implementation-shape mistakes.
- Sentinel should treat replacement drift, generic-tool drift, services drift, and weak-customer drift as primary hazards.
- The first proof should favor disciplined speed over strategic grandeur.

## Still Open

- how strict the customer qualification bar should be before engaging in real discovery
- whether the first explicit no-go boundary should be framed more around buyer weakness or workflow weakness
