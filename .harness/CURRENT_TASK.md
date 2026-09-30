# CURRENT TASK

**Feature**: F021 — Kit extraction + releases (Phase 05, `phases/PHASE-05-MULTI-REPO.md`)
**Status**: IN PROGRESS (2026-09-30). Last: F020 COMPLETE.

## Exact next step
0. After the F020 PR merges: Flux prunes `preview-deployer` / `preview-deployer-guard`, keeps `*-todo` (check `kubectl get vap`).
1. Branch `feat/F021`; contract `verification/contracts/F021.md`.
2. `kit/`: composite action (`kit/action.yml`, runs `preview-ci.sh` via `github.action_path`) + reusable workflows
   (`workflow_call`: deploy, destroy, reap, purge); chart published to ACR OCI; `.preview.yaml` `defaults`.
3. Semver release workflow (full tags only, DEC-035); this repo's workflows consume the kit (dogfood); consumer example ≤ 25 lines.

Follow-ups (not on the roadmap; each needs a new FID first; several fold into Phase 05):
1. BLK-008 (→ F020): `bootstrap/teardown.sh` leaves Entra app `gh-preview-deployer` (+SP, federated creds) and UAMI
   `cert-manager-dns`.
2. Untagged ACR manifests (buildx platform/attestation children) are never purged (F011 contract §5).
3. `ubuntu-latest` migrates to Ubuntu 26 from 2026-10-19 (runner notice on every run) — re-run workflows after; pin `ubuntu-24.04` if anything breaks.
4. Cluster RUNNING since 2026-09-30 (F015 e2e) — stop with `az aks stop -g nimatresourceg -n aks-preview` when idle.

## Definition of done (for any new feature)
`AGENTS.md` → Definition of done.
