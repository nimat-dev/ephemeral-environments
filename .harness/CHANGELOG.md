# CHANGELOG — completed implementation, with evidence

Newest first. One entry per feature that reached `COMPLETE`. An entry is not valid without
reproducible evidence (see `verification/acceptance-evidence.md`).

## Template
```
## <YYYY-MM-DD> — <FID> <feature name> — COMPLETE
Branch/commit: <branch> @ <sha>   PR: <url>   CI: <green + link>
Evidence:
  - <exact command> -> <result / test id / artifact path>
  - full suite: <command> -> <N passed, 0 failed> (no regressions)
  - e2e: <command> -> <scenarios passed / N-A not user-facing> (trace: .harness/evidence/<FID>/)
  - edge cases: <the applicable edge-cases.md categories covered, by test>
Evaluator: acceptance=_ correctness=_ boundaries=_ modularity=_ evidence=_ => avg _._  (PASS)
Notes: <anything the next agent should know>
```

<!-- entries go below, newest first -->

## 2026-09-29 — F009 scoped ClusterRole / preview-* guard — IN PROGRESS (live apply pending BLK-010)
Branch: feat/F009   Contract: `verification/contracts/F009.md`
Evidence (`evidence/F009/offline-verify.txt`):
  - baseline gap (live can-i as SP): configmaps kube-system yes, delete ns keda yes, create ns yes, deployments default yes; secrets no; Azure roles AcrPush + AKS Cluster User only
  - a5 renders VAP `preview-deployer-guard` + binding keyed on SP oid; `kubectl apply --dry-run=server` of the rendered manifest -> accepted by the live API server
  - bats: `A5: renders preview-deployer-guard…`, `A5 apply: guard effective -> probes…`, `A5 apply: guard not effective -> exit 1`
  - full suite: `./scripts/init.sh` -> BASELINE GREEN, bats 157/157
Open: live `a5 --apply` + probes, Deploy/Destroy dispatch under the guard.

## 2026-09-29 — F007 preview-destroy.yml — COMPLETE (Phase 02 COMPLETE)
Branch/commit: feat/F007 merged to main @ 1bde2f9; tracking on feat/F006-oidc   PR: https://github.com/nimat-dev/ephemeral-environments/pull/10
Evidence (`evidence/F007/dispatch-destroy-e2e.txt`, `evidence/F007/scheduled-reap.txt`):
  - Deploy `e2e/preview-test` lifetime 24h: https://github.com/nimat-dev/ephemeral-environments/actions/runs/36568611973 (success, verify ok) -> GET 200
  - Destroy dispatch: https://github.com/nimat-dev/ephemeral-environments/actions/runs/36568750009 (success) -> `namespace "preview-e2e-preview-test" deleted`; GET -> 404
  - first scheduled reap (cron) run 36558226159 10:52Z: deleted expired `preview-e2e-preview-test` (1h lifetime) -> F008 cron path proven too
  - full suite: `./scripts/init.sh` -> BASELINE GREEN (2026-09-29)
Evaluator: acceptance=5 correctness=5 boundaries=5 modularity=5 evidence=5 => avg 5.0 (PASS)

## 2026-09-29 — F008 preview-reap.yml — COMPLETE
Branch/commit: feat/F008 merged to main @ 425ccb8   PR: https://github.com/nimat-dev/ephemeral-environments/pull/11
Evidence (`evidence/F008/dispatch-reap-e2e.txt`):
  - Deploy `e2e/reap-test` lifetime 1m: https://github.com/nimat-dev/ephemeral-environments/actions/runs/36522237996 (success)
  - Reap dispatch: https://github.com/nimat-dev/ephemeral-environments/actions/runs/36522361188 (success) -> deleted only `preview-e2e-reap-test`; live `preview-e2e-preview-test` (1h) kept; reaped URL 404
  - earlier local e2e + bats 26/26 (entry 2026-09-28)
Evaluator: acceptance=5 correctness=5 boundaries=5 modularity=5 evidence=5 => avg 5.0 (PASS)

