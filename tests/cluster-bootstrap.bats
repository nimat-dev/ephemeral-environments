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
