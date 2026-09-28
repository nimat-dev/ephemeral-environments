#!/usr/bin/env bats
# F005: scripts/smoke.sh control flow against fakes (the real run is the e2e evidence).

ROOT="$BATS_TEST_DIRNAME/.."
SMOKE="$ROOT/scripts/smoke.sh"

setup() {
  T="$(mktemp -d)"
  export HELM_LOG="$T/helm.log" KUBECTL_LOG="$T/kubectl.log"; : >"$HELM_LOG"; : >"$KUBECTL_LOG"
  export PATH="$ROOT/tests/fakes:$PATH" SMOKE_POLL_SECONDS=0 FAKE_REPLICAS_SEQ="$T/seq"
  export SMOKE_ZERO_DEADLINE=5 SMOKE_BACK_DEADLINE=5
}
teardown() { rm -rf "$T"; }
seq_of() { printf '%s\n' "$@" >"$FAKE_REPLICAS_SEQ"; }
run_smoke() { run "$SMOKE" --image acr.io/todo --tag abc1234 --idle 1 "$@"; }

@test "happy path: 1 -> 0, wake to 1, back to 0 => 3 PASS, namespace cleaned" {
  seq_of 1 0 1 0
  run_smoke
  [ "$status" -eq 0 ]
  [[ "$output" == *"CP1 PASS"* ]] || false
  [[ "$output" == *"CP2 PASS cold start 0→1 ready"* ]] || false
  [[ "$output" == *"CP3 PASS"* ]] || false
  grep -q 'delete namespace preview-smoke' "$KUBECTL_LOG"
  grep -q 'set ingressClassName=traefik' "$HELM_LOG"
  grep -q 'set idleTimeoutSeconds=1' "$HELM_LOG"
}

@test "never scales to zero => CP2 FAIL before any request, still cleaned" {
  seq_of 1
  SMOKE_ZERO_DEADLINE=0 run "$SMOKE" --image acr.io/todo --tag abc1234 --idle 1
  [ "$status" -eq 1 ] || false
  [[ "$output" == *"CP2 FAIL never scaled to 0"* ]] || false
  [ "$(grep -c '^curl' "$KUBECTL_LOG" || true)" -eq 0 ]
  grep -q 'delete namespace preview-smoke' "$KUBECTL_LOG"
}

@test "missing spec.replicas is not mistaken for asleep" {
  printf '\n' >"$FAKE_REPLICAS_SEQ"
  SMOKE_ZERO_DEADLINE=0 run_smoke
  [ "$status" -eq 1 ]
  [[ "$output" == *"CP2 FAIL never scaled to 0"* ]] || false
}

@test "HTTP 200 but no ready pod => CP2 FAIL" {
  seq_of 0 0
  FAKE_READY=0 run_smoke
  [ "$status" -eq 1 ]
  [[ "$output" == *"CP2 FAIL wake request HTTP 200, ready=0"* ]] || false
}

@test "wake returns 502 => CP2 FAIL" {
  seq_of 0 0 0
  FAKE_CURL_OUT="502 0 30.0" run_smoke
  [ "$status" -eq 1 ]
  [[ "$output" == *"CP2 FAIL wake request HTTP 502"* ]] || false
}

@test "bad TLS => CP1 FAIL" {
  seq_of 0 1 0
  FAKE_CURL_OUT="200 20 1.0" run_smoke
  [ "$status" -eq 1 ]
  [[ "$output" == *"CP1 FAIL TLS verify=20"* ]] || false
}

@test "--keep leaves the namespace" {
  seq_of 0 1 0
  run_smoke --keep
  [ "$status" -eq 0 ]
  [ "$(grep -c 'delete namespace' "$KUBECTL_LOG" || true)" -eq 0 ]
}

@test "usage errors exit 2" {
  run "$SMOKE" --tag x; [ "$status" -eq 2 ]
  run "$SMOKE" --image x; [ "$status" -eq 2 ]
  run "$SMOKE" --image x --tag y --idle 0; [ "$status" -eq 2 ]
  run "$SMOKE" --bogus; [ "$status" -eq 2 ]
}
