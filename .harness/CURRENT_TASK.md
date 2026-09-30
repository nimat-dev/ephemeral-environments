# CURRENT TASK

**Feature**: F016 — `.preview.yaml` app contract with components (Phase 05, `phases/PHASE-05-MULTI-REPO.md`)
**Status**: IN PROGRESS (2026-09-30; no code yet). Last: F015 COMPLETE (PR pending merge).

## Exact next step
1. After F015's PR merges: branch `feat/F016` from main; write `verification/contracts/F016.md` from the phase file.
2. Define `.preview.yaml` schema (components[], addons[], defaults) + validator (jq, pure lib) — tests first.
3. Chart: loop components (Deployment/Service/HTTPScaledObject each), path routing on one host; keep todo working
   with no `.preview.yaml` (single component default). Keep spec files' byte-identity rule (DEC-018) in mind — needs a DEC.
4. Cluster is RUNNING (started 2026-09-30 for F015): `az aks stop -g nimatresourceg -n aks-preview` when idle.

Follow-ups (not on the roadmap; each needs a new FID first; several fold into Phase 05):
1. BLK-008 (→ F020): `bootstrap/teardown.sh` leaves Entra app `gh-preview-deployer` (+SP, federated creds) and UAMI
   `cert-manager-dns`.
2. Untagged ACR manifests (buildx platform/attestation children) are never purged (F011 contract §5).
3. `ubuntu-latest` migrates to Ubuntu 26 from 2026-10-19 (runner notice on every run) — re-run workflows after; pin `ubuntu-24.04` if anything breaks.
4. Cluster RUNNING since 2026-09-30 (F015 e2e) — stop with `az aks stop -g nimatresourceg -n aks-preview` when idle.

## Definition of done (for any new feature)
`AGENTS.md` → Definition of done.
