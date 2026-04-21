# Medium-Risk Review Notes

## Persistence Review Outcome

- Reviewed candidate indexes:
  - `dispatch_records(request_id, created_at_utc)` for `export_request_metrics()`
  - `events(request_id, status)` for `wait_for_processed_requests()` and processed-count checks
  - `events(source, processed_at_utc)` for `persistence_timeline.csv` sampling
- These candidates were tested as part of the medium-risk pass and were not retained.
- Reason for rejection:
  - backlog-recovery latency regressed materially while the worker concurrency improvements remained strong without them
  - the medium-risk pass keeps the review outcome captured here, but does not ship the index changes

## Concurrency Review Outcome

- Baseline (`ConcurrentMessageLimit=0`) stayed green but had worse stress and backlog behavior than bounded settings
- `ConcurrentMessageLimit=16` was the strongest balance of stress improvement and release/soak stability
- `ConcurrentMessageLimit=24` stayed green but did not improve enough over `16` to justify making it the default

## Deferred Architecture Review Notes

- Consider whether append-only ledger persistence should remain on the same completion path at higher sustained load
- Consider whether a projection/read model would be useful if verification and operational reads become materially heavier
- Consider whether transport topology or batching changes would pay off only after current worker/persistence tuning is exhausted
- Consider a purpose-built load harness if Phase 4 shell diagnostics become too coarse for deeper capacity work
