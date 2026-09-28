# PROJECT STATE — MASTER FILE

> Read this first, every session. Rewrite it for a cold reader before you stop.

## Where we are
- **Phase**: Phase 01 — Foundation
- **Active feature**: F004 — Cluster bootstrap (IN PROGRESS; offline part workable, apply BLOCKED on BLK-001/004/005)
- **Overall progress**: 4 / 12 features COMPLETE (33%) — F001, F002, F003, F012 done

## Last verified
- **Date**: 2026-09-28
- **init**: green — `./scripts/init.sh` BASELINE GREEN (2026-09-28)
- **Full suite + check-architecture**: green — `bats tests/` 62/62; helm lint + kubeconform active; check-architecture clean (lib=1, templates=8)
- **E2E**: F012 local docker run + curl green; cluster e2e N/A
- **Git**: branch `feat/F004` (stack: chore/harness-and-todo → F001 → F002 → F003 → F004) — F001–F003 pushed, unreviewed (BLK-006, DEC-016).

## Next step
F004: write bootstrap scripts with `--dry-run` + tests offline; applying needs Azure access (BLK-001). Mirrors `CURRENT_TASK.md`.

## Open blockers
See `BLOCKERS.md`. BLK-001 (no Azure values) blocks F004+; BLK-002 now only = F006 build
context `todo`; BLK-006 blocks opening PRs via `gh`. F001–F003 offline and unblocked.

## Notes for the next agent
- 2026-09-28 Azure discovery: single subscription, empty RG `nimatresourceg` (eastus); no AKS/ACR/DNS.
  F004 cannot apply until F013 (provision) is approved and a domain is chosen (BLK-001, BLK-005).
- Tooling lives outside brew: yamllint (~/.local/bin, pipx), kubeconform (~/go/bin), bats (npm).
  `scripts/init.sh` adds those to PATH. Brew blocked until `sudo xcodebuild -license accept`.
- Hooks (`.claude/settings.json`, DEC-013) enforce the loop: Stop is blocked if you change
  files outside `.harness/` without updating this file.
- App to preview = `todo/` (F012). Deploy workflow (F006) must build `context: todo`.
- The requirement is `.harness/preview-environments-implementation.md` — verbatim file
  contents for chart, workflows, bootstrap. Harness files distill it; the spec wins on detail.
- DEC-010: preview-id sanitizer lives once in `scripts/lib/preview.sh` (spec inlines it twice).
- Most drift-prone file: `httpscaledobject.yaml` (KEDA HTTP add-on pre-1.0).
