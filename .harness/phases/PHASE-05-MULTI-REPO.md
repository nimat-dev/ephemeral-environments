# Phase 05 — Multi-repo, reusable platform — IN PROGRESS (2026-09-30)

Goal: any repo of the team can get branch previews on the team's cluster under its own domain,
by consuming a versioned kit, with platform + onboarding in OpenTofu and in-cluster add-ons in
Flux. Harness usable by any coding agent. Decisions: DEC-036–DEC-043.

Target layout (still one repo, DEC-037): `kit/` (action, reusable workflows, chart, scripts),
`platform/` (OpenTofu infra + onboarding modules), `clusters/` (Flux: `base/` + `<team>/`),
`harness/` template. Existing bash stays until its OpenTofu/Flux replacement is proven (DEC-042).

## F015 — Repo-scoped preview identity
**Status**: COMPLETE (2026-09-30) — contract `verification/contracts/F015.md`, evidence `evidence/F015/`
- [x] Namespace `preview-<app>-<branch-id>`; `<app>` from repo var `PREVIEW_APP` (default: repo name, sanitized, ≤ 20). > 63 chars → 54-char prefix + 8-hex cksum.
- [x] Host unchanged: `<branch-id>.<PREVIEW_DOMAIN>` (domain is per project, DEC-040).
- [x] Namespace labels `preview.repo` + `preview.app` (+ annotation `preview.repo-original`); namespace apply, destroy, reap act only on owned namespaces. Purge unchanged (own image repo only; in-use set spans all previews).
- [x] Legacy namespaces without `preview.repo` still destroyable/reapable (bats + live: `preview-f015-legacy` destroyed).
- [x] Two repos, same branch → distinct namespaces; other repo's ns never reaped, destroy refused (bats + live runs 36706523897, 36706594874).
- [x] Edge cases: long names/hash, unicode/symbols, empty app var → repo name, missing/garbled labels, missing `GITHUB_REPOSITORY`.
- [x] Full verify green (206/206); e2e: Deploy 36706339119 (200) + Destroy 36706663297 (404) green on real cluster.

## F016 — `.preview.yaml` app contract with components
**Status**: COMPLETE (2026-09-30) — contract `verification/contracts/F016.md`, evidence `evidence/F016/`, DEC-044–046
- [x] Schema-validated `.preview.yaml` in the app repo: `components[]` (name, context, dockerfile, port, probePath, route, resources), `addons[]` (none supported yet). `defaults` deferred to F021 (DEC-046).
- [x] Chart loops over components (Deployment + Service + HTTPScaledObject each, `pathPrefixes`); one host, interceptor routes `/` web, `/api` api (longest prefix; `/apix` stays on web).
- [x] Missing file → single component from repo root; legacy chart render byte-identical (golden `tests/fixtures/legacy-render.yaml`).
- [x] Full verify green (227/227); e2e: this repo deployed with 2 matrix builds (runs 36708302080, 36710182013), both components idle to 0 and wake independently; Destroy 36710425734 → 404; purge dry-run 36708609459 walks `todo`, `todo/web`, `todo/api`.

## F017 — Multiple project domains per cluster
**Status**: COMPLETE (2026-09-30) — contract `verification/contracts/F017.md`, evidence `evidence/F017/`, DEC-047
- [x] One Azure DNS zone per project domain (`bootstrap/a7-project-domain.sh`; delegated via NS in a parent Azure zone, or NS printed for the registrar), wildcard A → ingress LB.
- [x] cert-manager DNS-01 identity has DNS Zone Contributor on each zone; ClusterIssuer + wildcard `Certificate` per domain.
- [x] Traefik default TLSStore lists every project wildcard cert; SNI serves the right one (default cert unchanged).
- [x] e2e: `shop.preview.nimat.dev` + `preview.nimat.dev` on one cluster, smoke PASS on both, served cert SAN matches each host.

## F018 — OpenTofu infra stack
**Status**: COMPLETE (2026-09-30) — contract `verification/contracts/F018.md`, evidence `evidence/F018/`, DEC-048
- [x] `platform/` OpenTofu 1.12.6 module `team-cluster`: AKS (1 node, OIDC + workload identity, Entra RBAC), ACR + kubelet AcrPull, base DNS zone, cert-manager UAMI + federation + DNS role; RG data-only; one instance per team (`envs/nimat`).
- [x] Remote state in Azure Storage (Entra auth, lease lock, versioning) + OpenTofu state encryption with a Key Vault RSA key (`bootstrap/a0-tofu-state.sh`); blob verified ciphertext-only.
- [x] `tofu fmt/validate/test`, tflint, checkov (justified skips) in `init.sh`; live resources imported (7 imports, 0 changes; re-plan "No changes").
- [x] Bash `provision.sh` kept until parity proven (DEC-042).

