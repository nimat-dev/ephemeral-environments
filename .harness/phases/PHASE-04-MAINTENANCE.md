# Phase 04 — Maintenance — COMPLETE (2026-09-29)

Post-roadmap upkeep. One feature per follow-up; each gated like any other.

## F014 — Pin GitHub Actions to latest full release tags
**Status**: COMPLETE (2026-09-29) — issue #17
- [x] Every `uses:` in `.github/workflows/` is the latest release (GitHub `releases/latest`, checked 2026-09-29) as a full tag, no major-only, no SHA (DEC-035): checkout v7.0.1, azure/login v3.1.0, use-kubelogin v1.3, aks-set-context v5.0.0, setup-buildx-action v4.4.1, build-push-action v7.4.0.
- [x] Breaking changes reviewed: none apply (no `pull_request_target`/`workflow_run`, no removed buildx/build-push inputs).
- [x] Guard test `tests/workflow-pins.bats` (4 tests); negative run with `checkout@v4` fails (`evidence/F014/negative.txt`).
- [x] Boundary invariants: obeys `rules/layer-boundaries.md` (check-architecture passes).
- [x] Verification: FULL verify green (192/192); Deploy/Purge/Reap/Destroy dispatched on CI green, no Node 20 annotation.

## Phase completion criteria
F014 `COMPLETE`. — MET 2026-09-29.
