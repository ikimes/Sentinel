# Rabbit Compatibility Isolation Runbook

This runbook executes a fixed four-pass matrix to isolate MassTransit durable dispatch behavior against RabbitMQ versions:

- `apphost_4_2`
- `apphost_3_13`
- `direct_4_2`
- `direct_3_13`

## What it captures per pass

- API POST response and request id
- outbox polling snapshots for 30 seconds
- MassTransit persistence snapshots (`masstransit.outbox_message`, `masstransit.outbox_state`, `masstransit.inbox_state`, `masstransit.dispatch_records`)
- Rabbit trace queue dump for `compliance`
- compliance queue stats
- runtime metadata (container names, ports, mode)
- AppHost log or direct API/worker logs
- computed pass classification

## Run

```bash
cd .
chmod +x diagnostics/rabbit-compat/run_matrix.sh
./diagnostics/rabbit-compat/run_matrix.sh
```

Optional custom evidence directory:

```bash
./diagnostics/rabbit-compat/run_matrix.sh /tmp/sentinel-rabbit-compat
```

## Output

The script writes one timestamped folder under:

`diagnostics/rabbit-compat/evidence/<utc-stamp>`

Top-level result file:

- `summary.txt` with pass-level classifications and final classification.
- `manifest.json` with normalized pass metadata and final classification.

Classification values:

- `published+handled`
- `published+deadletter`
- `published+no-handler`
- `not-published`
- final classification:
  - `broker-compat`
  - `app-logic`
  - `apphost-orchestration`
  - `still-unknown`

## Transport Slice (publish vs send)

This slice runs on one Rabbit tag (default `4.2-management`) and compares API send path behavior:

- `apphost_publish`
- `apphost_send`
- `direct_publish`
- `direct_send`

It also captures sender-side MassTransit diagnostics and persistence snapshots.

```bash
chmod +x diagnostics/rabbit-compat/run_transport_slice.sh
./diagnostics/rabbit-compat/run_transport_slice.sh
```

Override Rabbit tag:

```bash
RABBIT_TAG=3.13-management ./diagnostics/rabbit-compat/run_transport_slice.sh
```

Transport slice output also includes:

- `manifest.json` with normalized pass metadata for upstream evidence bundles.

## Notes

- The script intentionally truncates MassTransit persistence tables before each pass to prevent cross-pass contamination.
- It does not mutate product code or package versions.
- Historical Wolverine diagnostics are archived under previous evidence folders for migration traceability.
