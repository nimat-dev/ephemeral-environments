# Phase 01 — Foundation

Tooling, pure core, chart, one-time cluster bootstrap, manual smoke test. Source:
`../preview-environments-implementation.md` Parts A, B, C. Files marked "verbatim" are
copied from the spec; deviations need a DEC.

## F001 — Repo tooling
**Status**: COMPLETE

### Acceptance criteria
- [x] `scripts/init.sh` runs: tool check → yamllint → shellcheck → actionlint (if workflows exist) → helm lint/template + kubeconform (if chart exists) → bats (if tests exist) → check-architecture. Exit non-zero on any failure.
- [x] `scripts/check-architecture.sh` implements all 9 rules in `rules/layer-boundaries.md`; each rule skips cleanly when its target dir doesn't exist yet.
- [x] Deliberately violating each rule (fixture) makes check-architecture exit non-zero naming the rule.
- [x] `.yamllint` config tolerates Helm templates (exclude `deploy/preview/templates`).
- [x] Structured log lines (`[level] component: msg`) at start/end/failure.
- [x] Edge/error cases from `verification/edge-cases.md` (applicable ones) covered by tests.
- [x] Boundary invariants: obeys `rules/layer-boundaries.md` (check-architecture passes).
- [x] Verification: the FULL verify (CLAUDE.md → Commands) passes with zero errors, no regressions.
- [x] E2E: N/A — not user-facing (init run is the integration check).

### Evidence expected
`./scripts/init.sh` output green; per-rule violation fixture output.

## F002 — Pure core `scripts/lib/preview.sh`
**Status**: COMPLETE

### Acceptance criteria
- [x] `preview_id <branch>` matches spec sanitizer exactly (lowercase, `[^a-z0-9]+`→`-`, trim, cut 40, trim trailing `-`); empty → exit 1.
- [x] `to_seconds` handles `Nm`, `Nh`, `Nd`; `never` handled by caller → 31536000.
- [x] `expires_at <lifetime> [now]` = now + seconds; `custom` + empty → exit 1.
- [x] `expired_namespaces <now>` (JSON on stdin; jq) returns names with `expires-at < now`; missing label → expired.
- [x] No adapter calls (rule 1). Bash strict mode.
- [x] bats tests: uppercase, slashes, underscores, leading/trailing symbols, >40 chars ending in `-` after cut, unicode, all-symbol branch (→ fail), each duration unit, invalid unit, boundary `expires-at == now`.
- [x] Edge/error cases from `verification/edge-cases.md` (applicable ones) covered by tests.
- [x] Boundary invariants: obeys `rules/layer-boundaries.md` (check-architecture passes).
- [x] Verification: the FULL verify (CLAUDE.md → Commands) passes with zero errors, no regressions.
- [x] E2E: N/A — library.

### Evidence expected
`bats tests/` output; shellcheck clean.

## F003 — Helm chart `deploy/preview` (verbatim Part B)
**Status**: COMPLETE

### Acceptance criteria
- [x] Chart.yaml, values.yaml, _helpers.tpl, deployment, service, interceptor-externalname, httpscaledobject, ingress, resourcequota exactly per spec.
- [x] `helm lint ./deploy/preview` clean.
- [x] `helm template` with sample values renders; kubeconform strict passes (HTTPScaledObject via CRD schema or `-ignore-missing-schemas` noted).
- [x] Render assertions (bats): no `kind: Namespace`; Deployment has no `replicas`; Ingress backend = `keda-http-interceptor`; `upstream-vhost` = host; HTTPScaledObject `hosts[0]` = host, `scaledownPeriod` = idleTimeoutSeconds; no Ingress `secretName`.
- [x] Long `name` (>50) truncated by `preview.fullname`.
- [x] Edge/error cases from `verification/edge-cases.md` (applicable ones) covered by tests.
- [x] Boundary invariants: obeys `rules/layer-boundaries.md` (check-architecture passes).
- [x] Verification: the FULL verify (CLAUDE.md → Commands) passes with zero errors, no regressions.
- [x] Missing host/image.repository/image.tag fails the render (additive `templates/validate.yaml`, DEC-018).
- [x] E2E: covered by F005.

### Evidence expected
helm lint/template output; bats render tests.

## F013 — Provision Azure prerequisites
**Status**: COMPLETE