## 2026-09-29 — F006 preview-deploy.yml — COMPLETE
Branch/commit: feat/F006 merged to main @ b8ac00d; OIDC fix on feat/F006-oidc   PR: https://github.com/nimat-dev/ephemeral-environments/pull/9
Evidence (`evidence/F006/dispatch-e2e.txt`, `evidence/F006/a5-immutable-subject.txt`):
  - run 36521876981 FAILED at azure/login: AADSTS700213, repo issues immutable OIDC subject `repo:nimat-dev@183449925/ephemeral-environments@1392951147:environment:preview` -> a5 now federates it (DEC-030; bats `A5: immutable OIDC subject prefix`), applied
  - https://github.com/nimat-dev/ephemeral-environments/actions/runs/36522067800 (success): plan -> build/push `todo:425ccb8` -> ns with label contract -> helm rev 1 (configmap) -> verify 200 attempt 1 -> summary
  - idle 15m: scaled to 0 at 04:49:05Z; wake request HTTP 200 in 9.0s, 0/0 -> 1/1
  - full suite: `./scripts/init.sh` -> BASELINE GREEN, bats 152/152
  - PR #12 review fixes (`reviews/F006-oidc-review.md`): gh lookup failure fails --apply; FIC subject drift -> update; bats 154/154 GREEN
Evaluator: acceptance=5 correctness=5 boundaries=5 modularity=5 evidence=5 => avg 5.0 (PASS)

## 2026-09-28 — F008 preview-reap.yml — IN PROGRESS (e2e on main pending BLK-009)
Branch/commit: feat/F008   PR: see PROJECT_STATE   CI: N/A until on main
Contract: `verification/contracts/F008.md`
Evidence:
  - `bats tests/preview-ci.bats` -> 26/26 (5 new reap tests); `tests/preview.bats` `default` ns with preview-bot label ignored
  - local reap e2e vs aks-preview (`evidence/F008/local-reap-e2e.txt`): reap-short (+60s, HTTP 200) and reap-live (+24h); reap before expiry -> nothing; after -> only reap-short deleted, URL 404; again -> nothing; live cleaned by destroy
  - actionlint/shellcheck/yamllint/check-architecture clean; `./scripts/init.sh` -> BASELINE GREEN, bats 151/151
Evaluator: acceptance=4 correctness=5 boundaries=5 modularity=5 evidence=4 => avg 4.6 (PASS pending scheduled e2e)
Notes: lib `expired_namespaces` now also requires a `preview-` name (stricter than spec, extends DEC-017).

## 2026-09-28 — F007 preview-destroy.yml — IN REVIEW (dispatch e2e pending BLK-009)
Branch/commit: feat/F007   PR: see PROJECT_STATE   CI: N/A until on main
Contract: `verification/contracts/F007.md`
Evidence:
  - `bats tests/preview-ci.bats` -> 21/21 (5 new destroy tests: delete, not-found no-op, foreign refused, bad input/get failure, workflow shape)
  - local destroy e2e vs aks-preview (`evidence/F007/local-destroy-e2e.txt`): destroy `feat/F006` -> ns NotFound, URL 404; again -> "nothing to destroy" exit 0; unlabeled `preview-e2e-foreign` -> refused exit 1, ns kept
  - actionlint/shellcheck/yamllint/check-architecture clean; `./scripts/init.sh` -> BASELINE GREEN, bats 146/146
Evaluator: acceptance=4 correctness=5 boundaries=5 modularity=5 evidence=4 => avg 4.6 (PASS pending dispatch e2e)

## 2026-09-28 — F006 preview-deploy.yml — IN REVIEW (dispatch e2e pending BLK-009)
Branch/commit: feat/F006   PR: see PROJECT_STATE   CI: N/A until on main
Contract: `verification/contracts/F006.md`
Evidence:
  - `bats tests/preview-ci.bats` -> 16/16 (plan/namespace/deploy/verify/summary + workflow shape + injection guard)
  - `bats tests/preview.bats` -> 27/27 (new: max_replicas, preview_plan, namespace_manifest)
  - `--set name=null` -> helm "invalid value; expected string"; `--set-string` renders (bats `deploy passes strings via --set-string`)
  - local entrypoint e2e vs aks-preview (`evidence/F006/local-entrypoint-e2e.txt`): plan -> buildx amd64 push `todo:85b116b` -> ns `preview-feat-f006` with label contract -> helm rev 1 (configmap storage, 0 secrets) -> verify 200 attempt 1 -> summary; redeploy -> same release rev 2
  - `actionlint`, `shellcheck`, `yamllint`, check-architecture -> clean
  - full suite: `./scripts/init.sh` -> BASELINE GREEN, bats 141/141
  - edge cases: empty/all-symbol branch, custom lifetime empty/bad/zero, max_replicas bounds, injection (quotes/$()/backticks), type coercion, missing vars, helm fail, never-200, summary after early failure
