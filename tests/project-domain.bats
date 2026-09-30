#!/usr/bin/env bats
# F017: bootstrap/a7-project-domain.sh (extra project domain on the cluster) against fake az/kubectl.

ROOT="$BATS_TEST_DIRNAME/.."
A7="$ROOT/bootstrap/a7-project-domain.sh"

setup() {
  T="$(mktemp -d)"
  export AZ_LOG="$T/az.log" KUBECTL_LOG="$T/kubectl.log" HELM_LOG="$T/helm.log"; : >"$AZ_LOG"; : >"$KUBECTL_LOG"
  export PATH="$ROOT/tests/fakes:$PATH" FAKE_CTX=aks-preview FAKE_LB_IP=20.1.2.3 FAKE_EXISTS=uami
  ENV="$T/env"; sed 's/^AZ_SUBSCRIPTION_ID=.*/AZ_SUBSCRIPTION_ID=sub-1/' "$ROOT/bootstrap/.env.example" >"$ENV"
}
teardown() { rm -rf "$T"; }

apply() { run "$A7" --env "$ENV" --domain shop.preview.nimat.dev --parent-zone preview.nimat.dev --apply "$@"; }

@test "a7 apply: zone, delegation in parent, wildcard, role, issuer + cert, TLSStore entry" {
  apply
  [ "$status" -eq 0 ]
  grep -q '^network dns zone create -g nimatresourceg -n shop.preview.nimat.dev' "$AZ_LOG"
  grep -q '^network dns record-set ns add-record -g nimatresourceg -z preview.nimat.dev -n shop -d ns1-01.azure-dns.com.' "$AZ_LOG"
  grep -q '^network dns record-set ns add-record .* -n shop -d ns2-01.azure-dns.net.' "$AZ_LOG"
  grep -q '^network dns record-set a add-record -g nimatresourceg -z shop.preview.nimat.dev -n \* --ipv4-address 20.1.2.3' "$AZ_LOG"
  grep -q '^role assignment create .*DNS Zone Contributor --scope /subscriptions/sub-1/zone' "$AZ_LOG"
  m="$KUBECTL_LOG.apply"
  grep -q 'name: letsencrypt-dns-shop-preview-nimat-dev' "$m"
  grep -q 'hostedZoneName: shop.preview.nimat.dev' "$m"
  grep -q 'clientID: cid-123' "$m"
  grep -qF 'commonName: "*.shop.preview.nimat.dev"' "$m"
  grep -q 'secretName: wildcard-shop-preview-nimat-dev-tls' "$m"
  grep -q 'wait --for=condition=Ready certificate/wildcard-shop-preview-nimat-dev -n traefik' "$KUBECTL_LOG"
  grep -qF 'patch tlsstore default -n traefik --type merge -p {"spec":{"certificates":[{"secretName":"wildcard-shop-preview-nimat-dev-tls"}]}}' "$KUBECTL_LOG"
  [[ "$output" == *"DOMAIN=shop.preview.nimat.dev WILDCARD=*.shop.preview.nimat.dev -> 20.1.2.3"* ]] || false
}

@test "a7 apply: TLSStore already lists other certs -> append (json patch), never replace the default" {
  FAKE_TLSSTORE_JSON='{"spec":{"defaultCertificate":{"secretName":"wildcard-preview-tls"},"certificates":[{"secretName":"wildcard-a-tls"}]}}' apply
  [ "$status" -eq 0 ]
  grep -qF 'patch tlsstore default -n traefik --type json -p [{"op":"add","path":"/spec/certificates/-","value":{"secretName":"wildcard-shop-preview-nimat-dev-tls"}}]' "$KUBECTL_LOG"
  ! grep -q 'defaultCertificate' "$KUBECTL_LOG"
}

