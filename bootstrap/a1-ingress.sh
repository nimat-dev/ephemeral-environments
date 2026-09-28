#!/usr/bin/env bash
# A1: Traefik v3 ingress controller (replaces EOL ingress-nginx, DEC-021). Prints the LB IP.
# Usage: bootstrap/a1-ingress.sh [--apply] [--env FILE]   (default: dry-run)
set -euo pipefail
export SCRIPT_NAME=a1-ingress
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_common.sh
. "$here/_common.sh"
parse_apply_args "$@"
load_env "$env_file"
load_versions
require_context

run helm repo add traefik https://traefik.github.io/charts --force-update
run helm upgrade --install traefik traefik/traefik -n traefik --create-namespace \
  --version "$TRAEFIK_CHART_VERSION" -f "$here/values/traefik.yaml" --wait --timeout 5m

if [ "$APPLY" -eq 1 ]; then
  ip=""
  for _ in $(seq 1 "${LB_WAIT_TRIES:-30}"); do
    ip=$(kubectl get svc traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    [ -n "$ip" ] && break
    sleep "${LB_WAIT_SECONDS:-10}"
  done
  [ -n "$ip" ] || { log error "no LoadBalancer IP for traefik after waiting"; exit 1; }
  echo "LB_IP=$ip"
fi
log info "done"
