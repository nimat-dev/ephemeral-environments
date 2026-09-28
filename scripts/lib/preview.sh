#!/usr/bin/env bash
# Pure core for preview environments: identity, durations, expiry.
# Source it; functions print on stdout and return non-zero (with a message on stderr) on
# invalid input. No cluster/cloud calls here (check-architecture rule 1). Sourcing does not
# change the caller's shell options.

PREVIEW_ID_MAX=40
PREVIEW_NEVER_SECONDS=31536000   # "never" idle timeout = 1 year

_preview_err() { printf '[error] preview: %s\n' "$*" >&2; }

# preview_id BRANCH -> RFC 1123 label: lowercase, non-alnum runs -> "-", trimmed, <= 40 chars.
preview_id() {
  local id
  id=$(printf '%s\n' "${1-}" | LC_ALL=C tr '[:upper:]' '[:lower:]' \
    | LC_ALL=C sed -E 's#[^a-z0-9]+#-#g; s#^-+##; s#-+$##' \
    | cut -c1-"$PREVIEW_ID_MAX" | sed -E 's#-+$##')
  if [ -z "$id" ]; then
    _preview_err "empty preview id for branch '${1-}'"
    return 1
  fi
  printf '%s\n' "$id"
}

# preview_namespace ID -> preview-ID
preview_namespace() { printf 'preview-%s\n' "$1"; }

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

# preview_plan BRANCH LIFETIME LIFETIME_CUSTOM IDLE_TIMEOUT MAX_REPLICAS DOMAIN SHORT_SHA [NOW]
# -> key=value lines (preview_id namespace host short_sha idle max_replicas lifetime expires_at),
# ready for $GITHUB_OUTPUT. Validates every input before printing anything.
preview_plan() {
  local id ns host idle maxr lt exp
  [ -n "${6-}" ] || { _preview_err "preview domain is empty"; return 1; }
  case "${7-}" in ''|*[!0-9a-f]*) _preview_err "invalid short sha '${7-}'"; return 1 ;; esac
  id=$(preview_id "${1-}") || return 1
  ns=$(preview_namespace "$id")
  host=$(preview_host "$id" "$6")
  idle=$(idle_seconds "${4-}") || return 1
  maxr=$(max_replicas "${5-}") || return 1
  lt=$(resolve_lifetime "${2-}" "${3-}") || return 1
  exp=$(expires_at "$lt" "${8-}") || return 1
  printf '%s\n' "preview_id=$id" "namespace=$ns" "host=$host" "short_sha=$7" \
    "idle=$idle" "max_replicas=$maxr" "lifetime=$lt" "expires_at=$exp"
}

# namespace_manifest NAMESPACE PREVIEW_ID SHORT_SHA EXPIRES_AT BRANCH -> Namespace JSON carrying
# the label contract (DATA_MODEL.md). BRANCH (raw, untrusted) only lands in an annotation, escaped by jq.
namespace_manifest() {
  jq -n --arg ns "${1-}" --arg id "${2-}" --arg sha "${3-}" --arg exp "${4-}" --arg br "${5-}" '{
    apiVersion: "v1", kind: "Namespace",
    metadata: {
      name: $ns,
      labels: {"managed-by": "preview-bot", "preview.branch": $id, "preview.commit": $sha, "preview.expires-at": $exp},
      annotations: {"preview.branch-original": $br}
    }}'
}

# expired_namespaces NOW < namespace-list.json -> names of preview-bot namespaces whose
# preview.expires-at < NOW. Missing or non-numeric label counts as expired. Only `preview-*`
# names qualify: a stray managed-by label on e.g. `default` never makes it reapable.
expired_namespaces() {
  local now="${1-}"
  case "$now" in ''|*[!0-9]*) _preview_err "invalid now '$now'"; return 1 ;; esac
  jq -r --argjson now "$now" '
    .items[]
    | select(.metadata.labels["managed-by"] == "preview-bot")
    | select(.metadata.name | startswith("preview-"))
    | select(((.metadata.labels["preview.expires-at"] // "0") | tonumber? // 0) < $now)
    | .metadata.name'
}
