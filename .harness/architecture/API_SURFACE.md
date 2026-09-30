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
Effect: `kubectl delete ns preview-<app>-<id> --ignore-not-found --wait=false`; absent → legacy `preview-<id>`
(only if preview-bot-made with no `preview.repo`); neither → success (no-op).
A namespace this repo doesn't own (not `managed-by=preview-bot`, DEC-029, or another repo's `preview.repo`, F015) is refused (exit 1).
Concurrency: `preview-<branch>` (shared with deploy), no cancel-in-progress.

## `Reap Expired Previews` (`preview-reap.yml`)
Cron `*/30 * * * *` + manual dispatch. Deletes `managed-by=preview-bot` namespaces with
`preview.expires-at < now`, a `preview-` name, owned by this repo (`preview.repo`, or none = legacy; F015). No expired → "nothing to reap", exit 0.
One failed delete → others still deleted, run fails. Concurrency: `preview-reap`.

## Repo variables read by the workflows (env `preview`, set by a6)
`AZURE_CLIENT_ID` `AZURE_TENANT_ID` `AZURE_SUBSCRIPTION_ID` `ACR_NAME` `ACR_LOGIN_SERVER` `APP_IMAGE_NAME`
`AKS_CLUSTER` `AKS_RESOURCE_GROUP` `PREVIEW_DOMAIN` `INTERCEPTOR_FQDN` `INTERCEPTOR_PORT` `INGRESS_CLASS`
`PREVIEW_APP` (F015; empty → repo name). Built-in `GITHUB_REPOSITORY` sets `preview.repo`.

## Helm chart `deploy/preview` values (set via `--set`)
`name`, `host`, `image.repository`, `image.tag`, `image.pullPolicy`, `containerPort` (8080),
`probePath` (`/`), `replicas.min` (0), `replicas.max` (3), `idleTimeoutSeconds` (1800),
`resources.*`, `quota.{cpu,memory,pods}` (2 / 4Gi / 6), `interceptor.{fqdn,port}`,
`ingressClassName` (nginx), `commit`, `branch`.

## Repo / `preview` environment variables (no secrets — OIDC only)
`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `ACR_NAME`, `ACR_LOGIN_SERVER`,
`APP_IMAGE_NAME`, `AKS_CLUSTER`, `AKS_RESOURCE_GROUP`, `PREVIEW_DOMAIN`, `INTERCEPTOR_FQDN`,
`INTERCEPTOR_PORT`, `INGRESS_CLASS` (traefik, DEC-022). Set by `bootstrap/a6-github-env.sh`.
