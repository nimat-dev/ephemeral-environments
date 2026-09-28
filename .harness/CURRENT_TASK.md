# CURRENT TASK

**Feature**: F006 — `.github/workflows/preview-deploy.yml`
**Phase**: Phase 02 — Workflows
**Status**: IN PROGRESS (not started; real e2e BLOCKED on BLK-006: gh access → A6 repo variables)

## Exact next step
1. Human: `gh auth login` (or switch) to the GitHub account with admin on nimat-dev/ephemeral-environments,
   then run `bootstrap/a6-github-env.sh --apply` (sets `preview` environment + 12 variables).
2. Branch `feat/F006` from `feat/F005`; sprint contract.
3. Workflow per spec Part D, adapted: source `scripts/lib/preview.sh` (DEC-010), build context `todo`
   (BLK-002), buildx linux/amd64 (DEC-025), `--set ingressClassName=${{ vars.INGRESS_CLASS }}` (DEC-022).
4. actionlint + check-architecture (rules 2, 3, 6, 7, 8) clean; dispatch against a test branch.
Proof: Actions run green, job summary URL returns 200 after cold start.

## Acceptance (summary)
See `phases/PHASE-02-WORKFLOWS.md` → F006.

## Definition of done
Every acceptance item met + evidence in `CHANGELOG.md` + Evaluator PASS + check-architecture
clean + PR reviewed clean (`AGENTS.md` → Definition of done).
