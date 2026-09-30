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

git() { command git -c core.quotePath=false "$@"; }
base_head=$(head -1 "$base_file")
# Candidates: everything that differs from the session's start commit (committed or not; renames split into
# delete + add so a move out of the code tree counts), plus untracked files.
changed=$(
  {
    if [ "$base_head" != none ]; then git diff --no-renames --name-only "$base_head" 2>/dev/null || true
    else git ls-files 2>/dev/null || true; fi
    git ls-files --others --exclude-standard 2>/dev/null || true
  } | sort -u | while IFS= read -r p; do
    [ -n "$p" ] || continue
    now=$(git hash-object -- "$p" 2>/dev/null || echo -)
    # already dirty at session start with the same content -> not this session's change
    grep -qxF "$now	$p" <(tail -n +2 "$base_file") || printf '%s\n' "$p"
  done
)
[ -n "$changed" ] || exit 0

# The state rule itself lives once, in scripts/harness-check.sh (also run by pre-commit + CI).
out=$(scripts/harness-check.sh --files <<<"$changed" 2>&1) && exit 0

reason="Harness guard (session changes):
$out
Run the Session-completion protocol (AGENTS.md): CHANGELOG evidence, ROADMAP/phase status, PROJECT_STATE, CURRENT_TASK, BLOCKERS/DECISIONS."
jq -n --arg r "$reason" '{decision:"block",reason:$r}'
