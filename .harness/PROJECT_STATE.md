# PROJECT STATE — MASTER FILE

> Read this first, every session. Rewrite it for a cold reader before you stop.

## Where we are
- **Phase**: Phase 02 — Workflows (Phase 01 COMPLETE 2026-09-28)
- **Active feature**: F008 — preview-reap.yml (IN PROGRESS, only e2e on `main` open). F006 PR #9 + F007 PR #10 IN REVIEW. All three built, local e2e green; GitHub-run e2e waits on `main` (BLK-009)
- **Overall progress**: 7 / 13 features COMPLETE (54%) — all of Phase 01

## Last verified
- **Date**: 2026-09-28
- **init**: green — `./scripts/init.sh` BASELINE GREEN (2026-09-28)
- **Full suite + check-architecture**: green — `bats tests/` 151/151; check-architecture clean
- **E2E**: `scripts/smoke.sh` 3/3 PASS twice on aks-preview; Phase 02 entrypoint deploy/destroy/reap run locally vs aks-preview green (`evidence/F006–F008`)
- **Git**: branches feat/F006 → feat/F007 → feat/F008 (each PR targets `main`: #9, #10, #11). PRs #1–#7 merged — but #2–#7 into their parent branches, so `main` only has #1. PR #8 (feat/F005 → main) lands Phase 01; agent merge denied by auto-mode → human must merge #8, then the F006 PR.

## Next step
Human: merge PRs #8 → #9 → #10 → #11 into `main` in that order (BLK-009; agent merge denied by auto-mode). Agent: dispatch Deploy → wake → Destroy, and a 1m-lifetime deploy + Reap run; mark F006–F008 + Phase 02 COMPLETE. Phase 03 stays gated until then. Mirrors `CURRENT_TASK.md`.

## Open blockers
See `BLOCKERS.md`. BLK-009 = dispatch needs Phase 01 + workflows on `main` (human merge); BLK-008 = teardown leaves Entra app + UAMI
(follow-up). BLK-003/BLK-006 resolved.

## Notes for the next agent
- Cluster: Traefik LB 74.151.139.236, `*.preview.nimat.dev` wildcard DNS + LE wildcard cert (Traefik default TLSStore).
  KEDA 2.21 + HTTP add-on 0.16 (interceptor-proxy:8080). Chart needs `--set ingressClassName=traefik`.
- kubectl auth is Entra (kubelogin in ~/go/bin; add to PATH). Break-glass: `az aks get-credentials --admin`.
- GitHub env `preview` + 12 variables SET (A6, 2026-09-28). `gh` active account must be `nimat-dev` (admin); `nimatrazmjo` also logged in but not a collaborator.
- CI SP has NO secrets access (DEC-026): `scripts/preview-ci.sh deploy` forces `HELM_DRIVER=configmap`.
- Workflows are thin: each step = `scripts/preview-ci.sh <cmd>`, inputs via `env:` only (DEC-027).
- `preview-feat-f006` was deployed (F006 local e2e) then destroyed (F007 local e2e).
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
