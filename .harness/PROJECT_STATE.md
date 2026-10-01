# PROJECT STATE — MASTER FILE

> Read this first, every session. Rewrite it for a cold reader before you stop.

## Where we are
- **Phase**: Phase 05 — Multi-repo, reusable platform — COMPLETE (2026-10-01). Phases 01–05 COMPLETE.
- **Active feature**: Roadmap COMPLETE (23 / 23 features, 100%). Last: F023 pilot second repo COMPLETE (2026-10-01).
- **Overall progress**: 23 / 23 features COMPLETE (100%)

## Last verified
- **Date**: 2026-10-01
- **init**: green — `./scripts/init.sh` BASELINE GREEN (2026-10-01, F023 local)
- **Full suite + check-architecture**: green — `bats tests/` 294/294 + tofu test 10/10 + tflint/checkov; check-architecture clean (F023, 2026-10-01)
- **E2E**: smoke 3/3; GitHub runs: Deploy 36522067800/36568611973 green + wake 200 after scale-to-0; Reap 36522361188 + scheduled 36558226159 green; Destroy 36568750009 green, URL 404; under F009 guard: Deploy 36637186203 + Destroy 36637334313 green; purge dispatch 36646924565 (SP deleted 2 stale tags); F014 new pins: Deploy 36655482441, Purge 36655484550, Reap 36655486789, Destroy 36655606524 green; F015: Deploy 36706339119 (ns `preview-todo-feat-f015`, 200), Reap 36706523897 (foreign expired ns kept), Destroy 36706532056 (legacy) / 36706594874 (foreign refused) / 36706663297 (404) ; F016: Deploy 36708302080/36710182013 (2 components, path routing, per-component scale-to-zero), Destroy 36710425734 ; F017: smoke PASS on `shop.preview.nimat.dev` + `preview.nimat.dev` ; F018: OpenTofu adopted 7 resources, plan No changes; regression Deploy 36713711855 + Destroy 36714179601 ; F019: Flux adopted add-ons, drift reverted, reinstall from scratch, smoke + Deploy 36720360228/Destroy 36720632838 ; F020: per-repo guard probes, Deploy 36722280404 + Destroy 36722549593 ; F021 dogfood via kit: Deploy 36724289952, Destroy 36724554226, Reap 36724558780, Purge 36724563167 (`evidence/F006`–`F021`); F022: pre-commit hook e2e + harness-check CI green (run 36786821360); F023: live pilot `nimat-dev/shop` onboarded, concurrent previews on `feat/pilot` (runs 36855731738 & 36855603644), SNI routing + distinct Let's Encrypt TLS certs, isolated destroy (run 36855956101 -> shop 404, todo 200; `evidence/F023/`)
- **Git**: PRs #8–#12 merged to `main` (ec256f8; #12 = a5 immutable OIDC subject DEC-030 + review fixes + Phase 02 tracking). PRs #13 (F009) + #14 (F010) merged (bb5468f). PR #15 (F011) merged (733daba); completion tracking on `chore/project-complete`. PR #18 (F014, issue #17) merged to `main`. PR #19 (cluster paused) merged (45a50da). PR #20 (Phase 05 plan) merged (084f9b0). PR #21 (F015) merged (ee1a62b). PR #22 (F016) merged (2cdcf0a). PR #23 (F017) merged (09f100e). PR #24 (F018) merged (09c2c5c). PR #25 (F019) merged (cdaaeac), Flux on main. PR #26 (F020) merged (dbfd648); Flux pruned the global guard (only `*-todo` left). PR #27 (F021) merged (9c68fe0); kit v1.0.0 released (run 36724767086). PR #28 (F022) merged to `main`. Kit v1.1.0 released (run 36854895287).
  F023 on `feat/F023` ready for PR.

## Next step
1. Open PR for `feat/F023` (F023: Pilot second repo) and merge to `main`.
2. Pause AKS cluster when idle: `az aks stop -g nimatresourceg -n aks-preview`.
Mirrors `CURRENT_TASK.md`.

## Open blockers
See `BLOCKERS.md`. BLK-008 resolved (F020). BLK-003/BLK-006 resolved.

