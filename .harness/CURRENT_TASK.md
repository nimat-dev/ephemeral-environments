# CURRENT TASK

**Feature**: F022 — Agent-agnostic harness (Phase 05, `phases/PHASE-05-MULTI-REPO.md`)
**Status**: IN PROGRESS (2026-09-30). Last: F021 COMPLETE.

## Exact next step
Done: kit v1.0.0 released (F021); all F022 pieces built; local verify GREEN (bats 281/281, Copier render, hook e2e — `evidence/F022/`).
1. Commit on `feat/F022`; push; open PR → `harness-check` CI must be green (contract §3 e2e).
2. Branch protection: `harness-check` required status check on `main` (admins not enforced).
3. Review PR (`loops/pr-review-loop.md`), fix findings; CHANGELOG COMPLETE entry + evaluator score; ROADMAP/phase COMPLETE.
4. Then F023 (pilot second repo).

Follow-ups (not on the roadmap; each needs a new FID first; several fold into Phase 05):
1. (done: BLK-008 resolved by F020)
2. Untagged ACR manifests (buildx platform/attestation children) are never purged (F011 contract §5).
3. `ubuntu-latest` migrates to Ubuntu 26 from 2026-10-19 (runner notice on every run) — re-run workflows after; pin `ubuntu-24.04` if anything breaks.
4. Cluster RUNNING since 2026-09-30 (F015 e2e) — stop with `az aks stop -g nimatresourceg -n aks-preview` when idle.

## Definition of done (for any new feature)
`AGENTS.md` → Definition of done.
