# CURRENT TASK

**Feature**: F008 — `.github/workflows/preview-reap.yml`
**Phase**: Phase 02 — Workflows
**Status**: IN PROGRESS
(F006 PR #9 and F007 are IN REVIEW: code + tests + local e2e done; only dispatch e2e open — BLK-009.)

## Exact next step
1. (done) reap subcommand + workflow + bats + local e2e; PR #11.
2. Human: merge PRs #8 → #9 → #10 → #11 into `main` in order (DEC-028, BLK-009).
3. Agent: `gh workflow run preview-deploy.yml -f branch=<test> -f lifetime=custom -f lifetime_custom=1h -f idle_timeout=15m`
   → summary URL 200; wait idle → wake 200; `gh workflow run preview-destroy.yml -f branch=<test>` → 404;
   deploy again with `lifetime_custom=1m` → `gh workflow run preview-reap.yml` → reaped. Record run URLs;
   mark F006–F008 + Phase 02 COMPLETE; then Phase 03 (F009).

## Acceptance (summary)
See `phases/PHASE-02-WORKFLOWS.md` → F008.

## Definition of done
Every acceptance item met + evidence in `CHANGELOG.md` + Evaluator PASS + check-architecture
clean + PR reviewed clean (`AGENTS.md` → Definition of done).
