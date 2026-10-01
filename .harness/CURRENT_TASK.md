# CURRENT TASK

**Feature**: F023 — Pilot second repo (Phase 05, `phases/PHASE-05-MULTI-REPO.md`)
**Status**: COMPLETE (2026-10-01). Full Roadmap COMPLETE (23/23, 100%).

## Exact next step
Done: `nimat-dev/shop` onboarded, live multi-tenant deployments verified simultaneously on `feat/pilot`, isolated destroy verified, full `./scripts/init.sh` BASELINE GREEN (294/294 tests).
1. Open PR for `feat/F023` to `main`, ensure `harness-check` CI passes, review clean, and merge.
2. Pause test cluster when done: `az aks stop -g nimatresourceg -n aks-preview`.

Follow-ups (not on the roadmap; each needs a new FID first; several fold into Phase 05):
1. (done: BLK-008 resolved by F020)
2. Untagged ACR manifests (buildx platform/attestation children) are never purged (F011 contract §5).
3. `ubuntu-latest` migrates to Ubuntu 26 from 2026-10-19 (runner notice on every run) — re-run workflows after; pin `ubuntu-24.04` if anything breaks.
4. Cluster RUNNING since 2026-09-30 (F015 e2e) — stop with `az aks stop -g nimatresourceg -n aks-preview` when idle.

## Definition of done (for any new feature)
`AGENTS.md` → Definition of done.