### Acceptance criteria
- [x] `bootstrap/provision.sh`: default = dry-run (prints `az` commands, mutates nothing); `--apply` executes.
- [x] Idempotent: each resource is `show`-checked first; re-run with everything present creates nothing.
- [x] Preflight (read-only): subscription reachable, resource providers registered, vCPU quota for the node size.
- [x] Creates in `nimatresourceg`/eastus: Basic ACR; AKS (1 node Standard_B2s, free tier, OIDC issuer + workload identity, ACR attached); Azure DNS zone `preview.nimat.dev`; prints the zone's NS servers for Namecheap.
- [x] `bootstrap/teardown.sh --yes` deletes AKS, ACR, DNS zone (never the resource group); without `--yes` it only prints.
- [x] All values from `bootstrap/.env` (gitignored); `bootstrap/.env.example` committed.
- [x] bats with a fake `az`: dry-run makes no mutating calls; apply skips existing resources; teardown refuses without `--yes`.
- [x] Edge/error cases from `verification/edge-cases.md` (applicable ones) covered by tests.
- [x] Boundary invariants: obeys `rules/layer-boundaries.md` (check-architecture passes).
- [x] Verification: the FULL verify (CLAUDE.md → Commands) passes with zero errors, no regressions.
- [x] E2E (online, human-approved): `--apply` run; `az aks show` Succeeded; `kubectl get nodes` Ready; second run no-op.

## F004 — Cluster bootstrap (Part A, adapted)
**Status**: COMPLETE (A6 apply pending BLK-006 — needed before F006)

### Acceptance criteria (as adapted by DEC-020/021/023/024)
- [x] `bootstrap/` scripts: a1-ingress (Traefik, DEC-021), a2-wildcard-dns, a3-cert-manager (+ ClusterIssuer, wildcard Certificate, Traefik TLSStore), a4-keda (pinned, sized), a5-github-oidc, a6-github-env.
- [x] Idempotent: every script re-run = skip/unchanged.
- [x] All env-specific values from `bootstrap/.env` (gitignored); `.env.example` committed; versions pinned in `bootstrap/versions.env`.
- [x] Interceptor svc `keda-add-ons-http-interceptor-proxy:8080` confirmed (a4) and recorded (DEC-023, a6 vars).
- [x] Wildcard cert `Ready=True`, served by Traefik, trusted by curl.
- [x] Spec chart accepted server-side by the live CRDs.
- [x] SP RBAC verified by impersonation (allowed: what previews create; denied: clusterroles, exec, nodes, kube-system).
- [ ] A6 applied (repo variables set) — blocked on BLK-006 (gh account access).
- [x] Edge/error cases covered by tests (tests/cluster-bootstrap.bats, 28).
- [x] Boundary invariants: check-architecture clean.
- [x] Verification: FULL verify GREEN (107 tests).
- [x] E2E: `curl https://anything.preview.nimat.dev` → trusted TLS, Traefik 404.

## F005 — Smoke test (Part C)
**Status**: IN PROGRESS

### Acceptance criteria
- [ ] `scripts/smoke.sh` creates `preview-smoke`, installs chart with `idleTimeoutSeconds=120`, cleans up on exit (trap).
- [ ] Checkpoint 1: HTTPS resolves with valid cert.
- [ ] Checkpoint 2: first curl returns 200 after cold start (0→1).
- [ ] Checkpoint 3: pod scales back to 0 after 120s idle.
- [ ] Edge/error cases from `verification/edge-cases.md` (applicable ones) covered by tests.
- [ ] Boundary invariants: obeys `rules/layer-boundaries.md` (check-architecture passes).
- [ ] Verification: the FULL verify (CLAUDE.md → Commands) passes with zero errors, no regressions.
- [ ] E2E: this IS the e2e for Phase 01.

### Evidence expected
smoke.sh log with 3 checkpoints PASS; saved to `.harness/evidence/F005/`.

## F012 — Sample app container (`todo/`)
**Status**: COMPLETE (recorded retroactively — built outside the loop, see CHANGELOG)

### Acceptance criteria
- [x] `todo/Dockerfile` multi-stage: node:22-alpine + pnpm `--frozen-lockfile` build → `nginxinc/nginx-unprivileged` runtime.
- [x] Listens on 8080 (= chart `containerPort`); `/` returns 200 (= chart `probePath`).
- [x] SPA fallback: unknown path returns `index.html` (200).
- [x] Runs non-root.
- [x] `.dockerignore` excludes `node_modules`, `dist`, `.git`.
- [ ] Edge/error cases — N/A beyond the above (static site, no inputs).
- [ ] Boundary invariants — N/A (check-architecture not built yet, F001).
- [ ] Full verify — N/A until F001 provides `init.sh`.
- [x] E2E: local `docker run` + curl (real-cluster e2e is F005).

### Evidence expected
`docker build` + `docker run` + curl output (CHANGELOG 2026-09-28 F012).

## Phase completion criteria
F001–F005 `COMPLETE` with evidence; `scripts/smoke.sh` green against the real cluster
before Phase 02 starts.
