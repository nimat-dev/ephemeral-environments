# CURRENT TASK

**Feature**: F023 — Pilot second repo (Phase 05, `phases/PHASE-05-MULTI-REPO.md`)
**Status**: IN PROGRESS (2026-10-01). Last: F022 COMPLETE (2026-10-01).

## Exact next step
Done: F022 PR #28 merged to `main`, kit v1.1.0 prepared and tagged.
1. Write sprint contract for F023 in `.harness/verification/contracts/F023.md`.
2. Onboard second repo via OpenTofu `repo-onboarding` module (`platform/envs/nimat/repos.tf`, `clusters/nimat/config/repos/`).
3. Setup second repo to consume the kit (v1.1.0), with its own domain (`shop.preview.nimat.dev`).
4. Prove two previews on the same branch run simultaneously without cross-repo interference, with independent destroy/reap.
5. Record evidence and PR review loop.

Follow-ups (not on the roadmap; each needs a new FID first; several fold into Phase 05):
1. (done: BLK-008 resolved by F020)
2. Untagged ACR manifests (buildx platform/attestation children) are never purged (F011 contract §5).
3. `ubuntu-latest` migrates to Ubuntu 26 from 2026-10-19 (runner notice on every run) — re-run workflows after; pin `ubuntu-24.04` if anything breaks.
4. Cluster RUNNING since 2026-09-30 (F015 e2e) — stop with `az aks stop -g nimatresourceg -n aks-preview` when idle.

## Definition of done (for any new feature)
`AGENTS.md` → Definition of done.
