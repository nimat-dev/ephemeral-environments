#!/usr/bin/env bash
# Shared by the harness hooks (sourced). Batched so large change sets stay inside the 10 s hook timeout.
git() { command git -c core.quotePath=false "$@"; }
# stdin: paths -> stdout: "<content hash>\t<path>" ("-" for a path that is not a regular file, e.g. deleted),
# via ONE git hash-object process.
hash_paths() {
  local list files
  list=$(grep . || true); [ -n "$list" ] || return 0
  files=$(while IFS= read -r p; do if [ -f "$p" ]; then printf '%s\n' "$p"; fi; done <<<"$list")
  while IFS= read -r p; do if [ ! -f "$p" ]; then printf -- '-\t%s\n' "$p"; fi; done <<<"$list"
  [ -n "$files" ] || return 0
  paste <(git hash-object --stdin-paths <<<"$files") <(printf '%s\n' "$files")
}
