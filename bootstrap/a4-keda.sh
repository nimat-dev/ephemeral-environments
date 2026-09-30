#!/usr/bin/env bash
# A4: KEDA core + HTTP add-on (pinned). Verifies the interceptor proxy service the chart targets.
# SUPERSEDED on Flux clusters (F019, DEC-049): clusters/<team>/ + OpenTofu own this; kept for clusters without Flux.
# Usage: bootstrap/a4-keda.sh [--apply] [--env FILE]   (default: dry-run)
set -euo pipefail
export SCRIPT_NAME=a4-keda
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_common.sh
. "$here/_common.sh"
parse_apply_args "$@"
load_env "$env_file"
load_versions
require_context

INTERCEPTOR_SVC=keda-add-ons-http-interceptor-proxy
INTERCEPTOR_PORT=8080

run helm repo add kedacore https://kedacore.github.io/charts --force-update
run helm upgrade --install keda kedacore/keda -n keda --create-namespace \
  --version "$KEDA_CHART_VERSION" -f "$here/values/keda.yaml" --wait --timeout 5m
run helm upgrade --install http-add-on kedacore/keda-add-ons-http -n keda \
  --version "$KEDA_HTTP_CHART_VERSION" -f "$here/values/keda-http.yaml" --wait --timeout 5m

if [ "$APPLY" -eq 1 ]; then
  port=$(kubectl get svc "$INTERCEPTOR_SVC" -n keda -o jsonpath='{.spec.ports[?(@.name=="proxy")].port}' 2>/dev/null || true)
  [ "$port" = "$INTERCEPTOR_PORT" ] || {
    log error "interceptor svc $INTERCEPTOR_SVC:${port:-missing} != :$INTERCEPTOR_PORT (update INTERCEPTOR_FQDN/PORT)"; exit 1; }
  echo "INTERCEPTOR_FQDN=$INTERCEPTOR_SVC.keda.svc.cluster.local"
  echo "INTERCEPTOR_PORT=$port"
fi
log info "done"