Evaluator: acceptance=4 correctness=4 boundaries=5 modularity=5 evidence=4 => avg 4.4 (PASS pending dispatch e2e)
Notes: concurrency group keys on the raw branch (`Feat/X` and `feat/x` share a preview but not a lock) — accepted, expressions have no lowercase. Phase 01 landed on main via PR #8 (DEC-028); merge blocked for the agent.

## 2026-09-28 — PR loop for Phase 01 stack (#1–#7) + A6 apply
Branch/commit: fixes on feat/F001 @ 73a98ac, feat/F004 (DEC-026); merged up to feat/F005   PRs: https://github.com/nimat-dev/ephemeral-environments/pull/1 … /7 (stacked)   CI: N/A (no workflows yet)
Evidence:
  - `gh api repos/nimat-dev/ephemeral-environments` -> permissions.admin true (account nimat-dev); BLK-006 resolved
  - `bootstrap/a6-github-env.sh --apply` -> env `preview` + 12 vars; `gh variable list --env preview` lists all 12 (INGRESS_CLASS=traefik)
  - review record: `.harness/reviews/stack-review.md` (2 fixes, 5 accepted notes)
  - F001 fix: probe workflow with `secrets.GITHUB_TOKEN_ADMIN` + `secrets['AZ_PW']` -> was "clean", now rule 3 exit 1; 3 new bats tests
  - F004 fix: ClusterRole without secrets; a5 `--apply` -> clusterrole configured; `kubectl auth can-i … --as=<SP>`: secrets get/list/create = no, configmaps/namespaces/httpscaledobjects = yes (`evidence/F004/sp-rbac-no-secrets.txt`); `HELM_DRIVER=configmap helm upgrade --install --kube-as-user <SP>` -> deployed, release in configmap (`evidence/F004/sp-helm-configmap.txt`); new test killed by re-adding secrets
  - full suite: `./scripts/init.sh` -> BASELINE GREEN on feat/F005 tip
Notes: F006 workflow MUST export `HELM_DRIVER=configmap` or helm fails with secrets forbidden.

## 2026-09-28 — PHASE 01 FOUNDATION — COMPLETE
F001, F002, F003, F004, F005, F012, F013 COMPLETE; phase smoke test green twice against aks-preview.

## 2026-09-28 — F005 Smoke test — COMPLETE
Branch/commit: feat/F005 @ (this commit)   PR: not opened (BLK-006)
Contract: `verification/contracts/F005.md`
Evidence:
  - image: ACR Tasks blocked on this subscription (TasksOperationsNotAllowed) -> `docker buildx --platform linux/amd64 --push` -> `nimatpreviewacr.azurecr.io/todo:ca47e1d`
  - run 1 (`evidence/F005/smoke-run1.log`): CP1 PASS valid TLS; CP2 PASS cold start 0→1 in 9.5s HTTP 200; CP3 PASS back to 0 after 127s
  - Checker probe: asleep was read from `.status.replicas` (absent status = 0). Hardened: asleep = `spec.replicas` 0 (absent ≠ 0), CP2 requires `readyReplicas` ≥ 1
  - run 2 with hardened script (`evidence/F005/smoke-run2.log`): CP1 PASS; CP2 PASS 0→1 ready in 8.3s HTTP 200; CP3 PASS back to 0 after 127s
  - tests: `bats tests/smoke.bats` 8/8 (happy, never-zero, absent spec, 200-but-not-ready, 502, bad TLS, --keep, usage); mutations killed: absent spec reads 0 (original bug); skip ready check
  - full suite: `./scripts/init.sh` GREEN, 115 tests
