# CURRENT TASK

**Feature**: F019 — Flux (AKS extension) for in-cluster add-ons (Phase 05, `phases/PHASE-05-MULTI-REPO.md`)
**Status**: IN PROGRESS (2026-09-30). Last: F018 COMPLETE.

## Exact next step
1. Branch `feat/F019`; contract `verification/contracts/F019.md`.
2. `clusters/base/` (HelmRepository + HelmRelease: traefik, cert-manager, keda, keda-http-add-on at `bootstrap/versions.env`
   pins, same values files; ClusterIssuer, wildcard Certificate, TLSStore, ClusterRole/VAP guard) + `clusters/nimat/` (Kustomization
   patches: domains, identities). Flux adopts the existing Helm releases (same names/namespaces) — no reinstall.
3. OpenTofu (team-cluster): `azurerm_kubernetes_cluster_extension` microsoft.flux + `azurerm_kubernetes_flux_configuration`
   → this repo, path `clusters/nimat`, `dependsOn` ordering. Git auth: public repo? (repo is private → GitHub deploy key / PAT).
4. Proof: Flux Ready; manual drift (e.g. scale traefik) reverted; smoke green; memory headroom on 1× D2as_v7 recorded.

Follow-ups (not on the roadmap; each needs a new FID first; several fold into Phase 05):
1. BLK-008 (→ F020): `bootstrap/teardown.sh` leaves Entra app `gh-preview-deployer` (+SP, federated creds) and UAMI
   `cert-manager-dns`.
2. Untagged ACR manifests (buildx platform/attestation children) are never purged (F011 contract §5).
3. `ubuntu-latest` migrates to Ubuntu 26 from 2026-10-19 (runner notice on every run) — re-run workflows after; pin `ubuntu-24.04` if anything breaks.
4. Cluster RUNNING since 2026-09-30 (F015 e2e) — stop with `az aks stop -g nimatresourceg -n aks-preview` when idle.

## Definition of done (for any new feature)
`AGENTS.md` → Definition of done.
