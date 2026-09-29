# PR review — #14 feat/F010 (quota-check), 2026-09-29

Round 1 (`/code-review medium 14`): arg guard, trap cleanup, wrong-reason handling, fakes correct.

| # | Where | Finding | Outcome |
|---|---|---|---|
| 1 | quota-check.sh cleanup (low) | `--wait=false` exits while fill pods terminate; they still count vs hard.pods → quick rerun CP4 false FAIL, blocks KEDA wake | fixed: `remove_fill` waits (`--grace-period=1 --wait=true --timeout`), also runs before reading usage; bats asserts both; live two back-to-back runs ALL PASS, 0 leftovers |
| 2 | quota-check.sh fill (low) | fill-pod failure logged without cause | fixed: kubectl output in the CP4 FAIL line; bats asserts reason |

Round 2: `./scripts/init.sh` BASELINE GREEN 165/165. Clean.
