# F006 review — PR #9

## Round 1 (2026-09-28) — CLEAN
Checker pass over `git diff origin/feat/F005..feat/F006`, re-running rather than trusting:
- Injection: no `${{ }}` in any `run:` (bats guard); raw branch only in a jq-escaped annotation. OK
- RBAC: `kubectl auth can-i --as=<SP>` get/create/patch/delete/list namespaces = yes; configmaps in ns = yes
  (apply on redeploy needs patch). OK
- Secrets: deploy forces `HELM_DRIVER=configmap`; local e2e ns has 0 secrets. OK
- Type coercion: `--set-string` for strings; `replicas.max`/`idleTimeoutSeconds`/`interceptor.port` stay ints
  (validated numeric in plan / var). OK
- Failure paths: bad input → plan exit 1 before any Azure call; summary runs `if: always()` with blanks. OK

Accepted notes (not defects):
1. Concurrency group uses the raw branch: `Feat/X` and `feat/x` → same preview, different lock. Expressions
   have no lowercase; collision needs two humans dispatching case-variants at once.
2. Deploy re-arms `expires-at` on every redeploy (lifetime counts from the last deploy) — matches spec.
