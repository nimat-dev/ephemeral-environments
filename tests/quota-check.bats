#!/usr/bin/env bats
# F010: scripts/quota-check.sh control flow against fake kubectl (the live run is the e2e evidence).

ROOT="$BATS_TEST_DIRNAME/.."
QC="$ROOT/scripts/quota-check.sh"
NS=preview-e2e-quota-test
QJSON='{"spec":{"hard":{"pods":"6"}},"status":{"hard":{"limits.cpu":"2","limits.memory":"4Gi","pods":"6"},"used":{"pods":"1"}}}'

setup() {
  T="$(mktemp -d)"
  export KUBECTL_LOG="$T/kubectl.log"; : >"$KUBECTL_LOG"
  export PATH="$ROOT/tests/fakes:$PATH" FAKE_QUOTA=on FAKE_QUOTA_JSON="$QJSON" FAKE_QUOTA_USED=1
}
teardown() { rm -rf "$T"; }

@test "enforced quota: CP0-CP4 PASS, fills to hard.pods, fill pods cleaned up" {
  run "$QC" "$NS"
  [ "$status" -eq 0 ]
  for cp in CP0 CP1 CP2 CP3 CP4; do [[ "$output" == *"$cp PASS"* ]] || false; done
  [[ "$output" == *"ALL PASS"* ]] || false
  [ "$(grep -c "^apply -n $NS -f -" "$KUBECTL_LOG")" -eq 5 ]     # used 1 -> 6
  grep -q 'name: quota-fill-5' "$KUBECTL_LOG.apply"
  ! grep -q 'name: quota-fill-6' "$KUBECTL_LOG.apply"
  grep -q "^delete pods -n $NS -l quota-check=fill" "$KUBECTL_LOG"
}

@test "quota not enforced (everything admitted) -> FAIL exit 1, still cleans up" {
  FAKE_QUOTA=off run "$QC" "$NS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"CP1 FAIL cpu over limits.cpu: admitted"* ]] || false
  [[ "$output" == *"CP3 FAIL pod without resources: admitted"* ]] || false
  grep -q "^delete pods -n $NS -l quota-check=fill" "$KUBECTL_LOG"
}

@test "rejected for another reason is not a PASS" {
  FAKE_QUOTA=wrong run "$QC" "$NS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"CP1 FAIL cpu over limits.cpu: rejected for another reason"* ]] || false
  [[ "$output" != *"CP1 PASS"* ]] || false
}

@test "fill pod creation fails -> CP4 FAIL, no final probe" {
  FAKE_FILL_FAIL=1 run "$QC" "$NS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"CP4 FAIL could not create fill pod 1"* ]] || false
  ! grep -q 'quota-probe-pods' "$KUBECTL_LOG.apply"
}

@test "already at hard.pods -> no fill, CP4 still probes" {
  FAKE_QUOTA_USED=6 run "$QC" "$NS"
  [ "$status" -eq 0 ]
  [ "$(grep -c "^apply -n $NS -f -" "$KUBECTL_LOG" || true)" -eq 0 ]
  [[ "$output" == *"CP4 PASS"* ]] || false
}

@test "no preview-quota in namespace -> exit 1" {
  FAKE_QUOTA_JSON= run "$QC" "$NS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no ResourceQuota preview-quota"* ]] || false
}

@test "usage: missing arg, extra arg, or non-preview namespace -> exit 2, nothing touched" {
  run "$QC"; [ "$status" -eq 2 ]
  run "$QC" "$NS" extra; [ "$status" -eq 2 ]
  run "$QC" kube-system; [ "$status" -eq 2 ]
  run "$QC" previewfoo; [ "$status" -eq 2 ]
  [ ! -s "$KUBECTL_LOG" ]
}
