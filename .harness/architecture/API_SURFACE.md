# API SURFACE

No served API. The contracts are **workflow inputs**, **chart values**, and **repo variables**.
Change them in the same commit as the code that consumes them.

## `Deploy Preview` (`preview-deploy.yml`, workflow_dispatch)
| Input | Type | Default | Values |
|---|---|---|---|
| `branch` | string, required | — | any branch |
| `lifetime` | choice, required | `48h` | `24h` `48h` `7d` `custom` |
| `lifetime_custom` | string | — | `12h`, `3d`… (only when `custom`) |
| `idle_timeout` | choice, required | `30m` | `15m` `30m` `1h` `6h` `never` |
| `max_replicas` | string | `3` | int 1..6 (≤ quota.pods) |
Output: job summary (branch, commit, image, namespace, idle, lifetime, **URL**).
Concurrency: `preview-<branch>`, no cancel-in-progress.
Failure: non-200 from URL after 30×5s → job fails.

## `Destroy Preview` (`preview-destroy.yml`, workflow_dispatch)
| Input | Type |
|---|---|
| `branch` | string, required |
Effect: `kubectl delete ns preview-<id> --ignore-not-found --wait=false`. Absent → success (no-op).
A `preview-<id>` namespace not labeled `managed-by=preview-bot` is refused (exit 1, DEC-029).
Concurrency: `preview-<branch>` (shared with deploy), no cancel-in-progress.

## `Reap Expired Previews` (`preview-reap.yml`)
Cron `*/30 * * * *` + manual dispatch. Deletes `managed-by=preview-bot` namespaces with
`preview.expires-at < now` and a `preview-` name. No expired → "nothing to reap", exit 0.
One failed delete → others still deleted, run fails. Concurrency: `preview-reap`.

## Helm chart `deploy/preview` values (set via `--set`)
`name`, `host`, `image.repository`, `image.tag`, `image.pullPolicy`, `containerPort` (8080),
`probePath` (`/`), `replicas.min` (0), `replicas.max` (3), `idleTimeoutSeconds` (1800),
`resources.*`, `quota.{cpu,memory,pods}` (2 / 4Gi / 6), `interceptor.{fqdn,port}`,
`ingressClassName` (nginx), `commit`, `branch`.

## Repo / `preview` environment variables (no secrets — OIDC only)
`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `ACR_NAME`, `ACR_LOGIN_SERVER`,
`APP_IMAGE_NAME`, `AKS_CLUSTER`, `AKS_RESOURCE_GROUP`, `PREVIEW_DOMAIN`, `INTERCEPTOR_FQDN`,
`INTERCEPTOR_PORT`, `INGRESS_CLASS` (traefik, DEC-022). Set by `bootstrap/a6-github-env.sh`.
