# CURRENT TASK

**Feature**: F022 — Agent-agnostic harness (Phase 05, `phases/PHASE-05-MULTI-REPO.md`)
**Status**: IN PROGRESS (2026-09-30). Last: F021 COMPLETE.

## Exact next step
0. After the F021 PR merges: `git tag v1.0.0 <merge sha> && git push origin v1.0.0` → Kit - Release green; record chart + release.
1. Branch `feat/F022`; contract `verification/contracts/F022.md`.
2. Root `AGENTS.md` canonical (CLAUDE.md → `@AGENTS.md`, `.github/copilot-instructions.md` pointer); `.harness/commands/*.md`
   mirrored to `.claude/commands/` + `.github/prompts/*.prompt.md`; pre-commit (roadmap gate + state-updated check) + CI `harness-check`;
   Copier template of the generic harness; check-architecture rules from config.

Follow-ups (not on the roadmap; each needs a new FID first; several fold into Phase 05):
1. (done: BLK-008 resolved by F020)
2. Untagged ACR manifests (buildx platform/attestation children) are never purged (F011 contract §5).
3. `ubuntu-latest` migrates to Ubuntu 26 from 2026-10-19 (runner notice on every run) — re-run workflows after; pin `ubuntu-24.04` if anything breaks.
4. Cluster RUNNING since 2026-09-30 (F015 e2e) — stop with `az aks stop -g nimatresourceg -n aks-preview` when idle.

## Definition of done (for any new feature)
`AGENTS.md` → Definition of done.
