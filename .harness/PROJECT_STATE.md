# PROJECT STATE — MASTER FILE

> Read this first, every session. Rewrite it for a cold reader before you stop.

## Where we are
- **Phase**: ALL COMPLETE — Phase 01 (2026-09-28), Phases 02–04 (2026-09-29)
- **Active feature**: none. Last: F014 action pins → latest full tags (issue #17, DEC-035). Follow-ups in `CURRENT_TASK.md`.
- **Overall progress**: 14 / 14 features COMPLETE (100%)

## Last verified
- **Date**: 2026-09-29
- **init**: green — `./scripts/init.sh` BASELINE GREEN (2026-09-29)
- **Full suite + check-architecture**: green — `bats tests/` 192/192; check-architecture clean (F014, 2026-09-29)
- **E2E**: smoke 3/3; GitHub runs: Deploy 36522067800/36568611973 green + wake 200 after scale-to-0; Reap 36522361188 + scheduled 36558226159 green; Destroy 36568750009 green, URL 404; under F009 guard: Deploy 36637186203 + Destroy 36637334313 green; purge dispatch 36646924565 (SP deleted 2 stale tags); F014 new pins: Deploy 36655482441, Purge 36655484550, Reap 36655486789, Destroy 36655606524 green (`evidence/F006`–`F014`)
- **Git**: PRs #8–#12 merged to `main` (ec256f8; #12 = a5 immutable OIDC subject DEC-030 + review fixes + Phase 02 tracking). PRs #13 (F009) + #14 (F010) merged (bb5468f). PR #15 (F011) merged (733daba); completion tracking on `chore/project-complete`. PR #18 (F014, issue #17) merged to `main`.

## Next step
Roadmap done. Pick a follow-up from `CURRENT_TASK.md` (new FID first) or pause the cluster to stop cost. Mirrors `CURRENT_TASK.md`.

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
- Quota proof: `scripts/quota-check.sh <preview-ns>` (operator-run; fills pods, cleans up). App ceiling is 4 pods (DEC-032).
- SP Azure roles: AcrPush + AcrDelete (purge, DEC-034) + AKS Cluster User.
- CI SP writes are confined to `preview-*` by VAP `preview-deployer-guard` (DEC-031); a new resource type in the chart still needs a ClusterRole rule in a5.
- 2026-09-28 Azure discovery: single subscription, empty RG `nimatresourceg` (eastus); no AKS/ACR/DNS.
  F013 DONE: AKS `aks-preview` (1× D2as_v7, k8s 1.35.8), ACR `nimatpreviewacr`, zone `preview.nimat.dev`.
  PAUSED 2026-09-30 (`az aks stop`) — resume: `az aks start -g nimatresourceg -n aks-preview`; remove: `bootstrap/teardown.sh --yes`.
- Tooling lives outside brew: yamllint (~/.local/bin, pipx), kubeconform (~/go/bin), bats (npm).
  `scripts/init.sh` adds those to PATH. Brew blocked until `sudo xcodebuild -license accept`.
- Hooks (`.claude/settings.json`, DEC-013) enforce the loop: Stop is blocked if you change
  files outside `.harness/` without updating this file.
- App to preview = `todo/` (F012). Deploy workflow (F006) must build `context: todo`.
- The requirement is `.harness/preview-environments-implementation.md` — verbatim file
  contents for chart, workflows, bootstrap. Harness files distill it; the spec wins on detail.
- DEC-010: preview-id sanitizer lives once in `scripts/lib/preview.sh` (spec inlines it twice).
- Most drift-prone file: `httpscaledobject.yaml` (KEDA HTTP add-on pre-1.0).
