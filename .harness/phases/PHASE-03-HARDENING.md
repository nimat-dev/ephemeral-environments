# Phase 03 — Hardening

Spec Part E step 6 + A5 hardening note.

## F009 — Scoped k8s ClusterRole
**Status**: IN PROGRESS
- [ ] SP AAD object bound to k8s `ClusterRole` limited to namespaces, deployments, services, ingresses, httpscaledobjects, resourcequotas.
- [ ] Azure `RBAC Writer` assignment removed; F006–F008 still pass.
- [ ] Negative test: SP cannot write e.g. secrets in `kube-system`.
- [ ] Edge/error cases from `verification/edge-cases.md` (applicable ones) covered by tests.
- [ ] Boundary invariants: obeys `rules/layer-boundaries.md` (check-architecture passes).
- [ ] Verification: the FULL verify (CLAUDE.md → Commands) passes with zero errors, no regressions.

## F010 — ResourceQuota enforced
**Status**: NOT STARTED
- [ ] Scaling beyond `quota.pods` / cpu / memory is rejected in a preview ns (evidence captured).
- [ ] Edge/error cases from `verification/edge-cases.md` (applicable ones) covered by tests.
- [ ] Boundary invariants: obeys `rules/layer-boundaries.md` (check-architecture passes).
- [ ] Verification: the FULL verify (CLAUDE.md → Commands) passes with zero errors, no regressions.

## F011 — Env gate + ACR retention
**Status**: NOT STARTED
- [ ] (Optional, per BLK) required reviewers on `preview` env.
- [ ] ACR retention/purge policy for preview SHA tags; documented schedule.
- [ ] Edge/error cases from `verification/edge-cases.md` (applicable ones) covered by tests.
- [ ] Boundary invariants: obeys `rules/layer-boundaries.md` (check-architecture passes).
- [ ] Verification: the FULL verify (CLAUDE.md → Commands) passes with zero errors, no regressions.

## Phase completion criteria
F009–F011 `COMPLETE`; Phase 02 e2e still green under least-privilege identity.
