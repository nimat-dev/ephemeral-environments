# CURRENT TASK

**Feature**: F009 — Scoped k8s ClusterRole (restrict SP to `preview-*` namespaces)
**Phase**: Phase 03 — Hardening (Phase 02 COMPLETE 2026-09-29)
**Status**: IN PROGRESS (code + bats done on `feat/F009`; live apply BLOCKED on BLK-010)

## Exact next step
1. BLK-010: human runs `./bootstrap/a5-github-oidc.sh --apply` (needs kubelogin on PATH:
   `export PATH=$HOME/go/bin:$PATH`). It applies VAP `preview-deployer-guard` and exits 1 unless the
   SP probes behave (preview-* allowed; kube-system/default/foo/keda denied). Save output to
   `evidence/F009/live-apply.txt`.
2. Dispatch Deploy then Destroy on a throwaway branch (e.g. `e2e/guard-test`) → both green under the
   guard (proves real SP username == oid); record runs in CHANGELOG; delete the branch.
3. Tick remaining F009 boxes, mark COMPLETE, push, PR, review. Then F010.

## Acceptance (summary)
See `phases/PHASE-03-HARDENING.md` → F009.

## Definition of done
Every acceptance item met + evidence in `CHANGELOG.md` + Evaluator PASS + check-architecture
clean + PR reviewed clean (`AGENTS.md` → Definition of done).
