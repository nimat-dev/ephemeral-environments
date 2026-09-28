#!/usr/bin/env bats
# F004: in-cluster bootstrap scripts (A1 Traefik, A4 KEDA) against fake helm/kubectl.

ROOT="$BATS_TEST_DIRNAME/.."
A1="$ROOT/bootstrap/a1-ingress.sh"
A4="$ROOT/bootstrap/a4-keda.sh"

setup() {
  T="$(mktemp -d)"
  export HELM_LOG="$T/helm.log" KUBECTL_LOG="$T/kubectl.log"; : >"$HELM_LOG"; : >"$KUBECTL_LOG"
  export PATH="$ROOT/tests/fakes:$PATH" FAKE_CTX=aks-preview LB_WAIT_SECONDS=0 LB_WAIT_TRIES=2
  ENV="$T/env"; sed 's/^AZ_SUBSCRIPTION_ID=.*/AZ_SUBSCRIPTION_ID=sub-1/' "$ROOT/bootstrap/.env.example" >"$ENV"
}
teardown() { rm -rf "$T"; }

helm_calls() { grep -c . "$HELM_LOG" || true; }

@test "A1 dry-run: plans pinned traefik install, calls no helm" {
  run "$A1" --env "$ENV"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] helm upgrade --install traefik traefik/traefik -n traefik --create-namespace --version 41.6.0"* ]] || false
  [[ "$output" == *"values/traefik.yaml"* ]] || false
  [ "$(helm_calls)" -eq 0 ]
}

@test "A1 apply: installs and prints LB IP" {
  FAKE_LB_IP=20.1.2.3 run "$A1" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  grep -q '^upgrade --install traefik traefik/traefik' "$HELM_LOG"
  [[ "$output" == *"LB_IP=20.1.2.3"* ]] || false
}

@test "A1 apply: no LB IP within timeout fails" {
  FAKE_LB_IP= run "$A1" --env "$ENV" --apply
  [ "$status" -eq 1 ]; [[ "$output" == *"no LoadBalancer IP"* ]] || false
}

@test "wrong kube context refuses before any helm call" {
  FAKE_CTX=some-other-cluster run "$A1" --env "$ENV" --apply
  [ "$status" -eq 1 ]; [[ "$output" == *"expected 'aks-preview'"* ]] || false
  FAKE_CTX= run "$A4" --env "$ENV" --apply
  [ "$status" -eq 1 ]
  [ "$(helm_calls)" -eq 0 ]
}

@test "A4 dry-run: plans keda + http add-on at pinned versions" {
  run "$A4" --env "$ENV"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] helm upgrade --install keda kedacore/keda -n keda --create-namespace --version 2.21.0"* ]] || false
  [[ "$output" == *"[dry-run] helm upgrade --install http-add-on kedacore/keda-add-ons-http -n keda --version 0.16.0 -f "*"values/keda-http.yaml"* ]] || false
  [ "$(helm_calls)" -eq 0 ]
}

@test "A4 apply: verifies interceptor proxy service and port" {
  FAKE_ICP_PORT=8080 run "$A4" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"INTERCEPTOR_FQDN=keda-add-ons-http-interceptor-proxy.keda.svc.cluster.local"* ]] || false
  [[ "$output" == *"INTERCEPTOR_PORT=8080"* ]] || false
}

@test "A4 apply: interceptor missing or on another port fails" {
  FAKE_ICP_PORT= run "$A4" --env "$ENV" --apply
  [ "$status" -eq 1 ]; [[ "$output" == *"missing"* ]] || false
  FAKE_ICP_PORT=9091 run "$A4" --env "$ENV" --apply
  [ "$status" -eq 1 ]; [[ "$output" == *"9091"* ]] || false
}

@test "helm failure mid-way exits non-zero; re-run converges" {
  FAKE_HELM_FAIL="http-add-on" FAKE_ICP_PORT=8080 run "$A4" --env "$ENV" --apply
  [ "$status" -ne 0 ]
  FAKE_ICP_PORT=8080 run "$A4" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  [ "$(grep -c 'upgrade --install http-add-on' "$HELM_LOG")" -eq 2 ]
}

@test "missing versions file exits 2" {
  VERSIONS_FILE="$T/none" run "$A1" --env "$ENV"
  [ "$status" -eq 2 ]
}

@test "unknown argument exits 2" {
  run "$A1" --bogus; [ "$status" -eq 2 ]
  run "$A4" --bogus; [ "$status" -eq 2 ]
}

