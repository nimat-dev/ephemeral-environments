#!/usr/bin/env bats
# F018: OpenTofu state bootstrap (bootstrap/a0-tofu-state.sh, fake az) + platform/ static contract.
# `tofu validate/test`, tflint and checkov run in scripts/init.sh.

ROOT="$BATS_TEST_DIRNAME/.."
A0="$ROOT/bootstrap/a0-tofu-state.sh"

setup() {
  T="$(mktemp -d)"
  export AZ_LOG="$T/az.log" A0_WAIT=0 A0_TRIES=2; : >"$AZ_LOG"
  export PATH="$ROOT/tests/fakes:$PATH"
  ENV="$T/env"; sed 's/^AZ_SUBSCRIPTION_ID=.*/AZ_SUBSCRIPTION_ID=sub-1/' "$ROOT/bootstrap/.env.example" >"$ENV"
}
teardown() { rm -rf "$T"; }

mutations() { grep -cE ' create | update | register | set-attributes ' "$AZ_LOG" || true; }

@test "a0 dry-run: plans storage, vault, roles, container, key; mutates nothing" {
  run "$A0" --env "$ENV"
  [ "$status" -eq 0 ]
  for s in 'az storage account create -g nimatresourceg -n nimattofustate' '--allow-shared-key-access false' \
           '--allow-blob-public-access false' '--enable-versioning true' \
           'az keyvault create -g nimatresourceg -n nimat-tofu-kv' '--enable-rbac-authorization true' '--enable-purge-protection true' \
           'Storage Blob Data Contributor' 'Key Vault Crypto Officer' 'az storage container create --account-name nimattofustate -n tfstate' \
           'az keyvault key create --vault-name nimat-tofu-kv -n tofu-state --kty RSA --size 3072 --ops encrypt decrypt'; do
    [[ "$output" == *"$s"* ]] || { echo "missing: $s"; return 1; }
  done
  [ "$(mutations)" -eq 0 ]
}

@test "a0 apply: creates everything missing, grants the signed-in operator" {
  run "$A0" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  grep -q '^storage account create -g nimatresourceg -n nimattofustate' "$AZ_LOG"
  grep -q '^keyvault create -g nimatresourceg -n nimat-tofu-kv' "$AZ_LOG"
  grep -q '^role assignment create --assignee-object-id me-oid --assignee-principal-type User --role Storage Blob Data Contributor' "$AZ_LOG"
  grep -q '^role assignment create --assignee-object-id me-oid .*--role Key Vault Crypto Officer' "$AZ_LOG"
  grep -q '^storage container create --account-name nimattofustate -n tfstate --auth-mode login' "$AZ_LOG"
  grep -q '^keyvault key create --vault-name nimat-tofu-kv -n tofu-state --kty RSA --size 3072 --ops encrypt decrypt' "$AZ_LOG"
  [[ "$output" == *"STATE=nimattofustate/tfstate KEY=https://nimat-tofu-kv.vault.azure.net/keys/tofu-state"* ]] || false
}

@test "a0 idempotent: everything present -> no mutation" {
  FAKE_EXISTS="sa versioning kv kvkey container" FAKE_ROLE_COUNT=1 run "$A0" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  [ "$(mutations)" -eq 0 ]
}

@test "a0: existing key without encrypt/decrypt -> ops fixed, not recreated" {
  FAKE_EXISTS="sa versioning kv kvkey container" FAKE_ROLE_COUNT=1 FAKE_KEY_OPS=unwrapKey,wrapKey run "$A0" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  grep -q '^keyvault key set-attributes --vault-name nimat-tofu-kv -n tofu-state --ops encrypt decrypt' "$AZ_LOG"
  ! grep -q '^keyvault key create' "$AZ_LOG"
}

@test "a0: unregistered KeyVault provider is registered first" {
  FAKE_UNREG=Microsoft.KeyVault run "$A0" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  grep -q '^provider register -n Microsoft.KeyVault --wait' "$AZ_LOG"
}

@test "a0: container/key never creatable (RBAC not effective) -> exit 1 after retries" {
  FAKE_EXISTS="sa versioning kv" FAKE_ROLE_COUNT=1 FAKE_FAIL='storage container create' run "$A0" --env "$ENV" --apply
  [ "$status" -eq 1 ]; [[ "$output" == *"cannot create container tfstate"* ]] || false
  [ "$(grep -c '^storage container create' "$AZ_LOG")" -eq 2 ]
}

@test "a0: invalid names -> exit 2 before any call" {
  for kv in 'TOFU_STATE_SA=Bad_Name' 'TOFU_STATE_SA=' 'TOFU_STATE_KV=1vault' 'TOFU_STATE_KV=v'; do
    : >"$AZ_LOG"; cp "$ENV" "$T/e2"; printf '%s\n' "$kv" >>"$T/e2"
    run "$A0" --env "$T/e2"
    [ "$status" -eq 2 ] || { echo "want 2 for $kv, got $status"; return 1; }
    [ ! -s "$AZ_LOG" ]
  done
}

# --- platform/ static contract ---
@test "envs/nimat: remote state is Entra-authenticated and encryption is enforced for state and plans" {
  f="$ROOT/platform/envs/nimat/versions.tf"
  grep -q 'use_azuread_auth     = true' "$f"
  grep -q 'key_provider "azure_vault" "state"' "$f"
  [ "$(grep -c 'enforced = true' "$f")" -eq 2 ]
}

@test "team-cluster: kubelet pulls from the ACR; RG is data-only (never created or deleted)" {
  m="$ROOT/platform/modules/team-cluster/main.tf"
  awk '/resource "azurerm_role_assignment" "kubelet_acr_pull"/,/^}/' "$m" | grep -q 'role_definition_name = "AcrPull"'
  awk '/resource "azurerm_role_assignment" "kubelet_acr_pull"/,/^}/' "$m" | grep -q 'kubelet_identity\[0\].object_id'
  grep -q '^data "azurerm_resource_group" "this"' "$m"
  ! grep -q 'resource "azurerm_resource_group"' "$m"
}

@test "checkov skips are all justified inline" {
  run awk '/^  - CKV_/ && !/#/' "$ROOT/platform/.checkov.yaml"
  [ -z "$output" ]
}
