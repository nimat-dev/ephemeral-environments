# PROJECT STATE — MASTER FILE

> Read this first, every session. Rewrite it for a cold reader before you stop.

## Where we are
- **Phase**: Phase 01 — Foundation
- **Active feature**: F003 — Helm chart `deploy/preview` (IN PROGRESS, not started)
- **Overall progress**: 3 / 12 features COMPLETE (25%) — F001, F002, F012 done

## Last verified
- **Date**: 2026-09-28
- **init**: green — `./scripts/init.sh` BASELINE GREEN (2026-09-28)
- **Full suite + check-architecture**: green — `bats tests/` 46/46; check-architecture clean (lib=1)
- **E2E**: F012 local docker run + curl green; cluster e2e N/A
- **Git**: branch `feat/F002` (stack: chore/harness-and-todo → feat/F001 → feat/F002) — pushed. No PRs open (BLK-006); F001/F002 unreviewed (DEC-016).

## Next step
F003: sprint contract, then chart verbatim from spec Part B + `tests/chart.bats`. Mirrors `CURRENT_TASK.md`.

## Open blockers
See `BLOCKERS.md`. BLK-001 (no Azure values) blocks F004+; BLK-002 now only = F006 build
context `todo`; BLK-006 blocks opening PRs via `gh`. F001–F003 offline and unblocked.

## Notes for the next agent
- Tooling lives outside brew: yamllint (~/.local/bin, pipx), kubeconform (~/go/bin), bats (npm).
  `scripts/init.sh` adds those to PATH. Brew blocked until `sudo xcodebuild -license accept`.
- Hooks (`.claude/settings.json`, DEC-013) enforce the loop: Stop is blocked if you change
  files outside `.harness/` without updating this file.
- App to preview = `todo/` (F012). Deploy workflow (F006) must build `context: todo`.
- The requirement is `.harness/preview-environments-implementation.md` — verbatim file
  contents for chart, workflows, bootstrap. Harness files distill it; the spec wins on detail.
- DEC-010: preview-id sanitizer lives once in `scripts/lib/preview.sh` (spec inlines it twice).
- Most drift-prone file: `httpscaledobject.yaml` (KEDA HTTP add-on pre-1.0).
