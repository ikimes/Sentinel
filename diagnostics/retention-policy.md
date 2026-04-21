# Diagnostics Retention Policy

Sentinel uses a curated diagnostics retention model for `Phase A`.

Classifications:

- `canonical-retained`
  - latest active proof for the trusted backbone lanes and live operational snapshot
- `historical-archived`
  - milestone proofs worth keeping for decision traceability, but not part of the active evidence roots
- `disposable`
  - partial, superseded, duplicate, or low-value exploratory artifacts that can be deleted safely after reference checks

Retention defaults:

- Keep the latest canonical green for:
  - `Foundation.A2 Correctness`
  - `Foundation.A3 Resilience`
  - `Foundation.A4 release suite`
  - `Foundation.A4 diagnostic-stress`
  - `Foundation.A4 diagnostic-soak`
  - latest live operational snapshot
- Keep milestone proofs for:
  - first clean strict Phase 3 proof after the old lock-stall issue
  - first canonical Phase A proof after the `phaseA` migration where needed
  - legacy-wrapper compatibility proof where needed
  - MassTransit/Rabbit compatibility migration proof
- Move non-canonical but still useful artifacts into `diagnostics/archive/`
- Delete only artifacts that are:
  - unreferenced
  - clearly partial or aborted
  - superseded by a newer retained proof of the same kind

Authoritative retained map:

- `diagnostics/retained-evidence.json`

