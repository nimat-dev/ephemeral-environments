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
**Status**: IN PROGRESS (2026-09-30)
- [ ] Schema-validated `.preview.yaml` in the app repo: `components[]` (name, build.context, build.dockerfile, port, probePath, route, resources), `addons[]` (empty for now), defaults (lifetime, idle, maxReplicas).
- [ ] Chart loops over components (Deployment + Service + HTTPScaledObject each); path routing on one host (`/` web, `/api` backend).
- [ ] Missing file → current single-component behaviour (todo keeps working).
- [ ] Full verify green; e2e deploy of `todo` via `.preview.yaml`.

## F017 — Multiple project domains per cluster
**Status**: NOT STARTED
- [ ] One Azure DNS zone per project domain (delegated from the parent registrar, DEC-040), wildcard A → ingress LB.
- [ ] cert-manager DNS-01 identity has DNS Zone Contributor on each zone; wildcard `Certificate` per domain.
- [ ] Traefik default TLSStore lists every project wildcard cert; SNI serves the right one.
- [ ] e2e: two domains on one cluster, both HTTPS valid.

## F018 — OpenTofu infra stack
**Status**: NOT STARTED
- [ ] `platform/` OpenTofu (latest release at start; DEC-038) module `team-cluster`: RG, AKS (1 node, OIDC + workload identity, Entra RBAC), ACR, identities; one instance per team (DEC-036).
- [ ] Remote state in Azure Storage with locking + OpenTofu state encryption (key in Key Vault).
- [ ] `tofu fmt/validate`, tflint, checkov in `init.sh` + CI; import or recreate current cluster documented.
- [ ] Bash `provision.sh` kept until parity proven (DEC-042).

## F019 — Flux add-ons
**Status**: NOT STARTED
- [ ] OpenTofu installs AKS `microsoft.flux` extension + flux configuration → `clusters/<team>/`.
- [ ] `clusters/base/`: HelmRelease Traefik, cert-manager, KEDA, KEDA HTTP; ClusterIssuer; ClusterRole + VAP guard; ordering via `dependsOn`.
- [ ] Fresh cluster reaches Ready with zero manual steps; manual drift reverted by Flux (evidence).
- [ ] Fits 1× D2as_v7 alongside previews (memory headroom recorded, DEC-041).
- [ ] Smoke (F005) green on a Flux-built cluster; `bootstrap/a1–a4` retired after.

## F020 — Repo onboarding module
**Status**: NOT STARTED
- [ ] OpenTofu module `repo-onboarding`: per-repo Entra app + SP + federated creds (legacy + immutable subject), GitHub env `preview` + vars (`github` provider), DNS zone/cert hookup for its domain.
- [ ] Per-repo SP confined by VAP to `preview-<app>-*` only.
- [ ] Replaces `a5`/`a6`; BLK-008 (teardown leftovers) resolved by `tofu destroy`.

## F021 — Kit extraction + releases
**Status**: NOT STARTED
- [ ] `kit/` composite action (scripts via `github.action_path`) + `workflow_call` deploy/destroy/reap/purge; chart pushed to ACR OCI.
- [ ] Semver release workflow, full tags only (DEC-035); consumer example ≤ 25 lines.
- [ ] This repo's own workflows consume the kit (dogfood).

## F022 — Agent-agnostic harness
**Status**: NOT STARTED
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
