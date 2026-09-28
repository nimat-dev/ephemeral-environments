# Phase 02 — Workflows

GitHub Actions per spec Part D, on the default branch. Workflows source
`scripts/lib/preview.sh` instead of inlining the sanitizer (DEC-010).

## F006 — `preview-deploy.yml`
**Status**: NOT STARTED

### Acceptance criteria
- [ ] Inputs/permissions/concurrency exactly per `architecture/API_SURFACE.md`.
- [ ] Image pushed as `<ACR_LOGIN_SERVER>/<APP_IMAGE_NAME>:<short_sha>`.
- [ ] Namespace applied with full label contract (`DATA_MODEL.md`).
- [ ] `helm upgrade --install --wait` succeeds; redeploy same branch rolls same release.
- [ ] Verify step: 200 within 30×5s (public curl, or in-cluster variant per BLK-003).
- [ ] Job summary shows branch, commit, image, namespace, idle, lifetime, URL (`if: always()`).
- [ ] actionlint clean.
- [ ] Edge/error cases from `verification/edge-cases.md` (applicable ones) covered by tests.
- [ ] Boundary invariants: obeys `rules/layer-boundaries.md` (check-architecture passes).
- [ ] Verification: the FULL verify (CLAUDE.md → Commands) passes with zero errors, no regressions.
- [ ] E2E: dispatch against a test branch; URL works; wakes after idle.

## F007 — `preview-destroy.yml`
**Status**: NOT STARTED

### Acceptance criteria
- [ ] Destroys `preview-<id>` where id is computed by the same lib as deploy.
- [ ] Non-existent preview → success (`--ignore-not-found`).
- [ ] Edge/error cases from `verification/edge-cases.md` (applicable ones) covered by tests.
- [ ] Boundary invariants: obeys `rules/layer-boundaries.md` (check-architecture passes).
- [ ] Verification: the FULL verify (CLAUDE.md → Commands) passes with zero errors, no regressions.
- [ ] E2E: deploy then destroy test branch; ns gone; URL 404.

## F008 — `preview-reap.yml`
**Status**: NOT STARTED

### Acceptance criteria
- [ ] Cron `*/30 * * * *` + manual dispatch.
- [ ] Deletes only `managed-by=preview-bot` ns with `expires-at < now`; "nothing to reap" exit 0 otherwise.
- [ ] Never touches non-preview namespaces.
- [ ] Edge/error cases from `verification/edge-cases.md` (applicable ones) covered by tests.
- [ ] Boundary invariants: obeys `rules/layer-boundaries.md` (check-architecture passes).
- [ ] Verification: the FULL verify (CLAUDE.md → Commands) passes with zero errors, no regressions.
- [ ] E2E: deploy with `custom` lifetime `1h` (or shorter for test), confirm next reap deletes it.

## Phase completion criteria
F006–F008 `COMPLETE`; full lifecycle deploy → sleep → wake → destroy/reap proven on real
cluster.