Evaluator: acceptance=5 correctness=5 boundaries=5 modularity=5 evidence=5 => avg 5.0 (PASS)
Notes:
  - Finding: KEDA sets spec.replicas=0 on a never-requested workload immediately ("scaled to 0 after 0s"), so a fresh preview is asleep until its first hit — the deploy workflow's verify step will always exercise a cold start.
  - bash 3.2: no `;&` case fall-through (fake rewritten).

## 2026-09-28 — F004 Cluster bootstrap — COMPLETE (A6 apply pending BLK-006)
Branch/commit: feat/F004 @ (this commit)   PR: not opened (BLK-006)
Contract: `verification/contracts/F004.md` (adapted: Traefik DEC-021, nimat.dev DEC-020)
Evidence (stages 1 and 3 in the entries below), plus stage 2:
  - `bootstrap/a5-github-oidc.sh --apply` -> AKS Entra ID + Azure RBAC enabled; operator RBAC Cluster Admin; app `gh-preview-deployer` (client ecf81f55-…), SP b34bba52-…, federated credential `repo:nimat-dev/ephemeral-environments:environment:preview`; AcrPush + Cluster User Role; ClusterRole/Binding `preview-deployer`
  - re-run -> every step "skip"/"unchanged" (`evidence/F004/a5-rerun.txt`)
  - SP impersonation (`evidence/F004/sp-rbac.txt`): yes = create/delete namespaces, create resourcequotas/httpscaledobjects/deployments/ingresses/secrets; no = clusterroles, pods/exec, delete nodes, daemonsets in kube-system
  - `bootstrap/a6-github-env.sh` dry-run -> environment `preview` + 12 variables (incl. INGRESS_CLASS=traefik); apply refused: gh account `nimatrazmjo` lacks admin (BLK-006)
  - cluster: all pods Running; node CPU 4% / mem 35%
  - full suite: `./scripts/init.sh` GREEN, 107 bats tests (28 in tests/cluster-bootstrap.bats); mutations killed: drop context guard; drop AcrPush
