# CURRENT TASK

**Feature**: F007 — `.github/workflows/preview-destroy.yml`
**Phase**: Phase 02 — Workflows
**Status**: IN PROGRESS (merged to main; only the GitHub dispatch run is open)

## Exact next step
1. `gh workflow run preview-destroy.yml -R nimat-dev/ephemeral-environments --ref main -f branch=e2e/preview-test`
   → ns `preview-e2e-preview-test` gone, URL 404; record run URL in CHANGELOG
   (evidence/F007/dispatch-destroy-e2e.txt). If the ns already got reaped (1h lifetime, ~05:32Z),
   redeploy `e2e/preview-test` first. Also capture the first scheduled reap run.
2. Push `feat/F006-oidc` (a5 immutable OIDC subject, DEC-030), open PR to main, review.
3. Mark F007 + Phase 02 COMPLETE; delete test branches `e2e/preview-test`, `e2e/reap-test`.
4. Phase 03: F009 (namespace-prefix admission guard).

## Acceptance (summary)
See `phases/PHASE-02-WORKFLOWS.md` → F007.

## Definition of done
Every acceptance item met + evidence in `CHANGELOG.md` + Evaluator PASS + check-architecture
clean + PR reviewed clean (`AGENTS.md` → Definition of done).
