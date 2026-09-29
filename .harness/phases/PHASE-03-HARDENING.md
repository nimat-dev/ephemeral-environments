# Phase 03 — Hardening — COMPLETE (2026-09-29)

Spec Part E step 6 + A5 hardening note.

## F009 — Scoped k8s ClusterRole
**Status**: COMPLETE (2026-09-29)
- [x] SP AAD object bound to k8s `ClusterRole` limited to namespaces, deployments, services, ingresses, httpscaledobjects, resourcequotas (DEC-024/026; + `preview-deployer-guard` VAP confines writes to `preview-*`, DEC-031).
- [x] Azure `RBAC Writer` assignment removed; F006–F008 still pass. (never assigned; Deploy 36637186203 + Destroy 36637334313 green under the guard)
- [x] Negative test: SP cannot write e.g. secrets in `kube-system`. (bats + live probes `evidence/F009/live-probes.txt`)
- [x] Edge/error cases from `verification/edge-cases.md` (applicable ones) covered by tests.
- [x] Boundary invariants: obeys `rules/layer-boundaries.md` (check-architecture passes).
- [x] Verification: the FULL verify (CLAUDE.md → Commands) passes with zero errors, no regressions.

## F010 — ResourceQuota enforced
**Status**: COMPLETE (2026-09-29)
- [x] Scaling beyond `quota.pods` / cpu / memory is rejected in a preview ns (evidence captured: `evidence/F010/live-quota-check.txt`).
- [x] Edge/error cases from `verification/edge-cases.md` (applicable ones) covered by tests (`tests/quota-check.bats`).
- [x] Boundary invariants: obeys `rules/layer-boundaries.md` (check-architecture passes).
- [x] Verification: the FULL verify (CLAUDE.md → Commands) passes with zero errors, no regressions.

## F011 — Env gate + ACR retention
**Status**: COMPLETE (2026-09-29)
- [x] (Optional, per BLK) required reviewers on `preview` env. — SKIPPED by user decision (DEC-033).
- [x] ACR retention/purge policy for preview SHA tags; documented schedule. (daily 03:17 UTC `preview-acr-purge.yml`, DEC-034; SP dispatch run 36646924565 deleted 2 stale tags, kept 3 newest)
- [x] Edge/error cases from `verification/edge-cases.md` (applicable ones) covered by tests.
- [x] Boundary invariants: obeys `rules/layer-boundaries.md` (check-architecture passes).
- [x] Verification: the FULL verify (CLAUDE.md → Commands) passes with zero errors, no regressions.

## Phase completion criteria
F009–F011 `COMPLETE`; Phase 02 e2e still green under least-privilege identity. — MET 2026-09-29 (Deploy/Destroy green under the F009 guard; purge by SP).
