# CURRENT TASK

**Feature**: F015 — Repo-scoped preview identity (Phase 05, `phases/PHASE-05-MULTI-REPO.md`)
**Status**: IN PROGRESS (planned 2026-09-30; no code yet)

## Exact next step
1. Branch `feat/F015` from main. Write `verification/contracts/F015.md` (sprint contract) from the phase file.
2. `scripts/lib/preview.sh`: `preview_app` sanitizer, `preview_namespace APP ID` (≤63, hash suffix), `preview.repo` label
   in `namespace_manifest`; scope `expired_namespaces`/destroy/purge by repo (legacy no-label ns = own). Tests first (bats).
3. Workflows: pass `PREVIEW_APP`/`GITHUB_REPOSITORY` env; a6 sets `PREVIEW_APP`. VAP/ClusterRole unchanged (still `preview-*`).
4. Cluster is PAUSED: `az aks start` before e2e, `az aks stop` after.

Follow-ups (not on the roadmap; each needs a new FID first; several fold into Phase 05):
1. BLK-008 (→ F020): `bootstrap/teardown.sh` leaves Entra app `gh-preview-deployer` (+SP, federated creds) and UAMI
   `cert-manager-dns`.
2. Untagged ACR manifests (buildx platform/attestation children) are never purged (F011 contract §5).
3. `ubuntu-latest` migrates to Ubuntu 26 from 2026-10-19 (runner notice on every run) — re-run workflows after; pin `ubuntu-24.04` if anything breaks.
4. Cluster PAUSED 2026-09-30 — `az aks start -g nimatresourceg -n aks-preview` before any e2e; remove with `bootstrap/teardown.sh --yes`.

## Definition of done (for any new feature)
`AGENTS.md` → Definition of done.
