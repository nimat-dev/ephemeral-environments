#!/usr/bin/env bash
# A2: wildcard A record `*.<DNS_ZONE>` -> Traefik LoadBalancer IP. Replaces a stale IP.
# Usage: bootstrap/a2-wildcard-dns.sh [--apply] [--env FILE]   (default: dry-run)
set -euo pipefail
export SCRIPT_NAME=a2-wildcard-dns
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_common.sh
. "$here/_common.sh"
parse_apply_args "$@"
load_env "$env_file"
require_context

lb_ip=$(kubectl get svc traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
[ -n "$lb_ip" ] || { log error "traefik has no LoadBalancer IP (run a1-ingress.sh --apply)"; exit 1; }

current=$(az network dns record-set a show -g "$AZ_RESOURCE_GROUP" -z "$DNS_ZONE" -n '*' \
  --subscription "$AZ_SUBSCRIPTION_ID" --query 'ARecords[].ipv4Address' -o tsv 2>/dev/null || true)
if [ "$current" = "$lb_ip" ]; then
  log info "skip *.$DNS_ZONE -> $lb_ip (already set)"
else
  for old in $current; do
    run az network dns record-set a remove-record -g "$AZ_RESOURCE_GROUP" -z "$DNS_ZONE" -n '*' \
      --ipv4-address "$old" --keep-empty-record-set --subscription "$AZ_SUBSCRIPTION_ID"
  done
  run az network dns record-set a add-record -g "$AZ_RESOURCE_GROUP" -z "$DNS_ZONE" -n '*' \
    --ipv4-address "$lb_ip" --subscription "$AZ_SUBSCRIPTION_ID"
fi
echo "WILDCARD=*.$DNS_ZONE -> $lb_ip"
log info "done"
