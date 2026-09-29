# ARCHITECTURE

> Archetype: **B. DevOps / IaC / platform tooling** (`ARCHETYPES.md`). Full detail + verbatim
> file contents: `../preview-environments-implementation.md`.

## Runtime topology
```
Developer
  │  workflow_dispatch (branch, lifetime, idle_timeout, max_replicas)
  ▼
GitHub Actions ──OIDC──► Azure (no stored secrets)
  ├─ checkout <branch>
  ├─ docker build → push  ACR/<app>:<short-sha>
  ├─ kubectl apply namespace  (labels: expires-at, branch, commit)
  ├─ helm upgrade --install  → Deployment, Service, HTTPScaledObject, ExternalName, Ingress, ResourceQuota
  └─ verify: curl the URL (cold-start proof) → write URL to job summary

Request path when live:
  Browser → nginx Ingress → ExternalName(svc) → KEDA HTTP interceptor (keda ns)
          → app Service → pod   (interceptor scales 0→1 and holds the request if asleep)

Wildcard, created once:
  *.preview.nimat.dev  A   → nginx LoadBalancer IP
  *.preview.nimat.dev  TLS → cert-manager (DNS-01), set as nginx default cert

Teardown:
  preview-destroy.yml (manual)  ─┐
  preview-reap.yml (cron */30)  ─┴─► kubectl delete ns preview-<id>   (expires-at < now)
```

## Repository shape (target)
```
.github/workflows/
  preview-deploy.yml     # entrypoint: dispatch → build/push → ns → helm → verify → summary
  preview-destroy.yml    # entrypoint: dispatch → delete ns
  preview-reap.yml       # entrypoint: cron → delete expired ns
scripts/
  lib/preview.sh         # PURE core: preview-id sanitize, duration→seconds, expiry select
  init.sh                # verify baseline (lint + template + tests + check-architecture)
  check-architecture.sh  # enforces rules/layer-boundaries.md
  smoke.sh               # Part C manual smoke test (real cluster)
deploy/preview/          # Helm chart (declarative; no cluster lookups)
  Chart.yaml  values.yaml  templates/{_helpers.tpl,deployment,service,
  interceptor-externalname,httpscaledobject,ingress,resourcequota}.yaml
bootstrap/               # Part A one-time: scripts + clusterissuer.yaml + wildcard-cert.yaml
tests/                   # bats tests for scripts/lib + chart render assertions
```

## Layers (dependency points down only)
```
entrypoints   .github/workflows/*.yml, scripts/smoke.sh
     │
     ├──► pure core     scripts/lib/preview.sh   (no az/kubectl/helm/docker/curl)
     ├──► chart         deploy/preview           (rendered by helm; values injected via --set)
     └──► adapters      azure/login, aks-set-context, docker/build-push, kubectl, helm, curl
bootstrap/     one-time, human-run; never referenced by workflows
```
**Pure core**: preview identity + duration + expiry logic. Depends on nothing; unit-tested
with no cloud calls. Both deploy and destroy source it so the namespace name can never
drift between them.

## Ownership split (don't blur)
- **Workflow** owns the Namespace (+ `preview.expires-at` label the reaper reads).
- **Helm** owns workloads inside the namespace. Chart never templates `Namespace`.
- **KEDA** owns replica count. Deployment has no `replicas:` field.
- **nginx** serves TLS via default wildcard cert; Ingress has no `secretName`.

## Version-sensitive points
- `HTTPScaledObject` schema (add-on pre-1.0) — most likely to drift.
- Interceptor service name/port → `INTERCEPTOR_FQDN` / `INTERCEPTOR_PORT`.
- nginx `upstream-vhost` annotation for ExternalName Host routing. Fallback: one central
  Ingress in `keda` ns routing all preview hosts to the interceptor.
