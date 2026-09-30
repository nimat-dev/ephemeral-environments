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
