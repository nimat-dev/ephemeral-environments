# CURRENT TASK

**Feature**: F010 — Prove per-namespace `ResourceQuota` enforced
**Phase**: Phase 03 — Hardening
**Status**: IN PROGRESS (starts after F009 PR is reviewed clean)

## Exact next step
1. F009 PR (`feat/F009`) reviewed clean + merged (`loops/pr-review-loop.md`).
2. Branch `feat/F010` off main; write `verification/contracts/F010.md`.
3. Deploy a throwaway preview; scale beyond `quota.pods` / request beyond cpu/memory →
   rejected (`exceeded quota`); capture evidence `evidence/F010/`. Add bats on chart quota values.

## Acceptance (summary)
See `phases/PHASE-03-HARDENING.md` → F010.

## Definition of done
Every acceptance item met + evidence in `CHANGELOG.md` + Evaluator PASS + check-architecture
clean + PR reviewed clean (`AGENTS.md` → Definition of done).