@test "a7 idempotent: zone, NS, A, role, TLSStore entry present -> no mutation but apply/wait" {
  FAKE_EXISTS="uami zone" FAKE_NS_RECORDS="ns1-01.azure-dns.com. ns2-01.azure-dns.net." FAKE_A_IPS=20.1.2.3 FAKE_ROLE_COUNT=1 \
    FAKE_TLSSTORE_JSON='{"spec":{"certificates":[{"secretName":"wildcard-shop-preview-nimat-dev-tls"}]}}' apply
  [ "$status" -eq 0 ]
  [ "$(grep -cE 'zone create|add-record|remove-record|assignment create' "$AZ_LOG" || true)" -eq 0 ]
  ! grep -q 'patch tlsstore' "$KUBECTL_LOG"
}

@test "a7: stale wildcard IP replaced" {
  FAKE_A_IPS=9.9.9.9 apply
  [ "$status" -eq 0 ]
  grep -q 'remove-record .* -z shop.preview.nimat.dev .* --ipv4-address 9.9.9.9' "$AZ_LOG"
}

@test "a7 without --parent-zone: prints NS for the registrar, no delegation record" {
  run "$A7" --env "$ENV" --domain shop.example.org --apply
  [ "$status" -eq 0 ]
  ! grep -q 'record-set ns' "$AZ_LOG"
  [[ "$output" == *"NS shop.example.org -> ns1-01.azure-dns.com."* ]] || false
}

@test "a7 dry-run: plans everything, mutates nothing" {
  run "$A7" --env "$ENV" --domain shop.preview.nimat.dev --parent-zone preview.nimat.dev
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] az network dns zone create"* ]] || false
  [[ "$output" == *"kind: ClusterIssuer"* ]] || false
  [[ "$output" == *"[dry-run] kubectl patch tlsstore default"* ]] || false
  [ "$(grep -cE 'zone create|add-record|assignment create' "$AZ_LOG" || true)" -eq 0 ]
  [ ! -s "$KUBECTL_LOG.apply" ]
}

@test "a7 input errors exit 2 before any cloud call" {
  for a in '' '--domain Shop.Example.org' '--domain -bad.example.org' '--domain nodot' \
           '--domain a.example.org --parent-zone other.org' '--domain a.example.org --parent-zone' '--bogus'; do
    : >"$AZ_LOG"
    # shellcheck disable=SC2086
    run "$A7" --env "$ENV" $a
    [ "$status" -eq 2 ] || { echo "want 2 for '$a', got $status"; return 1; }
    [ ! -s "$AZ_LOG" ]
  done
}

@test "a7: no LB IP / no cert-manager identity / cert never Ready -> fails" {
  FAKE_LB_IP= apply; [ "$status" -eq 1 ]; [[ "$output" == *"no LoadBalancer IP"* ]] || false
  FAKE_EXISTS= apply; [ "$status" -eq 1 ]; [[ "$output" == *"no identity cert-manager-dns"* ]] || false
  FAKE_WAIT_FAIL=1 apply; [ "$status" -ne 0 ]
  ! grep -q 'patch tlsstore' "$KUBECTL_LOG"
}

@test "a7: wrong kube context refuses before any cloud call" {
  FAKE_CTX=other apply
  [ "$status" -eq 1 ]; [ ! -s "$AZ_LOG" ]
}

@test "teardown: deletes PROJECT_DOMAINS zones before the main zone" {
  printf 'PROJECT_DOMAINS="shop.preview.nimat.dev b.example.org"\n' >>"$ENV"
  FAKE_EXISTS=zone run "$ROOT/bootstrap/teardown.sh" --env "$ENV" --yes
  [ "$status" -eq 0 ]
  [ "$(grep '^network dns zone delete' "$AZ_LOG" | awk '{print $6}' | tr '\n' ' ')" = 'shop.preview.nimat.dev b.example.org preview.nimat.dev ' ]
}

@test "a6: PREVIEW_DOMAIN overrides DNS_ZONE for this repo" {
  export GH_LOG="$T/gh.log"; : >"$GH_LOG"
  printf 'PREVIEW_DOMAIN=shop.preview.nimat.dev\n' >>"$ENV"
  FAKE_EXISTS=app FAKE_GH_ADMIN=true run "$ROOT/bootstrap/a6-github-env.sh" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  grep -q 'variable set PREVIEW_DOMAIN --env preview --repo nimat-dev/ephemeral-environments --body shop.preview.nimat.dev' "$GH_LOG"
}
