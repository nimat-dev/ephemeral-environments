#!/usr/bin/env bash
# Copy the GENERIC harness files of this repo into the Copier template (F022, DEC-052), so the template
# never drifts from what this project runs. Project-specific files are hand-written *.jinja in the template.
# Usage: scripts/build-harness-template.sh [--check]   (--check: exit 1 if the template is stale)
set -euo pipefail
log() { printf '[%s] build-harness-template: %s\n' "$1" "$2" >&2; }
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
check=0; [ "${1-}" = --check ] && check=1
dst=templates/harness/template

# Generic = no project names, ids or tech (see F022 contract); keep in sync with tests/harness.bats.
generic=(
  .harness/RUNTIME-CONTINUITY.md .harness/RUNTIME-SWITCHES.md
  .harness/graph/graph.json .harness/graph/workflow-graph.md
  .harness/loops/failure-modes.md .harness/loops/maker-checker-loop.md .harness/loops/pr-review-loop.md
  .harness/loops/timer-loop.md .harness/loops/goal.md
  .harness/verification/acceptance-evidence.md .harness/verification/edge-cases.md .harness/verification/roles.md
  .harness/verification/sprint-contract.md .harness/verification/evaluator-rubric.md
  .harness/rules/conventions.md .harness/state/clean-state-checklist.md .harness/scripts/SCRIPTS.md
  .harness/commands/start-session.md .harness/commands/start-feature.md .harness/commands/finish-session.md
  scripts/harness-check.sh scripts/sync-agent-commands.sh .githooks/pre-commit .github/workflows/harness-check.yml
  .github/prompts/harness-start-session.prompt.md .github/prompts/harness-start-feature.prompt.md
  .github/prompts/harness-finish-session.prompt.md
)
# Claude-only files land under a copier-conditional directory name.
claude=(.claude/settings.json .claude/hooks/harness-session-start.sh .claude/hooks/harness-prompt-reminder.sh
  .claude/hooks/harness-stop-guard.sh .claude/commands/harness-start-session.md .claude/commands/harness-start-feature.md
  .claude/commands/harness-finish-session.md)
cdir='{% if claude_hooks %}.claude{% endif %}'

stale=0
place() { # SRC DEST
  if [ "$check" -eq 1 ]; then
    cmp -s "$1" "$2" || { log error "stale: $2 (from $1)"; stale=1; }
  else
    mkdir -p "$(dirname "$2")"; cp -p "$1" "$2"
  fi
}
for f in "${generic[@]}"; do place "$f" "$dst/$f"; done
for f in "${claude[@]}"; do place "$f" "$dst/$cdir/${f#.claude/}"; done
if [ "$check" -eq 0 ]; then
  mkdir -p "$dst/.harness/verification/contracts" "$dst/.harness/evidence" "$dst/.harness/product" "$dst/.harness/architecture"
  touch "$dst/.harness/verification/contracts/.gitkeep" "$dst/.harness/evidence/.gitkeep" \
        "$dst/.harness/product/.gitkeep" "$dst/.harness/architecture/.gitkeep"
  log info "template refreshed ($(( ${#generic[@]} + ${#claude[@]} )) generic files)"
fi
[ "$stale" -eq 0 ] || { log error "run scripts/build-harness-template.sh"; exit 1; }
[ "$check" -eq 1 ] && log info "template up to date"
exit 0
