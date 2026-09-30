# CURRENT TASK

**Feature**: F018 — OpenTofu infra stack `team-cluster` (Phase 05, `phases/PHASE-05-MULTI-REPO.md`)
**Status**: IN PROGRESS (2026-09-30). Last: F017 COMPLETE.

## Exact next step
1. Branch `feat/F018`; contract `verification/contracts/F018.md`.
2. `platform/` OpenTofu (latest release): state backend (Azure Storage + lock) with OpenTofu state encryption (Key Vault key);
   module `team-cluster` (RG-scoped AKS 1 node OIDC+WI+Entra RBAC, ACR, DNS zone, cert-manager UAMI); `envs/nimat` instance.
3. Import the live resources (no recreate): `tofu import` / import blocks; `tofu plan` → no changes. Bash provision stays (DEC-042).
4. Lint: `tofu fmt -check`, `tofu validate`, tflint, checkov in init.sh.

Follow-ups (not on the roadmap; each needs a new FID first; several fold into Phase 05):
1. BLK-008 (→ F020): `bootstrap/teardown.sh` leaves Entra app `gh-preview-deployer` (+SP, federated creds) and UAMI
   `cert-manager-dns`.
2. Untagged ACR manifests (buildx platform/attestation children) are never purged (F011 contract §5).
3. `ubuntu-latest` migrates to Ubuntu 26 from 2026-10-19 (runner notice on every run) — re-run workflows after; pin `ubuntu-24.04` if anything breaks.
4. Cluster RUNNING since 2026-09-30 (F015 e2e) — stop with `az aks stop -g nimatresourceg -n aks-preview` when idle.

## Definition of done (for any new feature)
`AGENTS.md` → Definition of done.
