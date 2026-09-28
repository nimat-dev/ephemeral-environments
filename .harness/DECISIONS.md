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
