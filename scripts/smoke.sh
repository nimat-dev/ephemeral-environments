#!/usr/bin/env bash
# Phase 01 e2e (spec Part C): deploy the preview chart, prove TLS, scale-to-zero, wake-on-request,
# and return to zero. Polls real state with deadlines; cleans up its namespace on exit.
# Usage: scripts/smoke.sh --image REPO --tag TAG [--domain D] [--idle SECONDS] [--keep]
# Exit: 0 all checkpoints pass, 1 a checkpoint failed, 2 usage error.
set -euo pipefail

log() { printf '[%s] smoke: %s\n' "$1" "$2" >&2; }
root="$(cd "$(dirname "$0")/.." && pwd)"

image="" tag="" domain="preview.nimat.dev" idle=120 keep=0
while [ $# -gt 0 ]; do
  case "$1" in
    --image) image="${2-}"; shift 2 ;;
    --tag) tag="${2-}"; shift 2 ;;
    --domain) domain="${2-}"; shift 2 ;;
    --idle) idle="${2-}"; shift 2 ;;
    --keep) keep=1; shift ;;
    *) log error "unknown argument: $1"; exit 2 ;;
  esac
done
[ -n "$image" ] && [ -n "$tag" ] || { log error "--image and --tag are required"; exit 2; }
[[ "$idle" =~ ^[1-9][0-9]*$ ]] || { log error "--idle must be a positive integer"; exit 2; }

NS=preview-smoke NAME=smoke HOST="smoke.$domain" URL="https://smoke.$domain/"
POLL="${SMOKE_POLL_SECONDS:-5}"
ZERO_DEADLINE="${SMOKE_ZERO_DEADLINE:-$(( idle + 240 ))}"   # chart starts at 1 replica; KEDA idles it
BACK_DEADLINE="${SMOKE_BACK_DEADLINE:-$(( idle + 180 ))}"
failed=0

cleanup() {
  if [ "$keep" -eq 1 ]; then log info "--keep: leaving namespace $NS"; return; fi
  log info "cleanup: deleting namespace $NS"
  kubectl delete namespace "$NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

# desired replicas (KEDA writes spec.replicas); an absent status must not read as "asleep"
replicas() { local r; r=$(kubectl get deploy "$NAME" -n "$NS" -o jsonpath='{.spec.replicas}' 2>/dev/null || true); echo "${r:-unknown}"; }
ready() { local r; r=$(kubectl get deploy "$NAME" -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true); echo "${r:-0}"; }

# wait_replicas CMP N DEADLINE_SECONDS -- poll until replicas CMP N (eq|ge). Prints elapsed seconds.
wait_replicas() {
  local cmp="$1" want="$2" deadline=$(( $(date +%s) + $3 )) start r
  start=$(date +%s)
  while :; do
    r=$(replicas)
    [ "$r" != unknown ] || r=-1
    case "$cmp" in
      eq) [ "$r" -eq "$want" ] && { echo $(( $(date +%s) - start )); return 0; } ;;
      ge) [ "$r" -ge "$want" ] && { echo $(( $(date +%s) - start )); return 0; } ;;
    esac
    [ "$(date +%s)" -lt "$deadline" ] || return 1
    sleep "$POLL"
  done
}

checkpoint() { printf 'CP%s %s %s\n' "$1" "$2" "$3"; [ "$2" = PASS ] || failed=1; }

log info "deploy $image:$tag as $HOST (idle ${idle}s)"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
helm upgrade --install "$NAME" "$root/deploy/preview" -n "$NS" \
  --set name="$NAME" --set host="$HOST" \
  --set image.repository="$image" --set image.tag="$tag" \
  --set idleTimeoutSeconds="$idle" --set ingressClassName=traefik \
  --wait --timeout 3m >/dev/null

# CP2 precondition: scaled to zero (the chart starts at 1 replica; KEDA must take it to 0).
if t=$(wait_replicas eq 0 "$ZERO_DEADLINE"); then log info "scaled to 0 after ${t}s idle"
else checkpoint 2 FAIL "never scaled to 0 within ${ZERO_DEADLINE}s (replicas=$(replicas))"; exit 1; fi

# CP1 + CP2: one strict-TLS request against a sleeping preview.
res=$(curl -sS -o /dev/null -w '%{http_code} %{ssl_verify_result} %{time_total}' --max-time 90 "$URL" 2>/dev/null || echo "000 1 0")
read -r code verify secs <<<"$res"
if [ "$verify" = 0 ] && [ "$code" != 000 ]; then checkpoint 1 PASS "valid TLS for $HOST"; else checkpoint 1 FAIL "TLS verify=$verify code=$code"; fi
rdy=$(ready)
if [ "$code" = 200 ] && [ "$rdy" -ge 1 ]; then checkpoint 2 PASS "cold start 0→$rdy ready in ${secs}s, HTTP 200"
else checkpoint 2 FAIL "wake request HTTP $code, ready=$rdy"; fi

# CP3: back to zero after idle.
if t=$(wait_replicas eq 0 "$BACK_DEADLINE"); then checkpoint 3 PASS "back to 0 after ${t}s"
else checkpoint 3 FAIL "still $(replicas) replica(s) after ${BACK_DEADLINE}s"; fi

[ "$failed" -eq 0 ] || { log error "smoke FAILED"; exit 1; }
log info "smoke PASSED"
