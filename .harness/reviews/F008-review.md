# F008 review — PR #11

## Round 1 (2026-09-28) — CLEAN
- Selection: label selector server-side + lib re-checks label and `preview-` prefix. OK
- `while read` over here-string: a delete failure is caught per item (`if kubectl …`), loop continues, exit 1 after. OK (bats)
- `kubectl get` failure / malformed JSON → pipefail / jq error aborts before any delete. OK (bats)
- Time: `date -u +%s` on the runner; label written by deploy from the runner clock — same source. OK
Accepted note: GitHub cron can be delayed/skipped; lifetime is a lower bound (spec behavior).
