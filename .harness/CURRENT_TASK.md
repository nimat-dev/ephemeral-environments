# CURRENT TASK

**Feature**: F013 — Provision Azure prerequisites (AKS + ACR + DNS zone)
**Phase**: Phase 01 — Foundation
**Status**: IN PROGRESS (F004 BLOCKED behind it)

## Exact next step
1. Branch `feat/F013` from `feat/F004`.
2. Sprint contract `verification/contracts/F013.md`.
3. `bootstrap/.env.example` + `.gitignore` for `bootstrap/.env`.
4. `bootstrap/provision.sh` (dry-run default, `--apply`, preflight, idempotent) and
   `bootstrap/teardown.sh` (`--yes` required).
5. `tests/bootstrap.bats` with a fake `az` on PATH.
6. Show the dry-run to the human; run `--apply` only after an explicit OK (cost, DEC-019).
7. Human adds NS records in Namecheap; verify `dig NS preview.nimat.dev`.
Proof: init GREEN; after apply: `az aks show` Succeeded, `kubectl get nodes` Ready, re-run no-op.

## Acceptance (summary)
See `phases/PHASE-01-FOUNDATION.md` → F013.

## Definition of done
Every acceptance item met + evidence in `CHANGELOG.md` + Evaluator PASS + check-architecture
clean + PR reviewed clean (`AGENTS.md` → Definition of done).
