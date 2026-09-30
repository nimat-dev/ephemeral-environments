#!/usr/bin/env bash
# A0: OpenTofu remote state for platform/ (F018, DEC-038): storage account (Entra-only auth, blob
# versioning, TLS 1.2, no public blobs) + container, and a Key Vault (RBAC, purge protection) holding
# the RSA key that encrypts state client-side. Grants the signed-in operator blob + key rights. Idempotent.
# Usage: bootstrap/a0-tofu-state.sh [--apply] [--env FILE]   (default: dry-run)
set -euo pipefail
export SCRIPT_NAME=a0-tofu-state
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_common.sh
. "$here/_common.sh"
parse_apply_args "$@"
load_env "$env_file"

SA="${TOFU_STATE_SA:-}" KV="${TOFU_STATE_KV:-}" CONTAINER=tfstate KEY=tofu-state
[[ "$SA" =~ ^[a-z0-9]{3,24}$ ]] || { log error "TOFU_STATE_SA must be 3-24 lowercase alphanumerics: '$SA'"; exit 2; }
[[ "$KV" =~ ^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$ ]] || { log error "TOFU_STATE_KV must be a valid vault name (3-24): '$KV'"; exit 2; }
az_s() { az "$@" --subscription "$AZ_SUBSCRIPTION_ID"; }

me=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || true)
[ -n "$me" ] || { log error "cannot read the signed-in user (az login)"; exit 1; }

for ns in Microsoft.Storage Microsoft.KeyVault; do
  state=$(az_s provider show -n "$ns" --query registrationState -o tsv 2>/dev/null || echo NotRegistered)
  if [ "$state" = Registered ]; then log info "skip provider $ns (registered)"
  else run az provider register -n "$ns" --wait --subscription "$AZ_SUBSCRIPTION_ID"; fi
done

if az_s storage account show -g "$AZ_RESOURCE_GROUP" -n "$SA" -o none 2>/dev/null; then log info "skip storage account $SA (exists)"
else
  run az storage account create -g "$AZ_RESOURCE_GROUP" -n "$SA" -l "$AZ_LOCATION" --sku Standard_LRS --kind StorageV2 \
    --min-tls-version TLS1_2 --allow-blob-public-access false --allow-shared-key-access false --https-only true \
    --subscription "$AZ_SUBSCRIPTION_ID"
fi
if [ "$(az_s storage account blob-service-properties show -g "$AZ_RESOURCE_GROUP" -n "$SA" --query isVersioningEnabled -o tsv 2>/dev/null)" = true ]; then
  log info "skip blob versioning (enabled)"
else
  run az storage account blob-service-properties update -g "$AZ_RESOURCE_GROUP" -n "$SA" --enable-versioning true \
    --subscription "$AZ_SUBSCRIPTION_ID"
fi

if az_s keyvault show -g "$AZ_RESOURCE_GROUP" -n "$KV" -o none 2>/dev/null; then log info "skip key vault $KV (exists)"
else
  run az keyvault create -g "$AZ_RESOURCE_GROUP" -n "$KV" -l "$AZ_LOCATION" --enable-rbac-authorization true \
    --enable-purge-protection true --retention-days 7 --subscription "$AZ_SUBSCRIPTION_ID"
fi

# grant ROLE SCOPE_ID -- idempotent role assignment to the operator
grant() {
  local n
  n=$(az_s role assignment list --assignee "$me" --scope "$2" --role "$1" --query 'length(@)' -o tsv 2>/dev/null || echo 0)
  if [ "${n:-0}" -ge 1 ]; then log info "skip role $1 (assigned)"
  else run az role assignment create --assignee-object-id "$me" --assignee-principal-type User --role "$1" --scope "$2" \
    --subscription "$AZ_SUBSCRIPTION_ID"; fi
}
sa_id=$(az_s storage account show -g "$AZ_RESOURCE_GROUP" -n "$SA" --query id -o tsv 2>/dev/null || echo "<sa-id>")
kv_id=$(az_s keyvault show -g "$AZ_RESOURCE_GROUP" -n "$KV" --query id -o tsv 2>/dev/null || echo "<kv-id>")
grant "Storage Blob Data Contributor" "$sa_id"
grant "Key Vault Crypto Officer" "$kv_id"

# RBAC can take a minute to reach the data plane: retry data-plane calls.
retry() { local _; for _ in $(seq 1 "${A0_TRIES:-12}"); do "$@" && return 0; sleep "${A0_WAIT:-10}"; done; return 1; }
if [ "$APPLY" -eq 1 ]; then
  if az_s storage container show --account-name "$SA" -n "$CONTAINER" --auth-mode login -o none 2>/dev/null; then
    log info "skip container $CONTAINER (exists)"
  else
    retry az storage container create --account-name "$SA" -n "$CONTAINER" --auth-mode login -o none \
      --subscription "$AZ_SUBSCRIPTION_ID" || { log error "cannot create container $CONTAINER (RBAC not effective?)"; exit 1; }
  fi
  # OpenTofu's azure_vault key provider calls encrypt/decrypt (RSA-OAEP-256) on the key.
  # shellcheck disable=SC2016 # JMESPath backtick literal, not shell
  ops=$(az_s keyvault key show --vault-name "$KV" -n "$KEY" --query 'join(`,`, sort(key.keyOps))' -o tsv 2>/dev/null || true)
  if [ "$ops" = "decrypt,encrypt" ]; then log info "skip key $KEY (exists, ops $ops)"
  elif [ -n "$ops" ]; then
    run az keyvault key set-attributes --vault-name "$KV" -n "$KEY" --ops encrypt decrypt -o none --subscription "$AZ_SUBSCRIPTION_ID"
  else
    retry az keyvault key create --vault-name "$KV" -n "$KEY" --kty RSA --size 3072 --ops encrypt decrypt -o none \
      --subscription "$AZ_SUBSCRIPTION_ID" || { log error "cannot create key $KEY (RBAC not effective?)"; exit 1; }
  fi
else
  echo "[dry-run] az storage container create --account-name $SA -n $CONTAINER --auth-mode login"
  echo "[dry-run] az keyvault key create --vault-name $KV -n $KEY --kty RSA --size 3072 --ops encrypt decrypt"
fi
echo "STATE=$SA/$CONTAINER KEY=https://$KV.vault.azure.net/keys/$KEY"
log info "done"
