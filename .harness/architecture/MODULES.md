# MODULES — the extension points

Variants plug in here without editing the core flow.

| Extension point | Where | Swap without touching core |
|---|---|---|
| **Scale engine** | `deploy/preview/templates/httpscaledobject.yaml` + `interceptor-externalname.yaml` | KEDA HTTP add-on → Knative `Service` (workflows, DNS, TLS unchanged) |
| **Preview identity strategy** | `scripts/lib/preview.sh` | per-branch → per-run (`<id>-<short_sha>`), one function |
| **Duration units** | `scripts/lib/preview.sh` `to_seconds` | add unit suffix in one place |
| **DNS / cert solver** | `bootstrap/clusterissuer.yaml` | Azure DNS → Cloudflare/Route53 solver |
| **Verify strategy** | deploy workflow verify step | public curl → in-cluster curl via interceptor (internal-only DNS) |
| **Per-preview sizing** | chart `values.yaml` (`resources`, `quota`, `replicas`) | override via `--set` / dispatch input |
| **Workload shape** | chart templates | add templates (e.g. ConfigMap) — no workflow change |

Rule: if a new variant needs edits in more than one workflow, the logic belongs in
`scripts/lib/preview.sh` or chart values instead.
