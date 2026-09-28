# Layer Boundaries

The enforceable rules behind `architecture/ARCHITECTURE.md`. `scripts/SCRIPTS.md` →
check-architecture validates these; a violation fails the build and blocks "done." These are
import-direction rules — dependencies point one way only.

> Archetype B (DevOps/IaC). These rules are **active**: once `scripts/check-architecture.sh`
> exists (F001) it enforces each one by grep/parse and exits non-zero on violation.

## Allowed dependency direction

    .github/workflows/*.yml, scripts/smoke.sh   (entrypoints)
        ├──► scripts/lib/preview.sh              (pure core — depends on nothing)
        ├──► deploy/preview (Helm chart)         (declarative; values injected)
        └──► adapters: az / kubectl / helm / docker actions / curl
    bootstrap/  (one-time, human-run) — nothing depends on it

## The rules (each must be checkable)

1. **Pure core.** `scripts/lib/*.sh` invokes no `az`, `kubectl`, `helm`, `docker`, `curl`,
   `gh`. (grep)
2. **Single identity implementation.** No workflow contains the preview-id `sed`/`tr`
   sanitizer inline; all source `scripts/lib/preview.sh`. (grep `s#\[^a-z0-9\]` in
   `.github/workflows/`)
3. **No secrets.** Workflows use `azure/login` with `client-id`/`tenant-id`/`subscription-id`
   from `vars.*` only; no `client-secret`, no `secrets.*` except `GITHUB_TOKEN`. (grep)
4. **Namespace owned by workflow.** No chart template renders `kind: Namespace`. (grep
   `deploy/preview/templates`)
5. **KEDA owns replicas.** `deploy/preview/templates/deployment.yaml` has no `replicas:`
   field. (grep)
6. **No hard-coded env.** Workflows reference no literal domain, ACR, cluster, RG, or
   interceptor FQDN — only `vars.*`. (grep `alleghenycounty.us`, `azurecr.io`,
   `svc.cluster.local` in `.github/workflows/`)
7. **Least-privilege tokens.** Every workflow declares `permissions:` with exactly
   `id-token: write` and `contents: read`. (yaml parse)
8. **Bootstrap isolated.** No workflow references `bootstrap/`. (grep)
9. **TLS via default cert.** Chart Ingress has no `secretName`. (grep)

## Rationale
The one boundary that matters most: **preview identity is pure and shared.** Deploy,
destroy, and reap must agree on the namespace name and label contract; a second
implementation means destroy silently misses what deploy created.

## How to check
Until the app exists, this file is the spec. Once the code exists, implement
check-architecture (contract in `scripts/SCRIPTS.md`) to inspect the import graph and exit
non-zero on any violation. The check runs in `init` and before any feature is marked passed.
