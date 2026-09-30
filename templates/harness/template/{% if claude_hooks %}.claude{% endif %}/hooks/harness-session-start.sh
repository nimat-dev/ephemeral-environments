#!/usr/bin/env bash
# SessionStart: inject harness state + snapshot git baseline for the Stop guard.
set -euo pipefail
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root"
input=$(cat)
sid=$(jq -r '.session_id // "unknown"' <<<"$input")

state_dir="${TMPDIR:-/tmp}/claude-harness"
mkdir -p "$state_dir"
{ git rev-parse HEAD 2>/dev/null || echo none; git status --porcelain 2>/dev/null; } >"$state_dir/$sid"

where=$(sed -n '/^## Where we are/,/^## /p' .harness/PROJECT_STATE.md | sed '$d')
next=$(sed -n '/^## Exact next step/,/^## /p' .harness/CURRENT_TASK.md | sed '$d')

ctx="HARNESS PROJECT. Every request goes through .harness/ (AGENTS.md contract):
map the ask to a feature id (or propose one in ROADMAP + phase file; off-phase work -> scope-guard/BLOCKERS),
work on feat/<FID> or chore|docs/<slug>, verify, record evidence in CHANGELOG,
update PROJECT_STATE + CURRENT_TASK (+ BLOCKERS/DECISIONS) before stopping.

$where

$next"
jq -n --arg c "$ctx" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