Evaluator: acceptance=4 correctness=4 boundaries=5 modularity=5 evidence=5 => avg 4.6 (PASS)
Notes:
  - Spec bug: `Azure Kubernetes Service RBAC Writer` cannot create namespaces/resourcequotas/httpscaledobjects -> DEC-024.
  - Real-cluster bugs fixed: HTTP add-on defaults unschedulable on 1 node (DEC-023); wildcard `kubectl auth can-i '*' '*'` returns "unknown" under Azure RBAC -> concrete verb.
  - Operator kubeconfig now uses kubelogin (`~/go/bin/kubelogin`, azurecli mode); break-glass: `az aks get-credentials --admin`.
  - SP may delete ANY namespace (k8s RBAC can't prefix-match) -> F009 adds an admission guard.

## 2026-09-28 — F004 stage 3 (wildcard DNS + TLS) — progress, feature still IN PROGRESS
Evidence:
  - `bootstrap/a2-wildcard-dns.sh --apply` -> `*.preview.nimat.dev A 74.151.139.236`; `dig anything.preview.nimat.dev @1.1.1.1` -> 74.151.139.236
  - `bootstrap/a3-cert-manager.sh --apply` -> cert-manager v1.21.2, UAMI `cert-manager-dns` (DNS Zone Contributor on zone, federated to cert-manager SA), ClusterIssuer `letsencrypt-dns` (no ACME email), Certificate `wildcard-preview` Ready, Traefik TLSStore `default` (`evidence/F004/a3-apply.txt`)
  - `openssl s_client anything.preview.nimat.dev:443` -> CN=*.preview.nimat.dev, issuer Let's Encrypt YR2, valid to 2026-12-27 (`evidence/F004/tls.txt`); `curl https://anything.preview.nimat.dev/` -> 404, ssl_verify_result=0 (trusted)
  - tests: 98/98 (A2: add/skip/stale-replace/no-LB/dry-run; A3: dry-run no mutation, MI client id + zone + no email in manifests, idempotent identity/role/federation, cert never Ready fails)

## 2026-09-28 — F004 stage 1 (Traefik + KEDA) — progress, feature still IN PROGRESS
Branch/commit: feat/F004 @ (this commit)
Evidence:
  - `bootstrap/a1-ingress.sh --apply` -> Traefik v3.7.13 deployed, LB_IP=74.151.139.236 (`evidence/F004/a1-apply.txt`)
  - `curl http://74.151.139.236/ -H 'Host: x.preview.nimat.dev'` -> 301 → https; https -> 404 (Traefik default)
  - `bootstrap/a4-keda.sh --apply` -> KEDA 2.21.0 + HTTP add-on 0.16.0 Running; interceptor `keda-add-ons-http-interceptor-proxy:8080` verified (`evidence/F004/a4-apply.txt`)
  - first A4 attempt failed: `context deadline exceeded` — 3 external-scaler pods Pending (Insufficient cpu, node at 88% requests). Fixed with sized values (DEC-023); re-run converged
  - spec chart `helm template … --set ingressClassName=traefik | kubectl apply --dry-run=server` -> all 6 objects accepted incl. HTTPScaledObject (`evidence/F004/chart-server-dry-run.txt`) — closes the spec's version-drift risk
  - tests: `bats tests/` 89/89 (10 new in tests/cluster-bootstrap.bats); mutation (drop context guard) killed; init GREEN
  - NS delegation live at Namecheap (BLK-005 resolved)

## 2026-09-28 — F013 Provision Azure prerequisites — COMPLETE
Branch/commit: feat/F013 @ (this commit)   PR: not opened (BLK-006)   CI: N/A
Contract: `verification/contracts/F013.md`
Evidence:
  - `bootstrap/provision.sh --apply` (human-approved, DEC-019) -> exit 0: registered Microsoft.ContainerRegistry; created ACR `nimatpreviewacr` (Basic), AKS `aks-preview`, DNS zone `preview.nimat.dev`
  - `az aks show` -> provisioningState Succeeded, power Running, k8s 1.35.8, tier Free, OIDC issuer + workload identity enabled (`evidence/F013/verify.txt`)
  - `kubectl get nodes` -> 1 node Ready (Standard_D2as_v7)
  - `az aks check-acr` -> name resolution, managed identity, image pull permission SUCCEEDED
  - second `--apply` -> skip ACR / skip AKS / skip DNS zone, exit 0 (`evidence/F013/apply-rerun.txt`)
  - zone NS: ns1-07.azure-dns.com. ns2-07.azure-dns.net. ns3-07.azure-dns.org. ns4-07.azure-dns.info.
  - full suite: `./scripts/init.sh` -> BASELINE GREEN, 79 bats tests (17 bootstrap)
  - mutations killed: dry-run executes; drop surge node; teardown defaults to delete; drop OIDC flags; capacity check on every run
Evaluator: acceptance=5 correctness=4 boundaries=5 modularity=5 evidence=5 => avg 4.8 (PASS)
Notes:
  - Two bugs escaped the fake az and were caught only against real Azure: (1) quota numbers are JSON strings (jq tonumber; fake now mirrors real shape); (2) quota preflight ran on every run and failed re-runs once the node consumed quota — capacity is now checked only when AKS will be created, and before any mutation. Both have regression tests.
  - Side effects on the operator machine: `--generate-ssh-keys` created ~/.ssh/id_rsa(.pub) (none existed); kubeconfig current-context is now `aks-preview`.
  - Cost is running (~$90–105/mo est. once ingress LB exists); `az aks stop -g nimatresourceg -n aks-preview` to pause, `bootstrap/teardown.sh --yes` to remove.

## 2026-09-28 — F004 discovery (read-only, no FID completion)
Evidence: `az account show`, `az account list`, `az group list`, `az aks list`, `az acr list`, `az network dns zone list`, `az graph query` -> 1 subscription, RG `nimatresourceg` empty; 0 AKS / 0 ACR / 0 DNS zones.
Notes: spec prerequisites absent -> proposed F013 (provision); BLK-001 / BLK-005 updated. Nothing created in Azure.

## 2026-09-28 — F003 Helm chart deploy/preview — COMPLETE
Branch/commit: feat/F003 (stacked on feat/F002) @ (this commit)   PR: not opened (BLK-006)   CI: N/A
Contract: `verification/contracts/F003.md` (written after the extraction step — process slip, noted)
Evidence:
  - chart = spec Part B, byte-identical (9 files extracted by script; bats diffs each against the spec)
  - `helm lint ./deploy/preview` -> 0 failed (INFO: icon recommended)
  - `helm template t ./deploy/preview -f tests/fixtures/values.yaml | kubeconform -strict -summary -ignore-missing-schemas` -> Valid 5, Invalid 0, Errors 0, Skipped 1 (HTTPScaledObject: no bundled CRD schema)
  - `./scripts/init.sh` -> BASELINE GREEN, helm steps active (no longer skipped); check-architecture templates=8 clean
  - full suite: `bats tests/` -> 62 passed, 0 failed (16 new in tests/chart.bats)
  - render assertions: no Namespace; no Deployment replicas; image repo:tag; Ingress → keda-http-interceptor:8080, upstream-vhost = host; no secretName; HTTPScaledObject host/scaledownPeriod/min/max; ExternalName + port overrides; ResourceQuota values
  - edge cases: name exactly 50 kept; >50 truncated with trailing `-` trimmed; idle "never" (31536000) renders as int; missing host / image.repository / image.tag each fail the render
  - checker probes (mutations, each killed): add replicas; add secretName; add Namespace template; drop validate guard
  - e2e: N/A here — F005
Evaluator: acceptance=5 correctness=5 boundaries=5 modularity=5 evidence=4 => avg 4.8 (PASS)
Notes:
  - Finding: with defaults only, the spec chart renders `host: ""` / `image: ":"` and kubeconform still accepts it. Added `templates/validate.yaml` (required guards) instead of editing spec files (DEC-018).
  - Test hygiene: `! cmd` never fails a bats test under `set -e`; negative asserts use grep -c == 0.

## 2026-09-28 — F002 Pure core scripts/lib/preview.sh — COMPLETE
Branch/commit: feat/F002 (stacked on feat/F001) @ (this commit)   PR: not opened (BLK-006)   CI: N/A
Contract: `verification/contracts/F002.md`
Evidence:
  - `./scripts/init.sh` -> BASELINE GREEN; check-architecture now scans lib=1 -> clean (rule 1 holds)
  - full suite: `bats tests/` -> 46 passed, 0 failed (21 new in tests/preview.bats; F001's 25 still green)
  - spec parity: `preview_id` == spec inline pipeline over a 14-branch corpus
  - edge cases: empty/whitespace/all-symbol/emoji-only -> fail; exactly 40 chars; >40 with `-` at cut; unicode; `-n`/`-e`; `08h` decimal; malformed durations (12, h, 1w, 1.5h, -1h, 1hm, " 1h", 1H); 0h lifetime; custom+empty; expires-at == now not expired; missing/garbage label expired; foreign namespace ignored; empty list; malformed JSON; bad now; sourcing leaves caller shell options untouched
  - checker probes (mutations, each killed): `<`→`<=`; missing label→not expired; drop base-10; drop managed-by filter; printf→echo
  - e2e: N/A — library (consumed by F006–F008)
Evaluator: acceptance=5 correctness=5 boundaries=5 modularity=5 evidence=5 => avg 5.0 (PASS)
Notes:
  - Stricter than spec on purpose (DEC-017): printf not echo; invalid/zero durations rejected; non-numeric expires-at = expired; managed-by re-checked in jq.
  - Also hardened F001 tests: bash 3.2 (macOS) ignores failing non-final `[[ ]]`, so every `[[ ]]` assert now ends `|| false`.

## 2026-09-28 — F001 Repo tooling — COMPLETE
Branch/commit: feat/F001 @ (this commit)   PR: not opened (BLK-006)   CI: N/A (no CI yet)
Contract: `verification/contracts/F001.md`
Evidence:
  - `./scripts/init.sh` -> BASELINE GREEN (roadmap gate, yamllint, shellcheck, bats, check-architecture; actionlint/helm/e2e skipped: targets absent)
  - full suite: `bats tests/` -> 25 passed, 0 failed (18 check-architecture, 7 init)
  - rules 1-9: one violation fixture each -> exit 1 naming the rule; compliant tree -> clean; empty tree -> clean
  - edge cases: empty tree, comments ignored, near-miss identifiers, GITHUB_TOKEN allowed, missing/extra/job-level permissions, multiple violations, bad args (exit 2), roadmap 0/1/2/empty/missing
  - checker probes: mutation (disable rule 5) -> tests 9,16 fail; mutation (drop comment strip) -> test 2 fails; bad YAML file -> init RED (yamllint); tools off PATH -> init RED "tool missing"
  - e2e: N/A — not user-facing
Evaluator: acceptance=5 correctness=5 boundaries=5 modularity=4 evidence=5 => avg 4.8 (PASS)
Notes:
  - Fixtures are generated per test in temp dirs (not static files under tests/fixtures/arch/) so yamllint/shellcheck never lint deliberate violations.
  - Tools installed without brew (brew blocked on Xcode license): yamllint via pipx (~/.local/bin), kubeconform via go install (~/go/bin), bats via npm. init.sh prepends ~/.local/bin and ~/go/bin.
  - Also fixed SC2001 in `.claude/hooks/harness-stop-guard.sh` (now shellchecked by init).
  - Modularity 4: rules are one block each in check-architecture.sh, not a registry — adequate for 9 grep rules.

## 2026-09-28 — chore: confirm todo target, drop placeholder README, open PR (harness-only, no FID)
Branch/commit: chore/harness-and-todo @ 3bae845   PR: NOT OPENED — `gh pr create` -> "must be a collaborator" (BLK-006)
Evidence:
  - user confirmed `todo/` is long-term preview target -> DEC-012 updated, BLK-002 narrowed to F006 build context
  - root `README.md` (one line: `# ephemeral-environments`) deleted by user; committed — root `CLAUDE.md` + `.harness/README.md` cover it

## 2026-09-28 — chore: harness enforcement hooks (harness-only, no FID)
Branch/commit: chore/harness-and-todo @ (this commit)   PR: not opened   CI: N/A
Evidence (pipe-tested each hook with synthetic stdin):
  - `harness-session-start.sh` -> emits additionalContext with PROJECT_STATE "Where we are" + CURRENT_TASK next step; writes git baseline
  - `harness-prompt-reminder.sh` -> emits UserPromptSubmit additionalContext
  - `harness-stop-guard.sh`: clean tree -> exit 0 (no output); new non-harness file -> {"decision":"block"}; same + PROJECT_STATE edited -> exit 0; stop_hook_active=true -> exit 0; pre-existing dirt (README.md deletion) ignored via baseline
  - `jq -e` on `.claude/settings.json` -> all 3 commands resolve
Notes: hooks load on next session start (or after opening `/hooks`); not live in the session that created them.

## 2026-09-28 — chore: root CLAUDE.md (harness-only, no FID) — retroactive
Branch/commit: chore/harness-and-todo @ aa73f65
Evidence: root `CLAUDE.md` `@`-imports `.harness/CLAUDE.md` + `.harness/AGENTS.md`; links read order.
Notes: done outside the loop (no tracking updates at the time); recorded here after user flagged it.

## 2026-09-28 — F012 Sample app container (todo) — COMPLETE (retroactive)
Branch/commit: chore/harness-and-todo @ 8f4ef86 (should have been feat/F012 — see Notes)   PR: not opened   CI: N/A
Evidence:
  - `docker build -t todo:local todo/` -> success; image 76.4MB
  - `docker run -p 18080:8080 todo:local` + `curl localhost:18080/` -> 200
  - `curl localhost:18080/some/route` -> 200 (SPA fallback)
  - `docker exec <ctr> id -u` -> 101 (non-root)
  - full suite / check-architecture: N/A (not built yet, F001)
  - e2e: N/A locally; real-cluster e2e = F005
Evaluator (retroactive checker pass): acceptance=5 correctness=4 boundaries=N/A modularity=4 evidence=4 => avg 4.25 (PASS)
Notes: built outside the harness loop (no FID, no contract, tracking not updated) — recorded after user flagged it. Deploy workflow must use `context: todo` (BLK-002).

## 2026-09-28 — chore: harness filled from spec (harness-only, no FID)
Branch/commit: chore/harness-and-todo @ c5307aa
Evidence: all `<<FILL>>` placeholders resolved (`grep -rn '<<FILL' .harness` -> only spec); ROADMAP 11 features / 3 phases; DEC-001..011; BLK-001..005.
