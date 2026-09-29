# Phase 02 — Workflows — COMPLETE (2026-09-29)

GitHub Actions per spec Part D, on the default branch. Workflows source
`scripts/lib/preview.sh` instead of inlining the sanitizer (DEC-010).

## F006 — `preview-deploy.yml`
**Status**: COMPLETE (2026-09-29)

### Acceptance criteria
- [x] Inputs/permissions/concurrency exactly per `architecture/API_SURFACE.md`.
- [x] Image pushed as `<ACR_LOGIN_SERVER>/<APP_IMAGE_NAME>:<short_sha>`.
- [x] Namespace applied with full label contract (`DATA_MODEL.md`).
- [x] `helm upgrade --install --wait` succeeds; redeploy same branch rolls same release.
- [x] Verify step: 200 within 30×5s (public curl, or in-cluster variant per BLK-003).
- [x] Job summary shows branch, commit, image, namespace, idle, lifetime, URL (`if: always()`).
- [x] actionlint clean.
- [x] Edge/error cases from `verification/edge-cases.md` (applicable ones) covered by tests.
- [x] Boundary invariants: obeys `rules/layer-boundaries.md` (check-architecture passes).
- [x] Verification: the FULL verify (CLAUDE.md → Commands) passes with zero errors, no regressions.
- [x] E2E: dispatch against a test branch; URL works; wakes after idle.

## F007 — `preview-destroy.yml`
**Status**: COMPLETE (2026-09-29)

### Acceptance criteria
- [x] Destroys `preview-<id>` where id is computed by the same lib as deploy.
- [x] Non-existent preview → success (`--ignore-not-found`).
- [x] Edge/error cases from `verification/edge-cases.md` (applicable ones) covered by tests.
- [x] Boundary invariants: obeys `rules/layer-boundaries.md` (check-architecture passes).
- [x] Verification: the FULL verify (CLAUDE.md → Commands) passes with zero errors, no regressions.
- [x] E2E: deploy then destroy test branch; ns gone; URL 404.

## F008 — `preview-reap.yml`
**Status**: COMPLETE (2026-09-29)

### Acceptance criteria
- [x] Cron `*/30 * * * *` + manual dispatch.
- [x] Deletes only `managed-by=preview-bot` ns with `expires-at < now`; "nothing to reap" exit 0 otherwise.
- [x] Never touches non-preview namespaces.
- [x] Edge/error cases from `verification/edge-cases.md` (applicable ones) covered by tests.
- [x] Boundary invariants: obeys `rules/layer-boundaries.md` (check-architecture passes).
- [x] Verification: the FULL verify (CLAUDE.md → Commands) passes with zero errors, no regressions.
- [x] E2E: deploy with `custom` lifetime `1h` (or shorter for test), confirm next reap deletes it.

## Phase completion criteria
F006–F008 `COMPLETE`; full lifecycle deploy → sleep → wake → destroy/reap proven on real
cluster.
