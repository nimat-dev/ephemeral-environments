#!/usr/bin/env bash
# Pure core for preview environments: identity, durations, expiry.
# Source it; functions print on stdout and return non-zero (with a message on stderr) on
# invalid input. No cluster/cloud calls here (check-architecture rule 1). Sourcing does not
# change the caller's shell options.

PREVIEW_ID_MAX=40
PREVIEW_APP_MAX=20
PREVIEW_NS_MAX=63                # RFC 1123 label
PREVIEW_NEVER_SECONDS=31536000   # "never" idle timeout = 1 year

_preview_err() { printf '[error] preview: %s\n' "$*" >&2; }

# _preview_slug STR MAX -> lowercase, non-alnum runs -> "-", trimmed, <= MAX chars (may be empty)
_preview_slug() {
  printf '%s\n' "${1-}" | LC_ALL=C tr '[:upper:]' '[:lower:]' \
    | LC_ALL=C sed -E 's#[^a-z0-9]+#-#g; s#^-+##; s#-+$##' \
    | cut -c1-"$2" | sed -E 's#-+$##'
}

# preview_id BRANCH -> RFC 1123 label: lowercase, non-alnum runs -> "-", trimmed, <= 40 chars.
preview_id() {
  local id
  id=$(_preview_slug "${1-}" "$PREVIEW_ID_MAX")
  if [ -z "$id" ]; then
    _preview_err "empty preview id for branch '${1-}'"
    return 1
  fi
  printf '%s\n' "$id"
}

# preview_app APP OWNER/REPO -> app slug (<= 20): APP (repo var PREVIEW_APP) when it has any
# alphanumerics, else the repo name. Namespaces of different repos differ by it (F015).
preview_app() {
  local app
  app=$(_preview_slug "${1-}" "$PREVIEW_APP_MAX")
  [ -n "$app" ] || app=$(_preview_slug "${2##*/}" "$PREVIEW_APP_MAX")
  [ -n "$app" ] || { _preview_err "empty app (PREVIEW_APP='${1-}', repo='${2-}')"; return 1; }
  printf '%s\n' "$app"
}

# preview_repo_label OWNER/REPO -> `preview.repo` label value (slug, <= 63): who owns a preview ns
preview_repo_label() {
  local l
  case "${1-}" in */?*) ;; *) _preview_err "repo must be owner/repo: '${1-}'"; return 1 ;; esac
  l=$(_preview_slug "$1" 63)
  [ -n "$l" ] || { _preview_err "empty repo label for '$1'"; return 1; }
  printf '%s\n' "$l"
}

# preview_namespace APP ID -> preview-APP-ID; over 63 chars -> first 54 chars (trailing "-" trimmed)
# + "-" + 8-hex POSIX cksum of the full name, so truncated names stay distinct and stable.
preview_namespace() {
  local ns="preview-$1-$2" h
  if [ "${#ns}" -gt "$PREVIEW_NS_MAX" ]; then
    h=$(printf '%s' "$ns" | cksum | awk '{printf "%08x", $1}')
    ns="$(printf '%s' "$ns" | cut -c1-$((PREVIEW_NS_MAX - 9)) | sed -E 's#-+$##')-$h"
  fi
  printf '%s\n' "$ns"
}

# preview_owns REPO_LABEL < namespace.json -> exit 0 when this repo owns the namespace:
# managed-by=preview-bot AND (preview.repo == REPO_LABEL, or no preview.repo label = legacy pre-F015)
preview_owns() {
  [ -n "${1-}" ] || { _preview_err "repo label required"; return 1; }
  jq -e --arg repo "$1" '
    .metadata.labels as $l | ($l["managed-by"] == "preview-bot")
    and (($l | has("preview.repo") | not) or $l["preview.repo"] == $repo)' >/dev/null
}

# preview_host ID DOMAIN -> ID.DOMAIN
preview_host() { printf '%s.%s\n' "$1" "$2"; }

# to_seconds Nm|Nh|Nd -> seconds
to_seconds() {
  local v="${1-}" n u
  case "$v" in
    ''|*[!0-9mhd]*) _preview_err "invalid duration '$v' (want Nm, Nh or Nd)"; return 1 ;;
  esac
  n="${v%?}"; u="${v#"$n"}"
  case "$n" in ''|*[!0-9]*) _preview_err "invalid duration '$v' (want Nm, Nh or Nd)"; return 1 ;; esac
  n=$((10#$n))   # force base 10: "08h" is 8, not invalid octal
  case "$u" in
    m) printf '%s\n' $((n * 60)) ;;
    h) printf '%s\n' $((n * 3600)) ;;
    d) printf '%s\n' $((n * 86400)) ;;
    *) _preview_err "invalid duration '$v' (want Nm, Nh or Nd)"; return 1 ;;
  esac
}

