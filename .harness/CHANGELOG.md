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
