#!/usr/bin/env bash
# Agent-agnostic harness enforcement — same checks for every agent and for humans:
#   1. roadmap gate: exactly one IN PROGRESS feature (or all COMPLETE/DEPRECATED)
#   2. state rule: changes outside .harness/ must come with a .harness/PROJECT_STATE.md update
#   3. agent command mirrors (.claude/commands, .github/prompts) match .harness/commands
# Usage: scripts/harness-check.sh [--staged | --range BASE...HEAD | --files | --roadmap-only | --current]
#                                 [--roadmap FILE] [--root DIR]
#   --staged  (pre-commit) all checks against the INDEX, not the working tree
#   --range   (CI) state rule over the diff; an all-zero BASE (branch creation, no base) skips it with a warning
#   --files   state rule only, over changed paths read from stdin (Claude Stop hook)
#   --roadmap-only  roadmap gate only (scripts/init.sh)   --current  print the IN PROGRESS roadmap line(s)
#   no mode   roadmap + mirrors
# Exit: 0 ok, 1 check failed, 2 usage.
set -euo pipefail

log() { printf '[%s] harness-check: %s\n' "$1" "$2" >&2; }
root="$(cd "$(dirname "$0")/.." && pwd)" mode="" range="" roadmap=""
while [ $# -gt 0 ]; do
  case "$1" in
    --staged) mode=staged; shift ;;
    --range) [ $# -ge 2 ] || { log error "--range needs BASE...HEAD"; exit 2; }; mode=range; range="$2"; shift 2 ;;
    --files) mode=files; shift ;;
    --roadmap-only) mode=roadmap; shift ;;
    --roadmap) [ $# -ge 2 ] || { log error "--roadmap needs a file"; exit 2; }
      roadmap="$(cd "$(dirname "$2")" 2>/dev/null && pwd)/$(basename "$2")" || roadmap="$2"; shift 2 ;;
    --root) [ $# -ge 2 ] || { log error "--root needs a directory"; exit 2; }; root="$(cd "$2" && pwd)"; shift 2 ;;
    --current) mode=current; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) log error "unknown argument: $1"; exit 2 ;;
  esac
done
cd "$root"
failed=0

# --staged judges what is being committed: roadmap + mirrors are read from a snapshot of the index.
tree="$root"
if [ "$mode" = staged ]; then
  tree=$(mktemp -d); trap 'rm -rf "$tree"' EXIT
  # only what the checks read — not the whole index (large / LFS / sparse repos)
  git ls-files -z -- .harness/ROADMAP.md .harness/commands .claude .github/prompts >"$tree.list"
  [ -s "$tree.list" ] && xargs -0 git checkout-index --prefix="$tree/" -- <"$tree.list"
  rm -f "$tree.list"
fi

# 1. roadmap gate — status = LAST backtick span of each `- [ ] **F…**` line (the one parser; init.sh uses it too)
features() { grep -E '^- \[.\] \*\*F[0-9]+\*\*' "$1" || true; }
# shellcheck disable=SC2016  # backticks are literal markdown
status_of() { sed -E 's/^.*`([^`]+)`[^`]*$/\1/'; }
check_roadmap() {
  local f="${roadmap:-$tree/.harness/ROADMAP.md}" st n total done_n
  [ -f "$f" ] || { log error "roadmap not found: $f"; return 1; }
  st=$(features "$f" | status_of)
  n=$(grep -cx 'IN PROGRESS' <<<"$st" || true); total=$(grep -c . <<<"$st" || true)
  done_n=$(grep -cxE 'COMPLETE|DEPRECATED' <<<"$st" || true)
  if [ "$n" -eq 0 ] && [ "$total" -gt 0 ] && [ "$done_n" -eq "$total" ]; then
    log info "roadmap complete: all $total features COMPLETE/DEPRECATED"
  elif [ "$n" -eq 1 ]; then log info "roadmap ok (1 IN PROGRESS, $done_n/$total done)"
  else log error "roadmap: expected exactly 1 IN PROGRESS feature (or all done) in $f, found $n of $total"; return 1; fi
}
if [ "$mode" = current ]; then
  features "${roadmap:-.harness/ROADMAP.md}" | while IFS= read -r l; do
    [ "$(status_of <<<"$l")" = 'IN PROGRESS' ] && sed -E 's/^- \[.\] //' <<<"$l"; done; exit 0
fi
[ "$mode" = files ] || check_roadmap || failed=1
if [ "$mode" = roadmap ]; then exit "$failed"; fi

# 2. state rule over the changed files (--no-renames: a move out of the code tree still lists its old path)
if [ -n "$mode" ]; then
  case "$mode" in
    staged) changed=$(git diff --cached --no-renames --name-only) ;;
    files) changed=$(cat) ;;
    range)
      base=${range%%...*} head=${range#*...}
      if [[ "$base" =~ ^0+$ ]]; then
        # branch creation: there is no "before" to judge against (an empty-tree diff would always contain
        # PROJECT_STATE.md and pass silently) — say so instead of pretending
        log warn "no base commit (branch creation push, head $head): state rule skipped"; changed=""
      else
        changed=$(git diff --no-renames --name-only "$range") || { log error "cannot diff range $range"; exit 2; }
      fi ;;
  esac
  code=$(grep -v '^\.harness/' <<<"$changed" | grep . || true)
  if [ "$mode" = range ] && [ -z "$changed" ]; then :
  elif [ -n "$code" ] && ! grep -qx '\.harness/PROJECT_STATE\.md' <<<"$changed"; then
    log error "files outside .harness/ changed without .harness/PROJECT_STATE.md (Session-completion protocol, AGENTS.md):"
    while IFS= read -r f; do printf '  - %s\n' "$f" >&2; done <<<"$code"; failed=1
  else log info "state rule ok ($(grep -c . <<<"$changed" || true) changed file(s))"; fi
fi

# 3. agent command mirrors
if [ "$mode" != files ] && [ -d "$tree/.harness/commands" ] && [ -x scripts/sync-agent-commands.sh ]; then
  scripts/sync-agent-commands.sh --check --root "$tree" || failed=1
fi

if [ "$failed" -eq 0 ]; then log info "ok"; else log error "failed"; fi
exit "$failed"
