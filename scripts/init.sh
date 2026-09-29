#!/usr/bin/env bash
# Verify a clean, reproducible baseline (.harness/scripts/SCRIPTS.md -> init).
# Usage: scripts/init.sh [--roadmap-only] [--roadmap FILE]
#   --roadmap-only  run only the ROADMAP gate (exactly one IN PROGRESS feature, or all COMPLETE)
#   --roadmap FILE  ROADMAP to check (default .harness/ROADMAP.md)
# Steps skip when their target is absent; a missing tool with a present target fails.
# Exit: 0 baseline green, 1 failed steps (listed), 2 usage error.
set -uo pipefail
shopt -s nullglob

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root" || exit 2
export PATH="$HOME/.local/bin:$HOME/go/bin:$PATH"   # pipx / go install locations

# Backticks are literal markdown, not command substitution.
# shellcheck disable=SC2016
in_progress_re='^- \[.\] \*\*F[0-9]+\*\*.*`IN PROGRESS`'

log() { printf '[%s] init: %s\n' "$1" "$2" >&2; }

roadmap=".harness/ROADMAP.md"
roadmap_only=0
while [ $# -gt 0 ]; do
  case "$1" in
    --roadmap-only) roadmap_only=1; shift ;;
    --roadmap)
      [ $# -ge 2 ] || { log error "--roadmap needs a file"; exit 2; }
      roadmap="$2"; shift 2 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) log error "unknown argument: $1"; exit 2 ;;
  esac
done

failed=()
fail() { failed+=("$1"); log error "$1"; }

# step NAME CMD... -- run CMD, record pass/fail.
step() {
  local name="$1"; shift
  log info "▶ $name"
  if "$@"; then log info "✔ $name"; else fail "$name"; fi
}

# need TOOL NAME -- true if TOOL exists, else records a failure for NAME.
need() { command -v "$1" >/dev/null 2>&1 || { fail "$2 (tool missing: $1)"; return 1; }; }

check_roadmap() {
  [ -f "$roadmap" ] || { log error "roadmap not found: $roadmap"; return 1; }
  local n total done_n
  n=$(grep -cE "$in_progress_re" "$roadmap" || true)
  # Roadmap finished: zero IN PROGRESS is valid only when every feature is COMPLETE/DEPRECATED.
  total=$(grep -cE '^- \[.\] \*\*F[0-9]+\*\*' "$roadmap" || true)
  # shellcheck disable=SC2016  # backticks are literal markdown
  done_n=$(grep -cE '^- \[.\] \*\*F[0-9]+\*\*.*`(COMPLETE|DEPRECATED)`' "$roadmap" || true)
  if [ "$n" -eq 0 ] && [ "$total" -gt 0 ] && [ "$done_n" -eq "$total" ]; then
    log info "roadmap complete: all $total features COMPLETE/DEPRECATED"; return 0
  fi
  [ "$n" -eq 1 ] || { log error "expected exactly 1 IN PROGRESS feature in $roadmap, found $n"; return 1; }
}

log info "start root=$root"

step "roadmap: one IN PROGRESS (or all COMPLETE)" check_roadmap
if [ "$roadmap_only" -eq 1 ]; then
  [ ${#failed[@]} -eq 0 ] && exit 0 || exit 1
fi

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  log warn "working tree is dirty (see .harness/loops/failure-modes.md)"
fi

need yamllint yamllint && step yamllint yamllint .

sh_files=(scripts/*.sh scripts/lib/*.sh bootstrap/*.sh .claude/hooks/*.sh tests/fakes/*)
if [ ${#sh_files[@]} -gt 0 ]; then
  need shellcheck shellcheck && step shellcheck shellcheck "${sh_files[@]}"
else log info "skip shellcheck (no shell scripts)"; fi

workflows=(.github/workflows/*.yml .github/workflows/*.yaml)
if [ ${#workflows[@]} -gt 0 ]; then
  need actionlint actionlint && step actionlint actionlint
else log info "skip actionlint (no workflows yet — Phase 02)"; fi

if [ -f deploy/preview/Chart.yaml ]; then
  if need helm helm && need kubeconform kubeconform; then
    step "helm lint" helm lint ./deploy/preview
    render() {
      helm template t ./deploy/preview -f tests/fixtures/values.yaml \
        | kubeconform -strict -summary -ignore-missing-schemas
    }
    step "helm template | kubeconform" render
  fi
else log info "skip helm (no chart yet — F003)"; fi

bats_files=(tests/*.bats)
if [ ${#bats_files[@]} -gt 0 ]; then
  need bats bats && step "bats (full suite)" bats tests/
else log info "skip bats (no tests)"; fi

step check-architecture ./scripts/check-architecture.sh

log info "skip e2e smoke (no runner yet — F005)"

echo
echo "== Active feature =="
grep -E "$in_progress_re" "$roadmap" | sed -E 's/^- \[.\] //' || true
echo "== Next step (CURRENT_TASK.md) =="
sed -n '/^## Exact next step/,/^## /p' .harness/CURRENT_TASK.md | sed '1d;$d'

if [ ${#failed[@]} -gt 0 ]; then
  echo
  echo "BASELINE RED — failed steps:"
  printf '  - %s\n' "${failed[@]}"
  exit 1
fi
echo
echo "BASELINE GREEN"
log info "done"
