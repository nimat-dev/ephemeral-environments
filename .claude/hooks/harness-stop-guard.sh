#!/usr/bin/env bash
# Stop: block if this session changed files outside .harness/ but did not
# update .harness/PROJECT_STATE.md. Baseline comes from harness-session-start.sh.
set -euo pipefail
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root"
input=$(cat)
[ "$(jq -r '.stop_hook_active // false' <<<"$input")" = "true" ] && exit 0
sid=$(jq -r '.session_id // "unknown"' <<<"$input")
base_file="${TMPDIR:-/tmp}/claude-harness/$sid"
[ -f "$base_file" ] || exit 0   # no baseline (session started before hook) -> don't guess

base_head=$(head -1 "$base_file")
base_status=$(tail -n +2 "$base_file")

changed=$(
  {
    if [ "$base_head" != none ]; then git diff --name-only "$base_head" HEAD 2>/dev/null || true; fi
    git status --porcelain 2>/dev/null | grep -vxF -f <(printf '%s\n' "$base_status") | cut -c4- || true
  } | sed 's/.* -> //' | sort -u
)
[ -n "$changed" ] || exit 0

# The state rule itself lives once, in scripts/harness-check.sh (also run by pre-commit + CI).
out=$(scripts/harness-check.sh --files <<<"$changed" 2>&1) && exit 0

reason="Harness guard (session changes):
$out
Run the Session-completion protocol (AGENTS.md): CHANGELOG evidence, ROADMAP/phase status, PROJECT_STATE, CURRENT_TASK, BLOCKERS/DECISIONS."
jq -n --arg r "$reason" '{decision:"block",reason:$r}'
