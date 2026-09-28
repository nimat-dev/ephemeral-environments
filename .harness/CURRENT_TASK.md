# CURRENT TASK

**Feature**: F006 — `.github/workflows/preview-deploy.yml`
**Phase**: Phase 02 — Workflows
**Status**: IN REVIEW (code + tests + local e2e done; only the dispatch e2e is open — BLK-009)

## Exact next step
1. Human: merge PR #8 (Phase 01 → main), then the F006 PR (DEC-028: feature PRs target `main`).
2. Agent: `gh workflow run preview-deploy.yml -f branch=<test branch> -f lifetime=24h -f idle_timeout=15m`;
   job summary URL returns 200 after cold start; record run URL in CHANGELOG; mark F006 COMPLETE.
3. Meanwhile (unblocked, same phase): F007 destroy, F008 reap — add `destroy`/`reap` to
   `scripts/preview-ci.sh`, thin workflows, bats, local e2e.

## Acceptance (summary)
See `phases/PHASE-02-WORKFLOWS.md` → F006.

## Definition of done
Every acceptance item met + evidence in `CHANGELOG.md` + Evaluator PASS + check-architecture
clean + PR reviewed clean (`AGENTS.md` → Definition of done).
