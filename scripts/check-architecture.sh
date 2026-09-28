#!/usr/bin/env bash
# Enforce .harness/rules/layer-boundaries.md (rules 1-9).
# Usage: scripts/check-architecture.sh [--root DIR]
# Output: "<file>:<line> -> <match> -> rule N" per violation, or "clean".
# Exit: 0 clean, 1 violations, 2 usage error.
set -euo pipefail
shopt -s nullglob

log() { printf '[%s] check-architecture: %s\n' "$1" "$2" >&2; }

root="$(cd "$(dirname "$0")/.." && pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      [ $# -ge 2 ] || { log error "--root needs a directory"; exit 2; }
      [ -d "$2" ] || { log error "--root: not a directory: $2"; exit 2; }
      root="$(cd "$2" && pwd)"; shift 2 ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) log error "unknown argument: $1"; exit 2 ;;
  esac
done
cd "$root"

violations=0

# scan RULE REGEX [EXCLUDE_REGEX] -- FILES...
# Prints matching non-comment lines. EXCLUDE removes allowed tokens before re-testing.
scan() {
  local rule="$1" re="$2" ex="$3"; shift 3
  [ $# -gt 0 ] || return 0
  local out
  out=$(RE="$re" EX="$ex" RULE="$rule" awk '
    {
      line = $0
      sub(/(^|[ \t])#.*/, "", line)          # strip comments
      if (line !~ ENVIRON["RE"]) next
      if (ENVIRON["EX"] != "") { t = line; gsub(ENVIRON["EX"], "", t); if (t !~ ENVIRON["RE"]) next }
      gsub(/^[ \t]+|[ \t]+$/, "", line)
      printf "%s:%d -> %s -> rule %s\n", FILENAME, FNR, line, ENVIRON["RULE"]
    }' "$@")
  if [ -n "$out" ]; then
    printf '%s\n' "$out"
    violations=$((violations + $(printf '%s\n' "$out" | wc -l)))
  fi
}

report() { printf '%s -> rule %s\n' "$1" "$2"; violations=$((violations + 1)); }

lib=(scripts/lib/*.sh)
wf=(.github/workflows/*.yml .github/workflows/*.yaml)
tpl=(deploy/preview/templates/*.yaml deploy/preview/templates/*.yml deploy/preview/templates/*.tpl)

log info "root=$root lib=${#lib[@]} workflows=${#wf[@]} templates=${#tpl[@]}"

# 1. Pure core: no adapter calls in scripts/lib.
scan 1 '(^|[^A-Za-z0-9_./-])(az|kubectl|helm|docker|curl|gh)([ \t]|$)' '' ${lib[@]+"${lib[@]}"}

# 2. Single identity implementation: no inline sanitizer in workflows.
scan 2 '\[\^a-z0-9\]' '' ${wf[@]+"${wf[@]}"}

# 3. No secrets: only secrets.GITHUB_TOKEN allowed (exact name); never client-secret or secrets[...].
scan 3 'client-secret|secrets[[:space:]]*(\.|\[)' 'secrets\.GITHUB_TOKEN([^A-Za-z0-9_-]|$)' ${wf[@]+"${wf[@]}"}

# 4. Chart never renders a Namespace.
scan 4 '^[ \t]*kind:[ \t]*Namespace[ \t]*$' '' ${tpl[@]+"${tpl[@]}"}

# 5. KEDA owns replicas: no replicas field in the Deployment template.
dep=(deploy/preview/templates/deployment.yaml)
[ -f "${dep[0]}" ] && scan 5 '^[ \t]*replicas:' '' "${dep[@]}"

# 6. No hard-coded environment in workflows.
scan 6 'alleghenycounty\.us|azurecr\.io|svc\.cluster\.local' '' ${wf[@]+"${wf[@]}"}

# 7. Least-privilege tokens: top-level permissions == {id-token: write, contents: read}; no job overrides.
want=$'contents: read\nid-token: write'
for f in ${wf[@]+"${wf[@]}"}; do
  got=$(awk '
    /^permissions:/ { inb = 1; v = $0; sub(/^permissions:[ \t]*/, "", v); if (v != "") print "INLINE " v; next }
    inb && /^[^ \t#]/ { inb = 0 }
    inb && /^[ \t]+[A-Za-z-]+:/ { l = $0; sub(/#.*/, "", l); gsub(/^[ \t]+|[ \t]+$/, "", l); gsub(/:[ \t]+/, ": ", l); print l }
  ' "$f" | sort)
  if [ "$got" != "$want" ]; then
    report "$f:1 -> top-level permissions [$(printf '%s' "$got" | tr '\n' ',')] != [contents: read,id-token: write]" 7
  fi
  nested=$(awk '/^[ \t]+permissions:/ { printf "%s:%d\n", FILENAME, FNR }' "$f")
  for loc in $nested; do report "$loc -> job-level permissions override" 7; done
done

# 8. Bootstrap isolated from workflows.
scan 8 'bootstrap/' '' ${wf[@]+"${wf[@]}"}

# 9. TLS via nginx default cert: no secretName in the chart Ingress.
ing=(deploy/preview/templates/ingress.yaml)
[ -f "${ing[0]}" ] && scan 9 'secretName:' '' "${ing[@]}"

if [ "$violations" -gt 0 ]; then
  log error "$violations violation(s)"
  exit 1
fi
echo clean
log info "clean"
