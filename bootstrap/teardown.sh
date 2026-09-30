#!/usr/bin/env bash
# Delete what provision.sh created: AKS, ACR, DNS zone (+ PROJECT_DOMAINS zones from a7). Never deletes the resource group.
# Usage: bootstrap/teardown.sh [--yes] [--env FILE]   (without --yes: print only)
# Exit: 0 ok, 1 failure, 2 usage/config error.
set -euo pipefail
export SCRIPT_NAME=teardown
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_common.sh
. "$here/_common.sh"

APPLY=0
env_file="$here/.env"
while [ $# -gt 0 ]; do
  case "$1" in
    --yes) APPLY=1; shift ;;
    --env) [ $# -ge 2 ] || { log error "--env needs a file"; exit 2; }; env_file="$2"; shift 2 ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    *) log error "unknown argument: $1"; exit 2 ;;
  esac
done
load_env "$env_file"
az_s() { az "$@" --subscription "$AZ_SUBSCRIPTION_ID"; }
[ "$APPLY" -eq 1 ] || log warn "print only — pass --yes to delete"

if az_s aks show -n "$AKS_NAME" -g "$AZ_RESOURCE_GROUP" -o none 2>/dev/null; then
  run az aks delete -n "$AKS_NAME" -g "$AZ_RESOURCE_GROUP" --yes --subscription "$AZ_SUBSCRIPTION_ID"
else log info "skip AKS $AKS_NAME (absent)"; fi

if az_s acr show -n "$ACR_NAME" -g "$AZ_RESOURCE_GROUP" -o none 2>/dev/null; then
  run az acr delete -n "$ACR_NAME" -g "$AZ_RESOURCE_GROUP" --yes --subscription "$AZ_SUBSCRIPTION_ID"
else log info "skip ACR $ACR_NAME (absent)"; fi

# Project zones added by a7 (F017) — before DNS_ZONE, which may hold their delegation.
for d in ${PROJECT_DOMAINS:-}; do
  if az_s network dns zone show -n "$d" -g "$AZ_RESOURCE_GROUP" -o none 2>/dev/null; then
    run az network dns zone delete -n "$d" -g "$AZ_RESOURCE_GROUP" --yes --subscription "$AZ_SUBSCRIPTION_ID"
  else log info "skip DNS zone $d (absent)"; fi
done

if az_s network dns zone show -n "$DNS_ZONE" -g "$AZ_RESOURCE_GROUP" -o none 2>/dev/null; then
  run az network dns zone delete -n "$DNS_ZONE" -g "$AZ_RESOURCE_GROUP" --yes --subscription "$AZ_SUBSCRIPTION_ID"
else log info "skip DNS zone $DNS_ZONE (absent)"; fi
log info "done"