## F019 — Flux add-ons
**Status**: COMPLETE (2026-09-30) — contract `verification/contracts/F019.md`, evidence `evidence/F019/`, DEC-049
- [x] OpenTofu installs AKS `microsoft.flux` extension + flux configuration → `clusters/nimat/{releases,config}` (public repo, HTTPS, GC on).
- [x] `clusters/base/`: HelmRelease Traefik, cert-manager, KEDA, KEDA HTTP (dependsOn keda); ClusterRole; team overlay: WI client id, issuers + certs, TLSStore, deployer guard. Existing releases adopted in place (no reinstall).
- [x] Drift reverted (ClusterRole deleted → restored 5s; Flux-owned Deployment field → corrected 25s); `helm uninstall http-add-on` → reinstalled by Flux in 20s. (A brand-new cluster end to end not run: one-cluster quota, no Docker — parked.)
- [x] Fits 1× D2as_v7: Flux 170m after trims, 303m free (3 awake components; 94% with the 2-component preview up).
- [x] Smoke (F005) green on the Flux-managed cluster; a1/a3/a4 marked superseded (kept for non-Flux clusters, DEC-042).

## F020 — Repo onboarding module
**Status**: COMPLETE (2026-09-30) — contract `verification/contracts/F020.md`, evidence `evidence/F020/`, DEC-050
- [x] OpenTofu module `repo-onboarding`: per-repo Entra app + SP + federated creds (legacy + immutable subject), AcrPush/AcrDelete + AKS Cluster User, GitHub env `preview` + 13 vars (`github` provider), generated k8s guard for Flux. This repo imported (21 imports, re-plan No changes).
- [x] Per-repo SP confined by VAP to `preview-<app>-*` only (live probes: `preview-todo-*` allowed; `preview-shop-*`, `preview-*`, kube-system, default denied).
- [x] Replaces `a5`/`a6` (superseded); BLK-008 resolved (identity + UAMI destroyed by `tofu destroy`).

## F021 — Kit extraction + releases
**Status**: COMPLETE (2026-09-30) — contract `verification/contracts/F021.md`, evidence `evidence/F021/`, DEC-051
- [x] `kit/action.yml` composite (scripts via `github.action_path/..`, plan outputs exposed) + `workflow_call` kit-deploy/destroy/reap/purge (kit checked out at `kit_ref` into `.kit`); chart published to ACR OCI by the release.
- [x] Semver release: `scripts/kit-release.sh prepare|verify|publish-chart|github-release` + `kit-release.yml` on tag `vX.Y.Z` (full tags only, DEC-035; rule-7 exception for `contents: write`); consumer example `examples/consumer/preview.yml` 21 lines.
- [x] This repo's workflows consume the kit (dogfood at `github.sha`): Deploy 36724289952, Destroy 36724554226, Reap 36724558780, Purge 36724563167 green.
- [x] `.preview.yaml` `defaults` (lifetime, idle, maxReplicas) fill empty inputs.

## F022 — Agent-agnostic harness
**Status**: IN PROGRESS (2026-09-30)
- [ ] Root `AGENTS.md` canonical; `CLAUDE.md` = `@AGENTS.md`; `.github/copilot-instructions.md` pointer (DEC-043).
- [ ] `.harness/commands/*.md` single source, mirrored to `.claude/commands/` + `.github/prompts/*.prompt.md`.
- [ ] Enforcement in git + CI: pre-commit (roadmap gate, state-updated check) + required `harness-check` status.
- [ ] Copier template of generic harness; generic vs project files split; check-architecture rules from config.

## F023 — Pilot second repo
**Status**: NOT STARTED
- [ ] Second repo onboarded via F020, uses kit via F021, own domain via F017.
- [ ] Same branch name in both repos → both previews live, correct certs; each repo's destroy/reap touches only its own.

## Later (not in this phase)
Key Vault + CSI secrets add-on; Postgres add-on (container per preview → managed server with db-per-preview); split into separate repos (DEC-037).

## Phase completion criteria
F015–F023 `COMPLETE`; pilot (F023) e2e green; Phase 02 e2e still green on a Flux-built cluster.
