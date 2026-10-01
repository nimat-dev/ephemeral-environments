# CURRENT TASK

**Feature**: F022 — Agent-agnostic harness (Phase 05, `phases/PHASE-05-MULTI-REPO.md`)
**Status**: COMPLETE (2026-10-01). Next active: F023.

## Exact next step
Done: All F022 pieces built, local verify GREEN (bats 294/294, Copier render, hook e2e), PR #28 open with CI green, review rounds 1–4 complete (29 findings fixed in rounds 1–3, round 4 clean), CHANGELOG / ROADMAP / phase / contract marked COMPLETE.
1. Merge PR #28 (`gh pr merge 28 --squash`).
2. Release kit v1.1.0 (`scripts/kit-release.sh prepare 1.1.0` -> commit -> merge -> tag v1.1.0; first release carrying the Copier template).
3. Start F023: Pilot second repo (write sprint contract in `verification/contracts/F023.md`, onboard second repo via F020, configure kit via F021, and prove isolation).

Follow-ups (not on the roadmap; each needs a new FID first; several fold into Phase 05):
1. (done: BLK-008 resolved by F020)
2. Untagged ACR manifests (buildx platform/attestation children) are never purged (F011 contract §5).
3. `ubuntu-latest` migrates to Ubuntu 26 from 2026-10-19 (runner notice on every run) — re-run workflows after; pin `ubuntu-24.04` if anything breaks.
4. Cluster RUNNING since 2026-09-30 (F015 e2e) — stop with `az aks stop -g nimatresourceg -n aks-preview` when idle.

## Definition of done (for any new feature)
`AGENTS.md` → Definition of done.