# idle_seconds never|Nm|Nh|Nd -> seconds
idle_seconds() {
  if [ "${1-}" = never ]; then printf '%s\n' "$PREVIEW_NEVER_SECONDS"; else to_seconds "${1-}"; fi
}

# resolve_lifetime LIFETIME CUSTOM -> LIFETIME, or CUSTOM when LIFETIME=custom
resolve_lifetime() {
  if [ "${1-}" = custom ]; then
    if [ -z "${2-}" ]; then _preview_err "lifetime=custom but lifetime_custom is empty"; return 1; fi
    printf '%s\n' "$2"
  else
    printf '%s\n' "${1-}"
  fi
}

# expires_at LIFETIME [NOW] -> epoch seconds (NOW defaults to current UTC epoch)
expires_at() {
  local secs now
  secs=$(to_seconds "${1-}") || return 1
  if [ "$secs" -le 0 ]; then _preview_err "lifetime must be > 0 (got '${1-}')"; return 1; fi
  now="${2:-$(date -u +%s)}"
  case "$now" in ''|*[!0-9]*) _preview_err "invalid now '$now'"; return 1 ;; esac
  printf '%s\n' $((now + secs))
}

# max_replicas N -> N when an integer 1..PREVIEW_MAX_REPLICAS_CAP (= chart quota.pods: more
# replicas could never schedule inside the namespace ResourceQuota)
PREVIEW_MAX_REPLICAS_CAP=6
max_replicas() {
  local v="${1-}"
  case "$v" in ''|*[!0-9]*|?????*) _preview_err "invalid max_replicas '$v' (want integer 1..$PREVIEW_MAX_REPLICAS_CAP)"; return 1 ;; esac
  v=$((10#$v))   # <= 4 digits: no overflow
  if [ "$v" -lt 1 ] || [ "$v" -gt "$PREVIEW_MAX_REPLICAS_CAP" ]; then
    _preview_err "invalid max_replicas '${1}' (want integer 1..$PREVIEW_MAX_REPLICAS_CAP)"; return 1
  fi
  printf '%s\n' "$v"
}

# preview_plan APP BRANCH LIFETIME LIFETIME_CUSTOM IDLE_TIMEOUT MAX_REPLICAS DOMAIN SHORT_SHA [NOW]
# -> key=value lines (app preview_id namespace host short_sha idle max_replicas lifetime expires_at),
# ready for $GITHUB_OUTPUT. APP is an already-resolved preview_app slug. Validates every input
# before printing anything.
preview_plan() {
  local app="${1-}" id ns host idle maxr lt exp
  shift
  [[ "$app" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || { _preview_err "invalid app '$app'"; return 1; }
  [ -n "${6-}" ] || { _preview_err "preview domain is empty"; return 1; }
  case "${7-}" in ''|*[!0-9a-f]*) _preview_err "invalid short sha '${7-}'"; return 1 ;; esac
  id=$(preview_id "${1-}") || return 1
  ns=$(preview_namespace "$app" "$id")
  host=$(preview_host "$id" "$6")
  idle=$(idle_seconds "${4-}") || return 1
  maxr=$(max_replicas "${5-}") || return 1
  lt=$(resolve_lifetime "${2-}" "${3-}") || return 1
  exp=$(expires_at "$lt" "${8-}") || return 1
  printf '%s\n' "app=$app" "preview_id=$id" "namespace=$ns" "host=$host" "short_sha=$7" \
    "idle=$idle" "max_replicas=$maxr" "lifetime=$lt" "expires_at=$exp"
}

# namespace_manifest NAMESPACE PREVIEW_ID SHORT_SHA EXPIRES_AT BRANCH APP OWNER/REPO -> Namespace JSON
# carrying the label contract (DATA_MODEL.md). BRANCH and OWNER/REPO (raw) only land in annotations,
# escaped by jq; `preview.repo` (ownership, F015) is their slug.
namespace_manifest() {
  local repo
  repo=$(preview_repo_label "${7-}") || return 1
  jq -n --arg ns "${1-}" --arg id "${2-}" --arg sha "${3-}" --arg exp "${4-}" --arg br "${5-}" \
    --arg app "${6-}" --arg repo "$repo" --arg repo_raw "$7" '{
    apiVersion: "v1", kind: "Namespace",
    metadata: {
      name: $ns,
      labels: {"managed-by": "preview-bot", "preview.branch": $id, "preview.commit": $sha, "preview.expires-at": $exp,
               "preview.app": $app, "preview.repo": $repo},
      annotations: {"preview.branch-original": $br, "preview.repo-original": $repo_raw}
    }}'
}

# expired_namespaces NOW REPO_LABEL < namespace-list.json -> names of preview-bot namespaces owned by
# REPO_LABEL (see preview_owns; legacy unlabeled ones included) whose preview.expires-at < NOW. Missing
# or non-numeric label counts as expired. Only `preview-*` names qualify: a stray managed-by label on
# e.g. `default` never makes it reapable.
expired_namespaces() {
  local now="${1-}"
  case "$now" in ''|*[!0-9]*) _preview_err "invalid now '$now'"; return 1 ;; esac
  [ -n "${2-}" ] || { _preview_err "repo label required"; return 1; }
  jq -r --argjson now "$now" --arg repo "$2" '
    .items[]
    | select(.metadata.labels["managed-by"] == "preview-bot")
    | select((.metadata.labels | has("preview.repo") | not) or .metadata.labels["preview.repo"] == $repo)
    | select(.metadata.name | startswith("preview-"))
    | select(((.metadata.labels["preview.expires-at"] // "0") | tonumber? // 0) < $now)
    | .metadata.name'
}

# preview_commits < namespace-list.json -> `preview.commit` label of each preview-bot `preview-*`
# namespace, one per line (the image tags live previews run).
preview_commits() {
  jq -r '.items[]
    | select(.metadata.labels["managed-by"] == "preview-bot")
    | select(.metadata.name | startswith("preview-"))
    | .metadata.labels["preview.commit"] // empty'
}

# image_tags_in_use IMAGE_NAME < deployments+pods-list.json -> tags of IMAGE_NAME referenced by
# Deployment templates or pods (incl. an old ReplicaSet's pods after a failed upgrade) in `preview-*`
# namespaces, one per line.
image_tags_in_use() {
  local name="${1-}"
  [ -n "$name" ] || { _preview_err "image name required"; return 1; }
  jq -r --arg name "$name" '
    .items[]
    | select(.metadata.namespace // "" | startswith("preview-"))
    | (.spec.template.spec // .spec) | ((.containers // []) + (.initContainers // []))[] | .image
    | sub("@sha256:[0-9a-f]+$"; "")
    | select(test("(^|/)" + $name + ":[^/:@]+$"))
    | sub(".*:"; "")' | sort -u
}

# iso_epoch ISO8601 -> epoch seconds (fractional seconds dropped)
iso_epoch() {
  jq -nr --arg t "${1-}" '$t | sub("\\.[0-9]+"; "") | fromdateiso8601' 2>/dev/null ||
    { _preview_err "invalid timestamp '${1-}'"; return 1; }
}

# purge_tags NOW MAX_AGE_SECONDS KEEP [IN_USE...] < show-tags-detail.json -> tags to delete, one per
# manifest. Only short-sha tags (7-40 hex) qualify; never one IN_USE by a live preview, never the KEEP
# newest sha tags, never a delete-locked tag; only tags last updated before NOW - MAX_AGE. Deleting a
# tag deletes its manifest and every tag on it, so a candidate whose digest any protected tag shares is
# skipped, and each digest is emitted once.
purge_tags() {
  local now="${1-}" age="${2-}" keep="${3-}"
  case "$now" in ''|*[!0-9]*) _preview_err "invalid now '$now'"; return 1 ;; esac
  case "$age" in ''|*[!0-9]*) _preview_err "invalid max age '$age'"; return 1 ;; esac
  case "$keep" in ''|*[!0-9]*) _preview_err "invalid keep '$keep'"; return 1 ;; esac
  shift 3
  jq -r --argjson now "$now" --argjson age "$age" --argjson keep "$keep" \
    --argjson inuse "$(printf '%s\n' "$@" | jq -R 'select(length > 0)' | jq -s .)" '
    [ .[] | .ts = (.lastUpdateTime | sub("\\.[0-9]+"; "") | fromdateiso8601) ] as $all
    | ([ $all[] | select(.name | test("^[0-9a-f]{7,40}$")) ] | sort_by(.ts) | reverse | .[:$keep] | map(.name)) as $newest
    | [ $all[] | .victim = (
          (.name | test("^[0-9a-f]{7,40}$"))
          and (.ts < $now - $age)
          and (.changeableAttributes.deleteEnabled != false)
          and (.name as $n | ($inuse | index($n) | not) and ($newest | index($n) | not))) ] as $tagged
    | ([ $tagged[] | select(.victim | not) | .digest // empty ]) as $protected
    | [ $tagged[] | select(.victim) | select((.digest // "") as $d | $d == "" or ($protected | index($d) | not)) ]
    | sort_by(.ts) | reverse | unique_by(.digest // .name) | sort_by(.ts) | reverse | .[].name'
}
