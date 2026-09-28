# DECISIONS — decision log

Indexes the architecture ADRs (`architecture/decisions/`) and records lighter decisions that
don't need a full ADR. Don't relitigate a decision here without a new one that supersedes it.

## Format
```
DEC-00N (<YYYY-MM-DD>): <decision, stated plainly>. — <why> [ADR-XXXX if applicable]
```

<!-- decisions go below -->
DEC-001 (2026-09-28): Scale engine = KEDA HTTP add-on (interceptor holds request, scales 0→1). — request-driven scale-to-zero on plain Deployment + nginx; Knative rejected as heavier and owns routing.
DEC-002 (2026-09-28): One preview per branch; `preview_id` = sanitized branch. — stable shareable URL; per-commit = one-line change in `scripts/lib/preview.sh`.
DEC-003 (2026-09-28): DNS = wildcard A `*.preview.alleghenycounty.us` in Azure DNS sub-zone → nginx LB IP. — zero per-preview DNS calls; sub-zone limits blast radius; external-dns rejected.
DEC-004 (2026-09-28): TLS = one cert-manager DNS-01 wildcard cert, set as nginx `default-ssl-certificate`. — no per-preview TLS config.
DEC-005 (2026-09-28): Auth = GitHub→Azure OIDC federated to `preview` environment; no stored secrets. — no long-lived credentials.
DEC-006 (2026-09-28): Two knobs: idle timeout (KEDA `scaledownPeriod`) vs lifetime (reaper deletes ns via `preview.expires-at`). — separates sleep/wake from teardown.
DEC-007 (2026-09-28): Workflow owns Namespace; Helm owns workloads; KEDA owns replicas. — avoids ownership conflicts; reaper metadata authoritative.
DEC-008 (2026-09-28): Image tag = short Git SHA. — traceable, immutable per commit.
DEC-009 (2026-09-28): Start with Azure RBAC Writer at cluster scope; tighten to k8s ClusterRole in F009. — Azure RBAC can't glob `preview-*` namespaces.
DEC-010 (2026-09-28): Deviation from spec "verbatim": preview-id/duration/expiry logic extracted to `scripts/lib/preview.sh`, sourced by workflows. — deploy & destroy duplicated the sanitizer; drift breaks destroy; makes logic unit-testable.
DEC-011 (2026-09-28): Build order: offline-verifiable (tooling, lib, chart) before cluster bootstrap. — progress without Azure access (BLK-001); spec Part E order otherwise kept.
DEC-012 (2026-09-28): Sample app `todo/` (Vite+React static SPA) is the long-term preview target (confirmed by user); image = nginx-unprivileged on :8080, matching chart defaults. — F012; unblocks F005/F006 image needs.
DEC-013 (2026-09-28): Enforce harness with project hooks in `.claude/settings.json`: SessionStart injects state, UserPromptSubmit reminds, Stop blocks if non-harness files changed without PROJECT_STATE update. — CLAUDE.md is advisory; ad-hoc asks were bypassing the loop.
DEC-014 (2026-09-28): check-architecture is grep/awk-based with `--root`; fixtures generated per bats test in temp dirs. — no import graph in an infra repo; generated fixtures keep deliberate violations out of lint.
DEC-015 (2026-09-28): Dev tools may come from pipx/go/npm when brew is unavailable; init.sh prepends ~/.local/bin and ~/go/bin. — brew blocked on Xcode license.
DEC-016 (2026-09-28): Continue F002+ as stacked branches before F001's PR is reviewed (user approved). — PR creation blocked by BLK-006; review debt tracked in PROJECT_STATE.
DEC-017 (2026-09-28): `scripts/lib/preview.sh` is stricter than the spec's inline code: printf (spec's `echo` swallows `-n`/`-e`), invalid/zero durations rejected (spec passed them through), non-numeric `preview.expires-at` treated as expired, managed-by re-checked in jq. — spec inputs still produce identical preview ids (corpus test).
DEC-018 (2026-09-28): Chart keeps the spec's 9 files byte-identical (enforced by a bats diff) and adds `templates/validate.yaml` with `required` guards for host, image.repository, image.tag. — defaults otherwise render a broken but schema-valid preview; additive file avoids spec drift.
DEC-019 (2026-09-28): Provision our own spec prerequisites (F013): 1-node Standard_B2s AKS (free tier, OIDC + workload identity) + Basic ACR in `nimatresourceg`/eastus, with a teardown script. Dry-run by default; apply only on explicit human OK. — subscription had no AKS/ACR; user chose "I create small ones".
DEC-020 (2026-09-28): Preview domain = `preview.nimat.dev` (supersedes the alleghenycounty.us part of DEC-003). Azure DNS zone `preview.nimat.dev` delegated from Namecheap BasicDNS via NS records on host `preview`; apex (Vercel) untouched. Wildcard A + wildcard cert design unchanged. — user owns nimat.dev; alleghenycounty.us not controllable.
DEC-021 (2026-09-28): Ingress controller = Traefik v3 (chart 41.6.0) instead of ingress-nginx. — community ingress-nginx EOL March 2026 (no security fixes); Traefik handles Ingress→ExternalName (allowExternalNameServices) and forwards Host by default, so spec chart files stay byte-identical. User chose it.
DEC-022 (2026-09-28): Chart's `ingressClassName` default (nginx) stays; deploy passes `--set ingressClassName=traefik` from a repo variable `INGRESS_CLASS` (F006). — keeps spec chart byte-identical.
DEC-023 (2026-09-28): KEDA HTTP add-on sized for one 2-vCPU node (`bootstrap/values/keda-http.yaml`: 1 scaler, interceptor min 1/max 3, 50m requests). — chart defaults (3 scalers + 3 interceptors at 250m) didn't schedule; quota allows no 2nd node.
DEC-024 (2026-09-28): CI identity gets AKS Cluster User Role + a k8s ClusterRole `preview-deployer` (namespaces, services, resourcequotas, secrets, configmaps, deployments, replicasets, ingresses, httpscaledobjects; read pods/events) bound to the SP object id — not the spec's `Azure Kubernetes Service RBAC Writer`, which only reads namespaces/resourcequotas and has no httpscaledobjects (deploy would fail). AKS now has Entra ID + Azure RBAC (needed for kubelogin); operator holds RBAC Cluster Admin; local accounts still enabled as break-glass. — verified by impersonation (`evidence/F004/sp-rbac.txt`).
