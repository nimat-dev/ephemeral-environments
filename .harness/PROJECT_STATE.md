# PROJECT STATE — MASTER FILE

> Read this first, every session. Rewrite it for a cold reader before you stop.

## Where we are
- **Phase**: Phase 03 — Hardening (Phase 01 COMPLETE 2026-09-28, Phase 02 COMPLETE 2026-09-29)
- **Active feature**: F009 — scoped ClusterRole / `preview-*` admission guard (IN PROGRESS, no code yet; starts after `feat/F006-oidc` PR merges). F006–F008 COMPLETE via real GitHub runs.
- **Overall progress**: 10 / 13 features COMPLETE (77%)

## Last verified
- **Date**: 2026-09-29
- **init**: green — `./scripts/init.sh` BASELINE GREEN (2026-09-29)
- **Full suite + check-architecture**: green — `bats tests/` 152/152; check-architecture clean
- **E2E**: smoke 3/3; GitHub runs: Deploy 36522067800/36568611973 green + wake 200 after scale-to-0; Reap 36522361188 + scheduled 36558226159 green; Destroy 36568750009 green, URL 404 (`evidence/F006`–`F008`)
- **Git**: PRs #8–#11 merged to `main` (425ccb8). Branch `feat/F006-oidc` = a5 immutable OIDC subject fix (DEC-030) + F007/Phase 02 tracking, pushed, PR open (see CURRENT_TASK).

## Next step
Merge `feat/F006-oidc` PR, then start F009 on `feat/F009`. Mirrors `CURRENT_TASK.md`.

## Open blockers
See `BLOCKERS.md`. BLK-008 = teardown leaves Entra app + UAMI
(follow-up). BLK-003/BLK-006 resolved.

## Notes for the next agent
- Cluster: Traefik LB 74.151.139.236, `*.preview.nimat.dev` wildcard DNS + LE wildcard cert (Traefik default TLSStore).
  KEDA 2.21 + HTTP add-on 0.16 (interceptor-proxy:8080). Chart needs `--set ingressClassName=traefik`.
- kubectl auth is Entra (kubelogin in ~/go/bin; add to PATH). Break-glass: `az aks get-credentials --admin`.
- GitHub env `preview` + 12 variables SET (A6, 2026-09-28). `gh` active account must be `nimat-dev` (admin); `nimatrazmjo` also logged in but not a collaborator.
- CI SP has NO secrets access (DEC-026): `scripts/preview-ci.sh deploy` forces `HELM_DRIVER=configmap`.
- Workflows are thin: each step = `scripts/preview-ci.sh <cmd>`, inputs via `env:` only (DEC-027).
- No live previews (all test namespaces destroyed/reaped 2026-09-29); test branches `e2e/*` deleted from origin.
- GitHub OIDC for this repo uses immutable subjects (DEC-030) — both federated credentials exist.
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
