# CURRENT TASK

**Feature**: F011 — `preview` env required reviewers (optional) + ACR retention for SHA tags
**Phase**: Phase 03 — Hardening
**Status**: IN PROGRESS (no code yet; branch `feat/F011`; F010 PR #14 merged)

## Exact next step
1. Write `verification/contracts/F011.md` (branch `feat/F011` exists).
2. Decide env reviewers (optional per phase file) — ask human; don't enable silently (it gates every deploy).
3. ACR retention for preview SHA tags on Basic SKU (no built-in retention policy on Basic — check;
   likely a scheduled `az acr run --cmd "acr purge …"` or workflow) + documented schedule + tests.
4. Phase 03 completion: F009–F011 COMPLETE + Phase 02 e2e green under least privilege (done in F009).

## Acceptance (summary)
See `phases/PHASE-03-HARDENING.md` → F011.

## Definition of done
Every acceptance item met + evidence in `CHANGELOG.md` + Evaluator PASS + check-architecture
clean + PR reviewed clean (`AGENTS.md` → Definition of done).
