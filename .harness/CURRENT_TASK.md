# CURRENT TASK

**Feature**: F003 — Helm chart `deploy/preview` (spec Part B)
**Phase**: Phase 01 — Foundation
**Status**: IN PROGRESS

## Exact next step
1. Branch `feat/F003` (from `feat/F002`).
2. Sprint contract `verification/contracts/F003.md`.
3. Write the chart verbatim from `preview-environments-implementation.md` Part B:
   Chart.yaml, values.yaml, templates/{_helpers.tpl, deployment, service,
   interceptor-externalname, httpscaledobject, ingress, resourcequota}.yaml.
4. `tests/fixtures/values.yaml` (sample host/image/tag) — used by init's helm step.
5. `tests/chart.bats`: render assertions (no Namespace, no Deployment replicas, Ingress →
   keda-http-interceptor, upstream-vhost = host, HTTPScaledObject hosts/scaledownPeriod,
   no Ingress secretName, name >50 truncated).
Proof: `./scripts/init.sh` runs helm lint + kubeconform (no longer skipped) and is GREEN.

## Acceptance (summary)
See `phases/PHASE-01-FOUNDATION.md` → F003.

## Definition of done
Every acceptance item met + evidence in `CHANGELOG.md` + Evaluator PASS + check-architecture
clean + PR reviewed clean (`AGENTS.md` → Definition of done).
