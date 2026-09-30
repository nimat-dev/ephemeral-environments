#!/usr/bin/env bash
# Agent-agnostic harness enforcement (F022, DEC-052) — same checks for every agent and for humans:
#   1. roadmap gate: exactly one IN PROGRESS feature (or all COMPLETE/DEPRECATED)
#   2. state rule: changes outside .harness/ must come with a .harness/PROJECT_STATE.md update
#   3. agent command mirrors (.claude/commands, .github/prompts) match .harness/commands
# Usage: scripts/harness-check.sh [--staged | --range BASE...HEAD] [--root DIR]
#   --staged  (pre-commit, .githooks/pre-commit)   --range  (CI, .github/workflows/harness-check.yml)
#   no mode   roadmap + mirrors only
# Exit: 0 ok, 1 check failed, 2 usage.
set -euo pipefail

log() { printf '[%s] harness-check: %s\n' "$1" "$2" >&2; }
root="$(cd "$(dirname "$0")/.." && pwd)" mode="" range=""
while [ $# -gt 0 ]; do
  case "$1" in
    --staged) mode=staged; shift ;;
    --range) [ $# -ge 2 ] || { log error "--range needs BASE...HEAD"; exit 2; }; mode=range; range="$2"; shift 2 ;;
    --root) [ $# -ge 2 ] || { log error "--root needs a directory"; exit 2; }; root="$(cd "$2" && pwd)"; shift 2 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) log error "unknown argument: $1"; exit 2 ;;
  esac
done
cd "$root"
failed=0

# 1. roadmap gate — status = LAST backtick span of each `- [ ] **F…**` line
roadmap=.harness/ROADMAP.md
if [ ! -f "$roadmap" ]; then log error "missing $roadmap"; failed=1
else
  # shellcheck disable=SC2016  # backticks are literal markdown
  st=$(grep -E '^- \[.\] \*\*F[0-9]+\*\*' "$roadmap" | sed -E 's/^.*`([^`]+)`[^`]*$/\1/' || true)
  n=$(grep -cx 'IN PROGRESS' <<<"$st" || true); total=$(grep -c . <<<"$st" || true)
  done_n=$(grep -cxE 'COMPLETE|DEPRECATED' <<<"$st" || true)
  if [ "$n" -eq 1 ] || { [ "$n" -eq 0 ] && [ "$total" -gt 0 ] && [ "$done_n" -eq "$total" ]; }; then
    log info "roadmap ok ($n IN PROGRESS, $done_n/$total done)"
  else log error "roadmap: expected exactly 1 IN PROGRESS feature (or all done), found $n of $total"; failed=1; fi
fi

# 2. state rule over the changed files
if [ -n "$mode" ]; then
  if [ "$mode" = staged ]; then changed=$(git diff --cached --name-only)
  else changed=$(git diff --name-only "$range") || { log error "cannot diff range $range"; exit 2; }; fi
  code=$(grep -v '^\.harness/' <<<"$changed" | grep . || true)
  if [ -n "$code" ] && ! grep -qx '\.harness/PROJECT_STATE\.md' <<<"$changed"; then
    log error "files outside .harness/ changed without .harness/PROJECT_STATE.md (Session-completion protocol, AGENTS.md):"
    while IFS= read -r f; do printf '  - %s\n' "$f" >&2; done <<<"$code"; failed=1
  else log info "state rule ok ($(grep -c . <<<"$changed" || true) changed file(s))"; fi
fi

# 3. agent command mirrors
if [ -d .harness/commands ] && [ -x scripts/sync-agent-commands.sh ]; then
  scripts/sync-agent-commands.sh --check --root "$root" || failed=1
fi

if [ "$failed" -eq 0 ]; then log info "ok"; else log error "failed"; fi
exit "$failed"