# --- A2 wildcard DNS ---
A2="$ROOT/bootstrap/a2-wildcard-dns.sh"
A3="$ROOT/bootstrap/a3-cert-manager.sh"
setup_az() { export AZ_LOG="$T/az.log"; : >"$AZ_LOG"; }

@test "A2: no record -> add wildcard to LB IP" {
  setup_az
  FAKE_LB_IP=20.1.2.3 run "$A2" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  grep -q "^network dns record-set a add-record .* -n \* --ipv4-address 20.1.2.3" "$AZ_LOG"
  [[ "$output" == *"WILDCARD=*.preview.nimat.dev -> 20.1.2.3"* ]] || false
}

@test "A2: record already correct -> skip" {
  setup_az
  FAKE_LB_IP=20.1.2.3 FAKE_A_IPS=20.1.2.3 run "$A2" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  [ "$(grep -cE 'add-record|remove-record' "$AZ_LOG" || true)" -eq 0 ]
}

@test "A2: stale IP -> removed, new added" {
  setup_az
  FAKE_LB_IP=20.1.2.3 FAKE_A_IPS=9.9.9.9 run "$A2" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  grep -q 'remove-record .* --ipv4-address 9.9.9.9' "$AZ_LOG"
  grep -q 'add-record .* --ipv4-address 20.1.2.3' "$AZ_LOG"
}

@test "A2: no LB IP fails before touching DNS" {
  setup_az
  FAKE_LB_IP= run "$A2" --env "$ENV" --apply
  [ "$status" -eq 1 ]
  [ "$(grep -c 'record-set' "$AZ_LOG" || true)" -eq 0 ]
}

@test "A2 dry-run: no DNS mutation" {
  setup_az
  FAKE_LB_IP=20.1.2.3 run "$A2" --env "$ENV"
  [[ "$output" == *"[dry-run] az network dns record-set a add-record"* ]] || false
  [ "$(grep -cE 'add-record|remove-record' "$AZ_LOG" || true)" -eq 0 ]
}

# --- A3 cert-manager ---
@test "A3 dry-run: plans install, identity, role, federation, manifests; mutates nothing" {
  setup_az
  FAKE_EXISTS="zone aks" run "$A3" --env "$ENV"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] helm upgrade --install cert-manager jetstack/cert-manager"*"--version v1.21.2"* ]] || false
  [[ "$output" == *"[dry-run] az identity create"* ]] || false
  [[ "$output" == *"[dry-run] az role assignment create"*"DNS Zone Contributor"* ]] || false
  [[ "$output" == *"[dry-run] az identity federated-credential create"*"system:serviceaccount:cert-manager:cert-manager"* ]] || false
  [[ "$output" == *'commonName: "*.preview.nimat.dev"'* ]] || false
  [[ "$output" == *"kind: TLSStore"* ]] || false
  [ "$(grep -cE ' create | assignment create' "$AZ_LOG" || true)" -eq 0 ]
  [ "$(grep -c . "$HELM_LOG" || true)" -eq 0 ]
}

@test "A3 apply: manifests use MI client id, zone, no ACME email; waits for cert" {
  setup_az
  FAKE_EXISTS="zone aks uami" run "$A3" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  m="$KUBECTL_LOG.apply"
  grep -q 'clientID: cid-123' "$m"
  grep -q 'hostedZoneName: preview.nimat.dev' "$m"
  grep -q 'namespace: traefik' "$m"
  [ "$(grep -c 'email:' "$m" || true)" -eq 0 ]
  grep -q 'annotate serviceaccount cert-manager -n cert-manager azure.workload.identity/client-id=cid-123' "$KUBECTL_LOG"
  grep -q 'wait --for=condition=Ready certificate/wildcard-preview' "$KUBECTL_LOG"
}

@test "A3 idempotent: identity, role, federation present -> none recreated" {
  setup_az
  FAKE_EXISTS="zone aks uami fic" FAKE_ROLE_COUNT=1 run "$A3" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  [ "$(grep -cE '^identity create|^role assignment create|^identity federated-credential create' "$AZ_LOG" || true)" -eq 0 ]
}

@test "A3: certificate never Ready -> fails" {
  setup_az
  FAKE_EXISTS="zone aks uami fic" FAKE_ROLE_COUNT=1 FAKE_WAIT_FAIL=1 run "$A3" --env "$ENV" --apply
  [ "$status" -ne 0 ]
}
