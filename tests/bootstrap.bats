#!/usr/bin/env bats
# F013: bootstrap/provision.sh + teardown.sh against a fake az (no Azure calls).

ROOT="$BATS_TEST_DIRNAME/.."
PROV="$ROOT/bootstrap/provision.sh"
DOWN="$ROOT/bootstrap/teardown.sh"
MUTATING='( create | update | delete | register | get-credentials )'

setup() {
  T="$(mktemp -d)"
  export AZ_LOG="$T/az.log"; : >"$AZ_LOG"
  export PATH="$ROOT/tests/fakes:$PATH"
  ENV="$T/env"
  sed 's/^AZ_SUBSCRIPTION_ID=.*/AZ_SUBSCRIPTION_ID=sub-1/' "$ROOT/bootstrap/.env.example" >"$ENV"
}
teardown() { rm -rf "$T"; }

mutations() { grep -cE "$MUTATING" "$AZ_LOG" || true; }

@test "dry-run: plans all three creates, runs no mutating az call" {
  run "$PROV" --env "$ENV"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] az acr create -n nimatpreviewacr"*"--sku Basic"* ]] || false
  [[ "$output" == *"[dry-run] az aks create"*"--tier free"*"--enable-oidc-issuer --enable-workload-identity"*"--attach-acr nimatpreviewacr"* ]] || false
  [[ "$output" == *"[dry-run] az network dns zone create -n preview.nimat.dev"* ]] || false
  [ "$(mutations)" -eq 0 ]
}

@test "apply: executes creates and fetches credentials" {
  run "$PROV" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  grep -q '^acr create' "$AZ_LOG"
  grep -q '^aks create' "$AZ_LOG"
  grep -q '^network dns zone create' "$AZ_LOG"
  grep -q '^aks get-credentials' "$AZ_LOG"
}

@test "idempotent: everything exists -> nothing created, NS printed" {
  FAKE_EXISTS="acr aks zone" run "$PROV" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  [ "$(grep -cE ' create ' "$AZ_LOG" || true)" -eq 0 ]
  [[ "$output" == *"ns1-01.azure-dns.com."* ]] || false
}

@test "partial failure then retry: existing ACR skipped, AKS retried" {
  FAKE_FAIL="aks create" run "$PROV" --env "$ENV" --apply
  [ "$status" -ne 0 ]
  : >"$AZ_LOG"
  FAKE_EXISTS="acr" run "$PROV" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  [ "$(grep -c '^acr create' "$AZ_LOG" || true)" -eq 0 ]
  grep -q '^aks create' "$AZ_LOG"
}

@test "existing AKS without OIDC/workload identity -> update planned" {
  FAKE_EXISTS="acr aks zone" FAKE_AKS_OIDC=false run "$PROV" --env "$ENV"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] az aks update"*"--enable-oidc-issuer --enable-workload-identity"* ]] || false
}

@test "unregistered provider -> register planned (dry-run), executed (apply)" {
  FAKE_UNREG="Microsoft.ContainerRegistry" run "$PROV" --env "$ENV"
  [[ "$output" == *"[dry-run] az provider register -n Microsoft.ContainerRegistry"* ]] || false
  [ "$(mutations)" -eq 0 ]
  FAKE_UNREG="Microsoft.ContainerRegistry" run "$PROV" --env "$ENV" --apply
  grep -q '^provider register -n Microsoft.ContainerRegistry' "$AZ_LOG"
}

@test "preflight: inaccessible subscription fails before any mutation" {
  FAKE_ACCOUNT_FAIL=1 run "$PROV" --env "$ENV" --apply
  [ "$status" -eq 1 ]; [[ "$output" == *"not accessible"* ]] || false
  [ "$(mutations)" -eq 0 ]
}

@test "preflight: missing resource group fails" {
  FAKE_RG_MISSING=1 run "$PROV" --env "$ENV" --apply
  [ "$status" -eq 1 ]; [[ "$output" == *"resource group"* ]] || false
  [ "$(mutations)" -eq 0 ]
}

@test "preflight: quota below vcpus x (nodes+1) fails" {
  FAKE_LIMIT=3 run "$PROV" --env "$ENV" --apply
  [ "$status" -eq 1 ]; [[ "$output" == *"need 4 vCPU, free 3"* ]] || false
  [ "$(mutations)" -eq 0 ]
}

@test "preflight: quota exactly enough passes" {
  FAKE_LIMIT=4 run "$PROV" --env "$ENV"
  [ "$status" -eq 0 ]
}

@test "preflight: restricted or missing VM size fails" {
  FAKE_RESTRICT=NotAvailableForSubscription run "$PROV" --env "$ENV"
  [ "$status" -eq 1 ]; [[ "$output" == *"restricted"* ]] || false
  FAKE_NO_SKU=1 run "$PROV" --env "$ENV"
  [ "$status" -eq 1 ]; [[ "$output" == *"not offered"* ]] || false
}

@test "config validation: each invalid value exits 2" {
  run "$PROV" --env "$T/missing"; [ "$status" -eq 2 ]
  for bad in 'ACR_NAME=Bad_Name' 'ACR_NAME=abc' 'AKS_NODE_COUNT=0' 'AKS_NODE_COUNT=x' 'DNS_ZONE=nodot' 'AKS_NAME='; do
    key=${bad%%=*}
    sed "s/^$key=.*/$bad/" "$ENV" >"$T/bad"
    run "$PROV" --env "$T/bad"
    [ "$status" -eq 2 ] || { echo "expected exit 2 for $bad, got $status"; false; }
  done
}

@test "unknown argument exits 2" {
  run "$PROV" --bogus; [ "$status" -eq 2 ]
  run "$DOWN" --bogus; [ "$status" -eq 2 ]
}

@test "teardown without --yes deletes nothing" {
  FAKE_EXISTS="acr aks zone" run "$DOWN" --env "$ENV"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] az aks delete"* ]] || false
  [ "$(mutations)" -eq 0 ]
}

@test "teardown --yes deletes AKS, ACR, zone but never the resource group" {
  FAKE_EXISTS="acr aks zone" run "$DOWN" --env "$ENV" --yes
  [ "$status" -eq 0 ]
  grep -q '^aks delete' "$AZ_LOG"; grep -q '^acr delete' "$AZ_LOG"; grep -q '^network dns zone delete' "$AZ_LOG"
  [ "$(grep -c '^group delete' "$AZ_LOG" || true)" -eq 0 ]
}

@test "teardown with nothing present skips all" {
  run "$DOWN" --env "$ENV" --yes
  [ "$status" -eq 0 ]
  [ "$(mutations)" -eq 0 ]
}
