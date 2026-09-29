# PR review — #16 chore/project-complete, 2026-09-29

Round 1 (`/code-review medium 16`):

| # | Where | Finding | Outcome |
|---|---|---|---|
| 1 | init.sh done-count (medium) | `COMPLETE`/`DEPRECATED` matched anywhere on the line → a NOT STARTED feature whose description mentions `COMPLETE` made the finished-roadmap check pass (reproduced) | fixed: `feature_statuses` takes each feature line's LAST backtick span as its status; IN PROGRESS count uses it too (fixes the same pre-existing weakness); bats `roadmap: status is the last backtick span…` |

`./scripts/init.sh` BASELINE GREEN 188/188.

Round 2 (on 0a26def): `CURRENT_TASK.md` lost the `## Exact next step` heading that the session-start hook and `init.sh` read → empty next step. Fixed: heading restored (follow-ups listed under it). PR body count 187→188. `init.sh` prints the follow-ups again.