## Notes for the next agent
- Cluster: Traefik LB 74.151.139.236, `*.preview.nimat.dev` wildcard DNS + LE wildcard cert (Traefik default TLSStore).
  KEDA 2.21 + HTTP add-on 0.16 (interceptor-proxy:8080). Chart needs `--set ingressClassName=traefik`.
- kubectl auth is Entra (kubelogin in ~/go/bin; add to PATH). Break-glass: `az aks get-credentials --admin`.
- GitHub env `preview` + 12 variables SET (A6, 2026-09-28). `gh` active account must be `nimat-dev` (admin); `nimatrazmjo` also logged in but not a collaborator.
- CI SP has NO secrets access (DEC-026): `scripts/preview-ci.sh deploy` forces `HELM_DRIVER=configmap`.
- Workflows are thin: each step = `scripts/preview-ci.sh <cmd>`, inputs via `env:` only (DEC-027).
- Other repos consume the kit: `examples/consumer/` (pin `kit-*.yml@vX.Y.Z`); release = `scripts/kit-release.sh prepare X.Y.Z` → merge → tag (DEC-051).
- Repos are onboarded in `platform/envs/nimat/repos.tf` (DEC-050; `GITHUB_TOKEN=$(gh auth token) tofu apply`, then commit `clusters/nimat/config/repos/`).
- In-cluster add-ons are Flux (`clusters/nimat`, AKS extension, DEC-049): change them in git, not with helm/kubectl. `kubectl get hr,ks -n flux-system`.
- Infra is OpenTofu (`platform/envs/nimat`, encrypted state in `nimattofustate` + key `nimat-tofu-kv/tofu-state`, DEC-048); bash provision kept (DEC-042).
- Second test domain `shop.preview.nimat.dev` (child zone, a7, DEC-047); Traefik TLSStore serves both wildcards by SNI.
- Apps declare components in `.preview.yaml` (F016); images `<ACR>/<APP_IMAGE_NAME>/<component>:<sha>`; this repo: web (todo) + api (examples/echo-api).
- Namespaces are `preview-<app>-<branch>` + `preview.repo` ownership label (F015); repo var `PREVIEW_APP=todo`. Legacy `preview-<id>` still destroyable.
- No live previews (all test namespaces destroyed 2026-09-30); test branches `e2e/*` deleted from origin.
- GitHub OIDC for this repo uses immutable subjects (DEC-030) — both federated credentials exist.
- Quota proof: `scripts/quota-check.sh <preview-ns>` (operator-run; fills pods, cleans up). App ceiling is 4 pods (DEC-032).
- SP Azure roles: AcrPush + AcrDelete (purge, DEC-034) + AKS Cluster User.
- CI SP writes are confined to `preview-*` by VAP `preview-deployer-guard` (DEC-031); a new resource type in the chart still needs a ClusterRole rule in a5.
- 2026-09-28 Azure discovery: single subscription, empty RG `nimatresourceg` (eastus); no AKS/ACR/DNS.
  F013 DONE: AKS `aks-preview` (1× D2as_v7, k8s 1.35.8), ACR `nimatpreviewacr`, zone `preview.nimat.dev`.
  RUNNING since 2026-09-30 (F015 e2e) — pause: `az aks stop -g nimatresourceg -n aks-preview`; remove: `bootstrap/teardown.sh --yes`.
- Tooling lives outside brew: yamllint (~/.local/bin, pipx), kubeconform (~/go/bin), bats (npm).
  `scripts/init.sh` adds those to PATH. Brew blocked until `sudo xcodebuild -license accept`.
- Hooks (`.claude/settings.json`, DEC-013) enforce the loop: Stop is blocked if you change
  files outside `.harness/` without updating this file.
- App to preview = `todo/` (F012). Deploy workflow (F006) must build `context: todo`.
- The requirement is `.harness/preview-environments-implementation.md` — verbatim file
  contents for chart, workflows, bootstrap. Harness files distill it; the spec wins on detail.
- DEC-010: preview-id sanitizer lives once in `scripts/lib/preview.sh` (spec inlines it twice).
- Most drift-prone file: `httpscaledobject.yaml` (KEDA HTTP add-on pre-1.0).
