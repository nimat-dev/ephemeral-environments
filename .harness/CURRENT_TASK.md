# CURRENT TASK

**Feature**: F006 — `.github/workflows/preview-deploy.yml`
**Phase**: Phase 02 — Workflows
**Status**: IN PROGRESS (not started; unblocked — A6 applied, Phase 01 PR stack reviewed clean)

## Exact next step
1. (done 2026-09-28) A6 applied; PRs #1–#7 open + reviewed clean.
2. Branch `feat/F006` from `feat/F005`; sprint contract.
3. Workflow per spec Part D, adapted: source `scripts/lib/preview.sh` (DEC-010), build context `todo`
   (BLK-002), buildx linux/amd64 (DEC-025), `--set ingressClassName=${{ vars.INGRESS_CLASS }}` (DEC-022),
   `HELM_DRIVER=configmap` (DEC-026 — SP cannot touch secrets).
4. actionlint + check-architecture (rules 2, 3, 6, 7, 8) clean; dispatch against a test branch.
Proof: Actions run green, job summary URL returns 200 after cold start.

## Acceptance (summary)
See `phases/PHASE-02-WORKFLOWS.md` → F006.

## Definition of done
Every acceptance item met + evidence in `CHANGELOG.md` + Evaluator PASS + check-architecture
clean + PR reviewed clean (`AGENTS.md` → Definition of done).
