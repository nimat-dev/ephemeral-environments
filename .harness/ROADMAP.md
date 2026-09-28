# ROADMAP

All features across all phases, with permanent ids and status. This is the source of truth
for **scope**. Statuses: `NOT STARTED` · `IN PROGRESS` · `BLOCKED` · `IN REVIEW` ·
`COMPLETE` · `DEPRECATED`.

Derived from `preview-environments-implementation.md` Part E (build order).

**Progress**: 7 / 13 COMPLETE (54%) — Phase 01 COMPLETE

## Phase 01 — Foundation — COMPLETE (2026-09-28)
- [x] **F001** — Repo tooling: `scripts/init.sh`, `scripts/check-architecture.sh`, lint configs (actionlint, shellcheck, yamllint, kubeconform) — `COMPLETE`
- [x] **F002** — Pure core `scripts/lib/preview.sh` (preview-id, to_seconds, expires_at, expired filter) + bats tests — `COMPLETE`
- [x] **F003** — Helm chart `deploy/preview` (Part B), `helm lint` + `helm template` clean — `COMPLETE`
- [x] **F013** — Provision AKS (1× Standard_B2s, OIDC issuer + workload identity) + Basic ACR + Azure DNS zone `preview.nimat.dev` in `nimatresourceg` (spec prerequisites; DEC-019/020) — `COMPLETE`
- [x] **F004** — Cluster bootstrap (Part A1–A6): `bootstrap/` scripts + `clusterissuer.yaml` + `wildcard-cert.yaml`, applied once — `COMPLETE` (Traefik instead of ingress-nginx; A6 apply pending BLK-006)
- [x] **F005** — Smoke test `scripts/smoke.sh` (Part C): HTTPS valid, cold-start 200, scales back to 0 — `COMPLETE`
- [x] **F012** — Sample app container: `todo/Dockerfile` (Vite build → nginx-unprivileged :8080, SPA fallback) — the image F005/F006 deploy — `COMPLETE`

## Phase 02 — Workflows (Part D)
- [ ] **F006** — `preview-deploy.yml`: dispatch → build/push → ns+labels → helm → verify → summary — `IN PROGRESS` (real e2e needs A6 vars, BLK-006)
- [ ] **F007** — `preview-destroy.yml`: dispatch → delete ns — `NOT STARTED`
- [ ] **F008** — `preview-reap.yml`: cron */30 → delete expired ns — `NOT STARTED`

## Phase 03 — Hardening (Part E step 6)
- [ ] **F009** — Scoped ClusterRole already in F004 (DEC-024); remaining: restrict SP namespace create/delete to `preview-*` (ValidatingAdmissionPolicy) + negative tests — `NOT STARTED`
- [ ] **F010** — Prove per-namespace `ResourceQuota` enforced — `NOT STARTED`
- [ ] **F011** — `preview` env required reviewers (optional gate) + ACR retention policy for SHA tags — `NOT STARTED`
