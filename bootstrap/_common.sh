#!/usr/bin/env bash
# Shared helpers for bootstrap scripts: logging, env loading/validation, dry-run runner.

log() { printf '[%s] %s: %s\n' "$1" "${SCRIPT_NAME:-bootstrap}" "$2" >&2; }

# load_env FILE -- source and validate the provisioning config. Exit 2 on invalid config.
load_env() {
  local f="$1" v
  [ -f "$f" ] || { log error "env file not found: $f (copy bootstrap/.env.example)"; exit 2; }
  # shellcheck disable=SC1090
  . "$f"
  for v in AZ_SUBSCRIPTION_ID AZ_RESOURCE_GROUP AZ_LOCATION ACR_NAME AKS_NAME AKS_NODE_SIZE AKS_NODE_COUNT DNS_ZONE; do
    [ -n "${!v:-}" ] || { log error "missing $v in $f"; exit 2; }
  done
  [[ "$ACR_NAME" =~ ^[a-z0-9]{5,50}$ ]] || { log error "ACR_NAME must be 5-50 lowercase alphanumerics: $ACR_NAME"; exit 2; }
  [[ "$AKS_NODE_COUNT" =~ ^[1-9][0-9]*$ ]] || { log error "AKS_NODE_COUNT must be >= 1: $AKS_NODE_COUNT"; exit 2; }
  [[ "$DNS_ZONE" =~ ^([a-z0-9-]+\.)+[a-z]{2,}$ ]] || { log error "DNS_ZONE is not a domain: $DNS_ZONE"; exit 2; }
}

# run CMD... -- execute when APPLY=1, else print as a planned command.
run() {
  if [ "${APPLY:-0}" -eq 1 ]; then
    log info "+ $*"
    "$@"
  else
    printf '[dry-run] %s\n' "$*"
  fi
}
