# BLOCKERS — what's stuck

Open blockers first. Close a blocker by moving it to Resolved with the fix + date. A parked
out-of-scope temptation (scope-guard) also lands here until it becomes a real ROADMAP feature.

## Open
```
(id | opened | feature | description | what would unblock it)
BLK-009 | 2026-09-28 | F006–F008 e2e | `workflow_dispatch` only runs workflows on the default branch; `main` lacks Phase 01 (stacked merges, DEC-028). Auto-mode denied the agent merging PRs (needs a human review/merge) | human merges PR #8, then the F006 (then F007, F008) PRs into `main`; agent then dispatches the e2e runs
BLK-008 | 2026-09-28 | F013 follow-up | `bootstrap/teardown.sh` leaves Entra app `gh-preview-deployer` (+SP, federated cred) and UAMI `cert-manager-dns` (PR #5 review) | teardown removes them (next bootstrap touch; not Phase 02 critical path)
```

## Resolved
```
(id | resolved | how)
BLK-002 | 2026-09-28 | F006 builds `context: src/todo` (app branch checked out into `src/`); bats `workflow: … todo context`
BLK-006 | 2026-09-28 | user switched gh to `nimat-dev` (admin); A6 applied (`preview` env + 12 vars); PRs #1–#7 opened
BLK-003 | 2026-09-28 | domain is now public `preview.nimat.dev` (DEC-020); F005 curled it from the public internet with trusted TLS
BLK-001 | 2026-09-28 | F013 provisioned AKS `aks-preview`, ACR `nimatpreviewacr`, zone `preview.nimat.dev` in `nimatresourceg` (sub 1325f79b-…); values in bootstrap/.env
BLK-005 | 2026-09-28 | Namecheap NS records for `preview` added by user; dns1.registrar-servers.com returns the 4 Azure NS
BLK-004 | 2026-09-28 | pinned in bootstrap/versions.env: traefik 41.6.0, keda 2.21.0, keda-add-ons-http 0.16.0, cert-manager v1.21.2; spec chart passes server-side dry-run against installed CRDs
BLK-007 | 2026-09-28 | brew install failed (Xcode license, needs sudo) -> installed yamllint (pipx), kubeconform (go install), bats (npm); DEC-015
```
