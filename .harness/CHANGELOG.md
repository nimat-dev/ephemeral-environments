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

## 2026-09-28 — chore: confirm todo target, drop placeholder README, open PR (harness-only, no FID)
Branch/commit: chore/harness-and-todo   PR: see PROJECT_STATE
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
