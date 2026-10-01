# F022 PR #28 review

## Round 1 (2026-09-30, `/code-review high main...feat/F022`) — 10 findings, all fixed
| # | Finding | Fix |
|---|---|---|
| 1 | Remote `copier copy gh:…` can't see `templates/harness/copier.yml` (Copier reads root only) → would copy the whole repo | `copier.yml` moved to repo root, `_subdirectory: templates/harness/template`; test renders from repo root, asserts no `platform/`/`copier.yml` |
| 2 | `_answers_file` set but no answers template → `copier update` impossible | `{{ _copier_conf.answers_file }}.jinja`; test asserts `_src_path` |
| 3 | CI push creating a branch: `before` = 0000… → `git diff` exit 2 | zero base diffs from the empty tree; test |
| 4 | Rule 6 config replaced the generic ACR/cluster-DNS pattern | config now extends it; conf trimmed to project domains; test asserts ACR caught with conf present |
| 5 | Template drift check ignored exec bit | `--check` compares exec bit (manual: chmod -x copy → exit 1). Orphan-file detection not added: template has intended hand-written non-jinja files |
| 6 | `--staged` read roadmap + mirrors from the working tree | checks run on a `git checkout-index` snapshot of the index; test both directions |
| 7 | Rename folding hid a code file moved into `.harness/` | `--no-renames` on both diffs; test |
| 8 | Generic files cited F022/DEC-052 and `scripts/init.sh` the template lacks | ids stripped from generic files; finish-session falls back to `harness-check.sh` |
| 9 | Roadmap gate duplicated in init.sh | init delegates: `harness-check.sh --roadmap-only --roadmap FILE` (init.bats unchanged, green) |
| 10 | Claude Stop hook duplicated the state rule | hook pipes its changed list to `harness-check.sh --files`; test |

Verify after fixes: `./scripts/init.sh` BASELINE GREEN, bats 285/285.

## Round 2 (2026-09-30, `/code-review high` on the round-1 fixes + full diff) — 10 findings, all fixed
| # | Finding | Fix |
|---|---|---|
| 1 | Stop hook still folded renames (fix #7 only in harness-check) | hook lists `git diff --no-renames` vs session-start commit + untracked; real-hook test (git mv committed → block) |
| 2 | Already-dirty PROJECT_STATE edited again was invisible → false block | baseline stores content hash per dirty path; changed = hash differs; test both ways |
| 3 | Copier default = latest tag v1.0.0, which predates the template | copier.yml documents it (`--vcs-ref main` until v1.1.0); DEC-052: template versioned by this repo's tags; cut v1.1.0 after merge |
| 4 | Zero-base CI range diffed the empty tree → always passed | skipped with an explicit warning; test asserts warning, not "ok" |
| 5 | Quoted porcelain paths (spaces) misread as code | `core.quotePath=false`, no porcelain parsing; test with `run 1.txt` |
| 6 | Hook tests only grepped | 3 bats cases run the real SessionStart + Stop hooks in a temp repo |
| 7 | `--staged` materialised the whole index | checks out only ROADMAP, commands, `.claude`, prompts |
| 8 | init kept its own status parser for "Active feature" | `harness-check.sh --current`; unused regex dropped |
| 9 | PR body / DEC-052 / docs stale; modes undocumented | PR body + DEC-052 updated; `harness-check` contract in SCRIPTS.md; Commands row in `.harness/CLAUDE.md` |
| 10 | PR body carried a Claude attribution line (user CLAUDE.md forbids) | removed |

Verify after fixes: `./scripts/init.sh` BASELINE GREEN, bats 288/288, 0 skipped.

## Round 3 (2026-09-30, `/code-review high main...feat/F022`) — 9 findings, all fixed
| # | Finding | Fix |
|---|---|---|
| 1 | SessionStart re-fires on resume/compact (same session_id) and re-recorded the baseline → session edits absorbed, guard fails open | baseline written once per session, atomically (tmp + mv); test: re-fire then Stop still blocks |
| 2 | `--current` exit 1 when the last roadmap line isn't IN PROGRESS (pipefail + `&&` in while) | `if` instead of `&&`; test asserts status on both roadmaps |
| 3 | Hooks spawned one `git hash-object` (+ grep/tail) per path under a 10 s timeout → fail-open / truncated baseline | `.claude/hooks/harness-lib.sh`: one `git hash-object --stdin-paths` + one awk join; test: 300 pre-dirty + 1000 new files < 5 s |
| 4 | Any `.claude/` dir (Claude Code's own `settings.local.json`) demanded Claude mirrors | opt-in = `.claude/commands` or `.claude/settings.json`; test with only settings.local.json |
| 5 | Pre-commit blocked code-only merge/revert/cherry-pick commits | `--staged` skips the state rule with a warning while MERGE_HEAD/REVERT_HEAD/CHERRY_PICK_HEAD exists (CI range still judges); test |
| 6 | `--roadmap` fallback dead → `/R.md` | `if d=$(cd …)`; test |
| 7 | Force-pushed main: `event.before` not in clone → exit 2, red main | full-SHA base missing from the clone → skip with warning (garbage base still exit 2); test |
| 8 | Description YAML escaped only `"` | also `\` + control chars stripped; test parses `C:\tools\init "now" \d+` via yq |
| 9 | Template `--check` missed orphans / missing scaffolding | `--check` diffs the template tree vs generic+claude+handwritten+.gitkeep sets (non-jinja); test on a repo copy |

Verify after fixes: `./scripts/init.sh` BASELINE GREEN, bats 294/294, shellcheck clean.

## Round 4 (2026-10-01, final pass on main...feat/F022) — CLEAN (0 findings)
- Full diff inspected against contract, DEC-052, and evaluator rubric:
  - Canonical root AGENTS.md, CLAUDE.md import, Copilot pointer in sync
  - Agent command generation and drift check clean
  - harness-check.sh and pre-commit hook verified
  - Copier template tree and drift check clean
  - check-architecture configuration clean
- Verification: `./scripts/init.sh` BASELINE GREEN (294/294 bats tests, tofu validate/test 10/10, tflint, checkov, check-architecture clean).
- GitHub Actions CI `harness-check` green on PR #28.
- Verdict: PASS / CLEAN. Ready for merge and v1.1.0 release.

