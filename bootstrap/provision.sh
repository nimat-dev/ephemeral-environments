#!/usr/bin/env bash
# Provision spec prerequisites (F013): Basic ACR, AKS (OIDC + workload identity), Azure DNS zone.
# Usage: bootstrap/provision.sh [--apply] [--env FILE]
#   default is a dry-run: read-only checks run, mutating commands are only printed.
# Exit: 0 ok, 1 preflight/apply failure, 2 usage/config error.
set -euo pipefail
export SCRIPT_NAME=provision
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_common.sh
. "$here/_common.sh"

APPLY=0
env_file="$here/.env"
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --env) [ $# -ge 2 ] || { log error "--env needs a file"; exit 2; }; env_file="$2"; shift 2 ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) log error "unknown argument: $1"; exit 2 ;;
  esac
done
load_env "$env_file"
az_s() { az "$@" --subscription "$AZ_SUBSCRIPTION_ID"; }
log info "mode=$([ "$APPLY" -eq 1 ] && echo APPLY || echo dry-run) sub=$AZ_SUBSCRIPTION_ID rg=$AZ_RESOURCE_GROUP"

# ---- preflight (read-only) ----
az account show --subscription "$AZ_SUBSCRIPTION_ID" -o none 2>/dev/null \
  || { log error "subscription $AZ_SUBSCRIPTION_ID not accessible (az login?)"; exit 1; }
az_s group show -n "$AZ_RESOURCE_GROUP" -o none 2>/dev/null \
  || { log error "resource group $AZ_RESOURCE_GROUP not found (never created by this script)"; exit 1; }

for p in Microsoft.ContainerService Microsoft.ContainerRegistry Microsoft.Network Microsoft.Compute Microsoft.KubernetesConfiguration; do
  state=$(az_s provider show -n "$p" --query registrationState -o tsv 2>/dev/null || echo Unknown)
  if [ "$state" = Registered ]; then log info "provider $p Registered"
  else log warn "provider $p is $state"; run az provider register -n "$p" --wait --subscription "$AZ_SUBSCRIPTION_ID"; fi
done

# check_capacity -- VM size offered + vCPU quota for nodes + 1 surge. Only needed when creating AKS
# (an existing node already consumes quota, so re-checking would fail every re-run).
check_capacity() {
  local sku restricted family vcpus need usage q free
  sku=$(az_s vm list-skus -l "$AZ_LOCATION" --resource-type virtualMachines --size "$AKS_NODE_SIZE" -o json 2>/dev/null \
    | jq -c --arg n "$AKS_NODE_SIZE" '[.[] | select(.name == $n)][0] // empty')
  [ -n "$sku" ] || { log error "VM size $AKS_NODE_SIZE not offered in $AZ_LOCATION"; exit 1; }
  restricted=$(jq -r '[.restrictions[]?.reasonCode] | join(",")' <<<"$sku")
  [ -z "$restricted" ] || { log error "VM size $AKS_NODE_SIZE restricted: $restricted"; exit 1; }
  family=$(jq -r '.family' <<<"$sku")
  vcpus=$(jq -r '[.capabilities[] | select(.name == "vCPUs") | .value][0]' <<<"$sku")
  need=$(( vcpus * (AKS_NODE_COUNT + 1) ))   # +1 surge node during upgrades
  usage=$(az_s vm list-usage -l "$AZ_LOCATION" -o json 2>/dev/null)
  for q in "$family" cores; do
    free=$(jq -r --arg q "$q" '[.[] | select(.name.value == $q) | ((.limit | tonumber) - (.currentValue | tonumber))][0] // -1' <<<"$usage")
    [ "$free" -ge "$need" ] || { log error "quota $q: need $need vCPU, free $free"; exit 1; }
    log info "quota $q: need $need vCPU, free $free"
  done
}

aks=$(az_s aks show -n "$AKS_NAME" -g "$AZ_RESOURCE_GROUP" -o json 2>/dev/null || true)
[ -n "$aks" ] || check_capacity   # before any mutation: no half-built state on a quota failure

# ---- resources (idempotent) ----
if az_s acr show -n "$ACR_NAME" -g "$AZ_RESOURCE_GROUP" -o none 2>/dev/null; then
  log info "skip ACR $ACR_NAME (exists)"
else
  run az acr create -n "$ACR_NAME" -g "$AZ_RESOURCE_GROUP" -l "$AZ_LOCATION" --sku Basic --subscription "$AZ_SUBSCRIPTION_ID"
fi

if [ -n "$aks" ]; then
  log info "skip AKS $AKS_NAME (exists)"
  oidc=$(jq -r '.oidcIssuerProfile.enabled // false' <<<"$aks")
  wi=$(jq -r '.securityProfile.workloadIdentity.enabled // false' <<<"$aks")
  if [ "$oidc" != true ] || [ "$wi" != true ]; then
    run az aks update -n "$AKS_NAME" -g "$AZ_RESOURCE_GROUP" --enable-oidc-issuer --enable-workload-identity --subscription "$AZ_SUBSCRIPTION_ID"
  fi
else
  run az aks create -n "$AKS_NAME" -g "$AZ_RESOURCE_GROUP" -l "$AZ_LOCATION" \
    --tier free --node-count "$AKS_NODE_COUNT" --node-vm-size "$AKS_NODE_SIZE" \
    --enable-oidc-issuer --enable-workload-identity --enable-managed-identity \
    --attach-acr "$ACR_NAME" --generate-ssh-keys --subscription "$AZ_SUBSCRIPTION_ID"
fi

if az_s network dns zone show -n "$DNS_ZONE" -g "$AZ_RESOURCE_GROUP" -o none 2>/dev/null; then
  log info "skip DNS zone $DNS_ZONE (exists)"
else
  run az network dns zone create -n "$DNS_ZONE" -g "$AZ_RESOURCE_GROUP" --subscription "$AZ_SUBSCRIPTION_ID"
fi

# ---- outputs ----
if [ "$APPLY" -eq 1 ]; then
  run az aks get-credentials -n "$AKS_NAME" -g "$AZ_RESOURCE_GROUP" --overwrite-existing --subscription "$AZ_SUBSCRIPTION_ID"
fi
ns=$(az_s network dns zone show -n "$DNS_ZONE" -g "$AZ_RESOURCE_GROUP" --query nameServers -o tsv 2>/dev/null || true)
if [ -n "$ns" ]; then
  echo "Add these NS records in Namecheap (host: ${DNS_ZONE%%.*}):"
  printf '%s\n' "$ns" | sed 's/^/  /'
else
  echo "NS servers: available after --apply creates $DNS_ZONE"
fi
log info "done"
