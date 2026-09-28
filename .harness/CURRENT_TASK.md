# CURRENT TASK

**Feature**: F002 — Pure core `scripts/lib/preview.sh` + bats tests
**Phase**: Phase 01 — Foundation
**Status**: IN PROGRESS

## Exact next step
1. Branch `feat/F002` (from `feat/F001`).
2. Write sprint contract `verification/contracts/F002.md` (edge cases: unicode, all-symbol
   branch, >40 chars ending in `-` after cut, each duration unit, invalid unit, `custom` empty,
   `expires-at == now`, missing label).
3. Write `scripts/lib/preview.sh`: `preview_id`, `to_seconds`, `idle_seconds`, `expires_at`,
   `expired_namespaces` (jq). Pure — rule 1 of check-architecture must stay clean.
4. `tests/preview.bats` covering every contract edge case; sanitizer output must match the
   spec's inline sed exactly (compare against it in a test).
Proof: `./scripts/init.sh` BASELINE GREEN; new bats cases pass.

## Acceptance (summary)
See `phases/PHASE-01-FOUNDATION.md` → F002.

## Definition of done
Every acceptance item met + evidence in `CHANGELOG.md` + Evaluator PASS + check-architecture
clean + PR reviewed clean (`AGENTS.md` → Definition of done).
