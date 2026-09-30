#!/usr/bin/env bash
# One source of agent commands: .harness/commands/<name>.md (first line `# <description>`)
# rendered for Claude Code (.claude/commands/harness-<name>.md) and GitHub Copilot
# (.github/prompts/harness-<name>.prompt.md). Usage: scripts/sync-agent-commands.sh [--check] [--root DIR]
# Exit: 0 in sync / written, 1 out of sync (--check), 2 usage.
set -euo pipefail
log() { printf '[%s] sync-agent-commands: %s\n' "$1" "$2" >&2; }
root="$(cd "$(dirname "$0")/.." && pwd)" check=0
while [ $# -gt 0 ]; do
  case "$1" in
    --check) check=1; shift ;;
    --root) [ $# -ge 2 ] || { log error "--root needs a directory"; exit 2; }; root="$(cd "$2" && pwd)"; shift 2 ;;
    *) log error "unknown argument: $1"; exit 2 ;;
  esac
done
cd "$root"
shopt -s nullglob
out=$(mktemp -d); trap 'rm -rf "$out"' EXIT
mkdir -p "$out/.claude/commands" "$out/.github/prompts"
for src in .harness/commands/*.md; do
  name=$(basename "$src" .md)
  desc=$(head -1 "$src" | sed -E 's/^#[[:space:]]*//; s/"/\\"/g')
  body=$(tail -n +2 "$src")
  banner="<!-- GENERATED from .harness/commands/$name.md by scripts/sync-agent-commands.sh — edit the source. -->"
  printf -- '---\ndescription: "%s"\n---\n%s\n%s\n' "$desc" "$banner" "$body" >"$out/.claude/commands/harness-$name.md"
  printf -- '---\nmode: agent\ndescription: "%s"\n---\n%s\n%s\n' "$desc" "$banner" "$body" >"$out/.github/prompts/harness-$name.prompt.md"
done
rc=0
# Claude mirrors only when the repo uses Claude Code (.claude/ exists; the template makes it optional).
dirs=(.github/prompts); [ -d .claude ] && dirs=(.claude/commands "${dirs[@]}")
for dir in "${dirs[@]}"; do
  if [ "$check" -eq 1 ]; then
    [ -d "$dir" ] || { log error "$dir missing (run scripts/sync-agent-commands.sh)"; rc=1; continue; }
    # only harness-* files are ours; other commands/prompts are left alone
    if ! diff -r <(cd "$out/$dir" && for f in harness-*; do printf '== %s\n' "$f"; cat "$f"; done) \
                 <(cd "$dir" && for f in harness-*; do printf '== %s\n' "$f"; cat "$f"; done) >/dev/null; then
      log error "$dir is out of sync with .harness/commands (run scripts/sync-agent-commands.sh)"; rc=1
    fi
  else
    mkdir -p "$dir"; rm -f "$dir"/harness-*; cp "$out/$dir"/harness-* "$dir"/ 2>/dev/null || true
  fi
done
[ "$check" -eq 1 ] && [ "$rc" -eq 0 ] && log info "in sync"
exit "$rc"
