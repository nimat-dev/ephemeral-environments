# CURRENT TASK

**Feature**: F009 — Scoped k8s ClusterRole (restrict SP to `preview-*` namespaces)
**Phase**: Phase 03 — Hardening (Phase 02 COMPLETE 2026-09-29)
**Status**: IN PROGRESS (no code yet; starts once the `feat/F006-oidc` PR merges)

## Exact next step
1. Merge PR for `feat/F006-oidc` (a5 immutable OIDC subject DEC-030 + F007/Phase 02 completion tracking).
2. Branch `feat/F009` off main; write `verification/contracts/F009.md`.
3. Most of the ClusterRole already exists (F004, DEC-024: `preview-deployer`, no RBAC Writer).
   Remaining: ValidatingAdmissionPolicy limiting SP namespace create/delete to `preview-*`
   + negative tests (SP can't write secrets in `kube-system`, can't create ns `foo`).
4. Re-run Deploy/Destroy dispatch under the policy (Phase 03 completion needs Phase 02 e2e green).

## Acceptance (summary)
See `phases/PHASE-03-HARDENING.md` → F009.

## Definition of done
Every acceptance item met + evidence in `CHANGELOG.md` + Evaluator PASS + check-architecture
clean + PR reviewed clean (`AGENTS.md` → Definition of done).
