#!/usr/bin/env bash
# F010: prove a preview namespace's ResourceQuota `preview-quota` is enforced (operator-run).
# CP0 small pod fits; CP1 cpu and CP2 memory over the limit rejected; CP3 pod without resources
# rejected; CP4 fill to hard.pods with tiny real pods, one more rejected. Fill pods removed on exit.
# Usage: scripts/quota-check.sh <preview-namespace>
# Exit: 0 all PASS, 1 a checkpoint failed / no quota, 2 usage error.
set -euo pipefail

log() { printf '[%s] quota-check: %s\n' "$1" "$2" >&2; }

NS="${1:-}"
[ $# -eq 1 ] && [[ "$NS" =~ ^preview-[a-z0-9-]+$ ]] || { log error "usage: $0 <preview-namespace> (must match preview-*)"; exit 2; }
IMAGE="${QUOTA_CHECK_IMAGE:-registry.k8s.io/pause:3.10}"
failed=0

# Waits until the fill pods are gone: terminating pods still count against hard.pods, which would
# skew a quick rerun's CP4 and block a KEDA wake-up of the app.
remove_fill() {
  kubectl delete pods -n "$NS" -l quota-check=fill --ignore-not-found --grace-period=1 --wait=true \
    --timeout="${QUOTA_CHECK_CLEANUP_TIMEOUT:-120s}" >/dev/null 2>&1 || log warn "fill pods in $NS not gone yet"
}
# shellcheck disable=SC2329  # invoked via trap
cleanup() { log info "cleanup: deleting fill pods in $NS"; remove_fill; }
trap cleanup EXIT

remove_fill   # leftovers from an interrupted/previous run
q=$(kubectl get resourcequota preview-quota -n "$NS" -o json 2>/dev/null) || { log error "no ResourceQuota preview-quota in $NS"; exit 1; }
hard_pods=$(jq -r '.status.hard.pods // .spec.hard.pods // empty' <<<"$q")
[[ "$hard_pods" =~ ^[0-9]+$ ]] || { log error "preview-quota has no pods limit"; exit 1; }
log info "quota $NS: $(jq -c '.status.hard // .spec.hard' <<<"$q") used $(jq -c '.status.used // {}' <<<"$q")"

# pod NAME CPU MEM [none] -- pod manifest; "none" omits resources entirely
pod() {
  printf 'apiVersion: v1\nkind: Pod\nmetadata:\n  name: %s\n  labels: {quota-check: fill}\nspec:\n  containers:\n    - name: c\n      image: %s\n' "$1" "$IMAGE"
  [ "${4:-}" = none ] && return
  printf '      resources:\n        requests: {cpu: 1m, memory: 4Mi}\n        limits: {cpu: "%s", memory: %s}\n' "$2" "$3"
}
# admit NAME CPU MEM [none] -- server dry-run; prints output, returns kubectl's status
admit() { pod "$@" | kubectl apply -n "$NS" --dry-run=server -f - 2>&1; }

# expect_denied CP DESC PATTERN ARGS... -- PASS only when rejected for the expected reason
expect_denied() {
  local cp=$1 desc=$2 pat=$3 out; shift 3
  if out=$(admit "$@"); then log error "$cp FAIL $desc: admitted"; failed=1
  elif [[ "$out" == *$pat* ]]; then log info "$cp PASS $desc: ${out:0:200}"
  else log error "$cp FAIL $desc: rejected for another reason: $out"; failed=1; fi
}

if out=$(admit quota-probe-fits 10m 16Mi); then log info "CP0 PASS small pod fits"
else log error "CP0 FAIL small pod rejected: $out"; failed=1; fi
expect_denied CP1 "cpu over limits.cpu" "exceeded quota" quota-probe-cpu 1000 16Mi
expect_denied CP2 "memory over limits.memory" "exceeded quota" quota-probe-mem 10m 1Ti
expect_denied CP3 "pod without resources" "must specify" quota-probe-none 0 0 none

used=$(kubectl get resourcequota preview-quota -n "$NS" -o jsonpath='{.status.used.pods}' 2>/dev/null || true)
used=${used:-0}
log info "CP4 filling pods: used $used / hard $hard_pods"
i=0
while [ $(( used + i )) -lt "$hard_pods" ]; do
  i=$(( i + 1 ))
  out=$(pod "quota-fill-$i" 1m 8Mi | kubectl apply -n "$NS" -f - 2>&1) ||
    { log error "CP4 FAIL could not create fill pod $i: $out"; failed=1; break; }
done
[ "$failed" -eq 0 ] && expect_denied CP4 "pod beyond hard.pods=$hard_pods" "exceeded quota" quota-probe-pods 1m 8Mi

if [ "$failed" -eq 0 ]; then log info "ALL PASS: preview-quota enforced in $NS"; exit 0; fi
log error "quota check FAILED in $NS"; exit 1
