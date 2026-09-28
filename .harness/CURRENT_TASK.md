# CURRENT TASK

**Feature**: F008 — `.github/workflows/preview-reap.yml`
**Phase**: Phase 02 — Workflows
**Status**: IN PROGRESS
(F006 PR #9 and F007 are IN REVIEW: code + tests + local e2e done; only dispatch e2e open — BLK-009.)

## Exact next step
1. `reap` subcommand in `scripts/preview-ci.sh` (lib `expired_namespaces` + `preview-` name guard),
   thin `preview-reap.yml` (cron `*/30` + dispatch), bats, local e2e with a `1m` lifetime preview.
2. Human: merge PR #8, #9, then F007/F008 PRs into `main` in order (DEC-028).
3. Agent: dispatch e2e for deploy → destroy → reap; mark F006–F008 COMPLETE; Phase 02 COMPLETE.

## Acceptance (summary)
See `phases/PHASE-02-WORKFLOWS.md` → F008.

## Definition of done
Every acceptance item met + evidence in `CHANGELOG.md` + Evaluator PASS + check-architecture
clean + PR reviewed clean (`AGENTS.md` → Definition of done).
