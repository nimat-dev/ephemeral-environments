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

# expired_namespaces NOW < namespace-list.json -> names of preview-bot namespaces whose
# preview.expires-at < NOW. Missing or non-numeric label counts as expired.
expired_namespaces() {
  local now="${1-}"
  case "$now" in ''|*[!0-9]*) _preview_err "invalid now '$now'"; return 1 ;; esac
  jq -r --argjson now "$now" '
    .items[]
    | select(.metadata.labels["managed-by"] == "preview-bot")
    | select(((.metadata.labels["preview.expires-at"] // "0") | tonumber? // 0) < $now)
    | .metadata.name'
}
