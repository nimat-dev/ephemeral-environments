# PROJECT STATE — MASTER FILE

> Read this first, every session. Rewrite it for a cold reader before you stop.

## Where we are
- **Phase**: Phase 01 — Foundation
- **Active feature**: F001 — Repo tooling (IN PROGRESS, no code yet)
- **Overall progress**: 1 / 12 features COMPLETE (8%) — F012 done

## Last verified
- **Date**: 2026-09-28
- **init**: N/A — `scripts/init.sh` not written yet (F001)
- **Full suite + check-architecture**: N/A — not built yet (F001)
- **E2E**: F012 local docker run + curl green; cluster e2e N/A
- **Git**: branch `chore/harness-and-todo` @ 3bae845+ — pushed, tree clean. PR NOT opened (BLK-006: gh account lacks access). Open manually: https://github.com/nimat-dev/ephemeral-environments/pull/new/chore/harness-and-todo

## Next step
Write `scripts/check-architecture.sh` (9 rules in `rules/layer-boundaries.md`, each skipping
when target dir absent), then `scripts/init.sh`. Mirrors `CURRENT_TASK.md`.

## Open blockers
See `BLOCKERS.md`. BLK-001 (no Azure values) blocks F004+; BLK-002 now only = F006 build
context `todo`; BLK-006 blocks opening PRs via `gh`. F001–F003 offline and unblocked.

## Notes for the next agent
- Hooks (`.claude/settings.json`, DEC-013) enforce the loop: Stop is blocked if you change
  files outside `.harness/` without updating this file.
- App to preview = `todo/` (F012). Deploy workflow (F006) must build `context: todo`.
- The requirement is `.harness/preview-environments-implementation.md` — verbatim file
  contents for chart, workflows, bootstrap. Harness files distill it; the spec wins on detail.
- DEC-010: preview-id sanitizer lives once in `scripts/lib/preview.sh` (spec inlines it twice).
- Most drift-prone file: `httpscaledobject.yaml` (KEDA HTTP add-on pre-1.0).
