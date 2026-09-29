# CURRENT TASK

**Feature**: F011 — `preview` env required reviewers (optional) + ACR retention for SHA tags
**Phase**: Phase 03 — Hardening
**Status**: IN PROGRESS (code + bats + local dry-run done on `feat/F011`; PR → merge → dispatch e2e)

## Exact next step
1. PR `feat/F011` → review → merge (reviewers skipped DEC-033; purge DEC-034).
2. On main: `gh workflow run preview-acr-purge.yml -f dry_run=true -f max_age=1h -f keep=3`, then
   `-f dry_run=false -f max_age=1h -f keep=3` → oldest tags deleted by the SP, 3 newest kept; record runs
   in CHANGELOG (`evidence/F011/dispatch-purge.txt`).
3. Mark F011 + Phase 03 COMPLETE (13/13) in a harness PR.

## Acceptance (summary)
See `phases/PHASE-03-HARDENING.md` → F011.

## Definition of done
Every acceptance item met + evidence in `CHANGELOG.md` + Evaluator PASS + check-architecture
clean + PR reviewed clean (`AGENTS.md` → Definition of done).
