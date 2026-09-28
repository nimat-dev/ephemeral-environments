# PROJECT STATE — MASTER FILE

> Read this first, every session. Rewrite it for a cold reader before you stop.

## Where we are
- **Phase**: Phase 01 — Foundation
- **Active feature**: F004 — Cluster bootstrap (IN PROGRESS; A2/A3 wait on Namecheap NS delegation)
- **Overall progress**: 5 / 13 features COMPLETE (38%) — F001, F002, F003, F012, F013 done

## Last verified
- **Date**: 2026-09-28
- **init**: green — `./scripts/init.sh` BASELINE GREEN (2026-09-28)
- **Full suite + check-architecture**: green — `bats tests/` 79/79; check-architecture clean
- **E2E**: F013 real apply green (AKS Succeeded, node Ready, ACR pull OK, re-run no-op); F012 local docker
- **Git**: branch `feat/F013` (stack: chore/harness-and-todo → F001 → F002 → F003 → F004 (tracking only) → F013) — pushed; unreviewed (BLK-006, DEC-016).

## Next step
Human: Namecheap NS records for `preview`. Agent: F004 contract + A1/A4–A6 scripts. Mirrors `CURRENT_TASK.md`.

## Open blockers
See `BLOCKERS.md`. BLK-001 (no Azure values) blocks F004+; BLK-002 now only = F006 build
context `todo`; BLK-006 blocks opening PRs via `gh`. F001–F003 offline and unblocked.

## Notes for the next agent
- 2026-09-28 Azure discovery: single subscription, empty RG `nimatresourceg` (eastus); no AKS/ACR/DNS.
  F013 DONE: AKS `aks-preview` (1× D2as_v7, k8s 1.35.8), ACR `nimatpreviewacr`, zone `preview.nimat.dev`.
  COST IS RUNNING — pause: `az aks stop -g nimatresourceg -n aks-preview`; remove: `bootstrap/teardown.sh --yes`.
- Tooling lives outside brew: yamllint (~/.local/bin, pipx), kubeconform (~/go/bin), bats (npm).
  `scripts/init.sh` adds those to PATH. Brew blocked until `sudo xcodebuild -license accept`.
- Hooks (`.claude/settings.json`, DEC-013) enforce the loop: Stop is blocked if you change
  files outside `.harness/` without updating this file.
- App to preview = `todo/` (F012). Deploy workflow (F006) must build `context: todo`.
- The requirement is `.harness/preview-environments-implementation.md` — verbatim file
  contents for chart, workflows, bootstrap. Harness files distill it; the spec wins on detail.
- DEC-010: preview-id sanitizer lives once in `scripts/lib/preview.sh` (spec inlines it twice).
- Most drift-prone file: `httpscaledobject.yaml` (KEDA HTTP add-on pre-1.0).
