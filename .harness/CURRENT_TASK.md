# CURRENT TASK

**Feature**: F020 — OpenTofu `repo-onboarding` module (Phase 05, `phases/PHASE-05-MULTI-REPO.md`)
**Status**: IN PROGRESS (2026-09-30). Last: F019 COMPLETE.

## Exact next step
0. After the F019 PR merges: `cd platform/envs/nimat && tofu apply` (Flux branch feat/F019 → main); check GitRepository revision main@….
1. Branch `feat/F020`; contract `verification/contracts/F020.md`.
2. Module `repo-onboarding` (azuread + github providers): per-repo Entra app + SP + federated creds (legacy + immutable subject),
   AcrPush/AcrDelete + AKS Cluster User, GitHub env `preview` + variables; Flux-side: per-repo ClusterRoleBinding + VAP guard
   confined to `preview-<app>-*`. Import this repo's existing app/SP/creds/vars (no recreate).
3. BLK-008 (teardown leftovers) closes via `tofu destroy` of the onboarding instance.

Follow-ups (not on the roadmap; each needs a new FID first; several fold into Phase 05):
1. BLK-008 (→ F020): `bootstrap/teardown.sh` leaves Entra app `gh-preview-deployer` (+SP, federated creds) and UAMI
   `cert-manager-dns`.
2. Untagged ACR manifests (buildx platform/attestation children) are never purged (F011 contract §5).
3. `ubuntu-latest` migrates to Ubuntu 26 from 2026-10-19 (runner notice on every run) — re-run workflows after; pin `ubuntu-24.04` if anything breaks.
4. Cluster RUNNING since 2026-09-30 (F015 e2e) — stop with `az aks stop -g nimatresourceg -n aks-preview` when idle.

## Definition of done (for any new feature)
`AGENTS.md` → Definition of done.
