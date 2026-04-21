# Sentinel Vision Packages

`docs/vision/` is the canonical home for forward-looking, versioned product vision packages.

Vision packages use the same broad retention pattern already established in diagnostics:

- `drafts`
  - active iteration space for in-progress vision work
- `current`
  - the single endorsed canonical version for a package
- `archive`
  - superseded prior canonical versions retained for traceability

Stable linking rule:

- link to the package `README.md` when you want a stable entrypoint
- link to `current/vN/` only when a canonical version has been endorsed
- do not treat `drafts/` as canonical

## Packages

| Package | Purpose | Current status | Canonical link |
|---|---|---|---|
| `docs/vision/pharma-control-plane/README.md` | Pharma-first compliance control-plane wedge with a PV-first starting point | `current v1 endorsed; v2 active draft` | `docs/vision/pharma-control-plane/current/v1/` |

## Iteration Rules

1. Create or revise a draft in `drafts/vN/`.
2. Iterate there until the package story, diagrams, and terminology are stable.
3. Promote the approved draft into `current/vN/`.
4. Move the prior canonical version into `archive/vN-1/`.
5. Update package and top-level indexes so only one canonical version is active.

## Extensibility Rules

- Add future product-vision or market-wedge packages under `docs/vision/`.
- Keep each package self-indexing with its own `README.md`.
- Treat the package `README.md` as the stable target for roadmap and top-level docs links.
