# PROJECT STATE — MASTER FILE

> Read this first, every session. Rewrite it for a cold reader before you stop.

## Where we are
- **Phase**: Phase 01 — Foundation
- **Active feature**: F001 — Repo tooling (IN PROGRESS, no code yet)
- **Overall progress**: 0 / 11 features COMPLETE (0%)

## Last verified
- **Date**: 2026-09-28
- **init**: N/A — `scripts/init.sh` not written yet (F001)
- **Full suite + check-architecture**: N/A — no code yet
- **E2E**: N/A
- **Git**: branch `main`, commit `2d8e6fb` — Working tree: DIRTY (`.harness/` untracked, `README.md` deleted)

## Next step
Write `scripts/check-architecture.sh` (9 rules in `rules/layer-boundaries.md`, each skipping
when target dir absent), then `scripts/init.sh`. Mirrors `CURRENT_TASK.md`.

## Open blockers
See `BLOCKERS.md`. BLK-001 (no Azure values) and BLK-002 (app repo location) block Phase 01
F004+ and Phase 02; F001–F003 are offline and unblocked.

## Notes for the next agent
- The requirement is `.harness/preview-environments-implementation.md` — verbatim file
  contents for chart, workflows, bootstrap. Harness files distill it; the spec wins on detail.
- DEC-010: preview-id sanitizer lives once in `scripts/lib/preview.sh` (spec inlines it twice).
- Most drift-prone file: `httpscaledobject.yaml` (KEDA HTTP add-on pre-1.0).
