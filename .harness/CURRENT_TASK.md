# CURRENT TASK

**Feature**: F022 — Agent-agnostic harness (Phase 05, `phases/PHASE-05-MULTI-REPO.md`)
**Status**: IN PROGRESS (2026-09-30). Last: F021 COMPLETE.

## Exact next step
Done: kit v1.0.0 released (F021); all F022 pieces built; local verify GREEN (bats 281/281, Copier render, hook e2e — `evidence/F022/`).
1. DONE: PR #28, harness-check CI green, `main` requires `harness-check`; review round 1 fixed (`reviews/F022-review.md`).
2. CI green on the fix push; review round 2 (`loops/pr-review-loop.md`, max 4 rounds).
3. Clean → CHANGELOG COMPLETE entry + evaluator score; ROADMAP/phase/contract COMPLETE; merge.
4. Then F023 (pilot second repo).

Follow-ups (not on the roadmap; each needs a new FID first; several fold into Phase 05):
1. (done: BLK-008 resolved by F020)
2. Untagged ACR manifests (buildx platform/attestation children) are never purged (F011 contract §5).
3. `ubuntu-latest` migrates to Ubuntu 26 from 2026-10-19 (runner notice on every run) — re-run workflows after; pin `ubuntu-24.04` if anything breaks.
4. Cluster RUNNING since 2026-09-30 (F015 e2e) — stop with `az aks stop -g nimatresourceg -n aks-preview` when idle.

## Definition of done (for any new feature)
`AGENTS.md` → Definition of done.
