# CURRENT TASK

**Feature**: F005 — Smoke test `scripts/smoke.sh` (spec Part C)
**Phase**: Phase 01 — Foundation
**Status**: IN PROGRESS

## Exact next step
1. Branch `feat/F005` from `feat/F004`; sprint contract `verification/contracts/F005.md`.
2. Push a real todo image to ACR tagged with the short SHA (`az acr build` or buildx linux/amd64).
3. `scripts/smoke.sh`: ns `preview-smoke`, chart with `idleTimeoutSeconds=120`,
   `ingressClassName=traefik`, trap cleanup; checkpoints: (1) valid HTTPS, (2) cold start 0→1 → 200,
   (3) back to 0 after idle. Deterministic waits (poll state), no blind sleeps.
4. Evidence to `.harness/evidence/F005/`.
Proof: smoke.sh 3/3 checkpoints PASS against aks-preview; init GREEN.

## Acceptance (summary)
See `phases/PHASE-01-FOUNDATION.md` → F005.

## Definition of done
Every acceptance item met + evidence in `CHANGELOG.md` + Evaluator PASS + check-architecture
clean + PR reviewed clean (`AGENTS.md` → Definition of done).
