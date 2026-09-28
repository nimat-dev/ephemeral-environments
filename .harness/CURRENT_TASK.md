# CURRENT TASK

**Feature**: F001 — Repo tooling (`init.sh`, `check-architecture.sh`, lint configs)
**Phase**: Phase 01 — Foundation
**Status**: IN PROGRESS

## Exact next step
1. Branch `feat/F001`.
2. Write `scripts/check-architecture.sh`: one function per rule in
   `rules/layer-boundaries.md` (1–9), skip when target path absent, print
   `[error] check-architecture: rule N: <why>` and exit 1 on violation.
3. Add fixtures under `tests/fixtures/arch/` that violate each rule; bats test asserts each fails.
4. Write `scripts/init.sh` per `CLAUDE.md` → Commands (skip missing tools/paths with a warn).
5. Add `.yamllint` (exclude `deploy/preview/templates/`).
Proof: `./scripts/init.sh` green; `bats tests/` shows 9 violation cases failing as expected.

## Acceptance (summary)
See `phases/PHASE-01-FOUNDATION.md` → F001 and the signed
`verification/sprint-contract.md` for this feature.

## Definition of done
Every acceptance item met + evidence in `CHANGELOG.md` + Evaluator PASS + check-architecture
clean + PR reviewed clean (`AGENTS.md` → Definition of done).
