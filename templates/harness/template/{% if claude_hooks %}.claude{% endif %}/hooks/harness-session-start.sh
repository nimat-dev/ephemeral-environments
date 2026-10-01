#!/usr/bin/env bash
# SessionStart: inject harness state + snapshot git baseline for the Stop guard.
set -euo pipefail
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root"
input=$(cat)
sid=$(jq -r '.session_id // "unknown"' <<<"$input")

# shellcheck source=harness-lib.sh
. "$(dirname "$0")/harness-lib.sh"
state_dir="${TMPDIR:-/tmp}/claude-harness"
mkdir -p "$state_dir"
# Baseline: HEAD, then "<content hash>\t<path>" of every path already dirty (tracked or untracked), so the
# Stop guard judges only what THIS session changed — including further edits to already-dirty files.
# Written ONCE per session: SessionStart re-fires on resume/compact with the same session_id, and
# re-recording then would absorb this session's own edits into the baseline. Atomic (tmp + mv) so a
# timeout never leaves a truncated baseline.
if [ ! -f "$state_dir/$sid" ]; then
  tmp=$(mktemp "$state_dir/.$sid.XXXXXX")
  {
    git rev-parse HEAD 2>/dev/null || echo none
    { git diff --no-renames --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } |
      sort -u | hash_paths
  } >"$tmp"
  mv -f "$tmp" "$state_dir/$sid"
fi

where=$(sed -n '/^## Where we are/,/^## /p' .harness/PROJECT_STATE.md | sed '$d')
next=$(sed -n '/^## Exact next step/,/^## /p' .harness/CURRENT_TASK.md | sed '$d')

ctx="HARNESS PROJECT. Every request goes through .harness/ (AGENTS.md contract):
map the ask to a feature id (or propose one in ROADMAP + phase file; off-phase work -> scope-guard/BLOCKERS),
work on feat/<FID> or chore|docs/<slug>, verify, record evidence in CHANGELOG,
update PROJECT_STATE + CURRENT_TASK (+ BLOCKERS/DECISIONS) before stopping.

$where

$next"
jq -n --arg c "$ctx" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
