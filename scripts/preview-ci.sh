#!/usr/bin/env bash
# CI entrypoint for the preview workflows (.github/workflows/preview-*.yml). Each workflow step is
# one subcommand; inputs come from env (never interpolated into shell by the workflow).
# Usage: scripts/preview-ci.sh plan|namespace|deploy|verify|summary|destroy|reap|purge
# Exit: 0 ok, 1 step failed, 2 usage/config error.
set -euo pipefail

log() { printf '[%s] preview-ci: %s\n' "$1" "$2" >&2; }
root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/preview.sh
. "$root/scripts/lib/preview.sh"

# need VAR... -- fail with exit 2 naming every unset/empty variable
need() {
  local v missing=()
  for v in "$@"; do [ -n "${!v-}" ] || missing+=("$v"); done
  [ ${#missing[@]} -eq 0 ] || { log error "missing env: ${missing[*]}"; exit 2; }
}

# out KEY=VALUE... -> $GITHUB_OUTPUT (stdout when unset)
out() { printf '%s\n' "$@" >>"${GITHUB_OUTPUT:-/dev/stdout}"; }

# plan: validate dispatch inputs, derive identity. Env: BRANCH LIFETIME LIFETIME_CUSTOM
# IDLE_TIMEOUT MAX_REPLICAS PREVIEW_DOMAIN SRC_DIR (checkout of BRANCH).
cmd_plan() {
  need BRANCH LIFETIME IDLE_TIMEOUT MAX_REPLICAS PREVIEW_DOMAIN SRC_DIR
  local sha plan
  sha=$(git -C "$SRC_DIR" rev-parse --short HEAD) || { log error "cannot read HEAD of $SRC_DIR"; exit 1; }
  plan=$(preview_plan "$BRANCH" "$LIFETIME" "${LIFETIME_CUSTOM-}" "$IDLE_TIMEOUT" "$MAX_REPLICAS" \
    "$PREVIEW_DOMAIN" "$sha") || exit 1
  log info "plan $(printf '%s' "$plan" | tr '\n' ' ')"
  # shellcheck disable=SC2086 # one KEY=VALUE per line, no spaces by construction
  out $plan
}

# namespace: apply the Namespace with the reaper's label contract (workflow owns it, DEC-007).
# Env: NAMESPACE PREVIEW_ID SHORT_SHA EXPIRES_AT BRANCH
cmd_namespace() {
  need NAMESPACE PREVIEW_ID SHORT_SHA EXPIRES_AT BRANCH
  log info "apply namespace $NAMESPACE expires-at=$EXPIRES_AT"
  namespace_manifest "$NAMESPACE" "$PREVIEW_ID" "$SHORT_SHA" "$EXPIRES_AT" "$BRANCH" | kubectl apply -f -
}

# deploy: helm upgrade --install. Strings go through --set-string so an id/sha like "1234e56" is
# not parsed as a float. Env: PREVIEW_ID NAMESPACE HOST SHORT_SHA IDLE_SECONDS MAX_REPLICAS IMAGE_REPOSITORY
# INTERCEPTOR_FQDN INTERCEPTOR_PORT INGRESS_CLASS [HELM_TIMEOUT]
cmd_deploy() {
  need PREVIEW_ID NAMESPACE HOST SHORT_SHA IDLE_SECONDS MAX_REPLICAS IMAGE_REPOSITORY \
    INTERCEPTOR_FQDN INTERCEPTOR_PORT INGRESS_CLASS
  export HELM_DRIVER=configmap   # DEC-026: the CI identity has no access to Secrets
  log info "helm upgrade --install $PREVIEW_ID -n $NAMESPACE image=$IMAGE_REPOSITORY:$SHORT_SHA"
  helm upgrade --install "$PREVIEW_ID" "$root/deploy/preview" -n "$NAMESPACE" \
    --set-string name="$PREVIEW_ID" \
    --set-string host="$HOST" \
    --set-string image.repository="$IMAGE_REPOSITORY" \
    --set-string image.tag="$SHORT_SHA" \
    --set idleTimeoutSeconds="$IDLE_SECONDS" \
    --set replicas.max="$MAX_REPLICAS" \
    --set-string interceptor.fqdn="$INTERCEPTOR_FQDN" \
    --set interceptor.port="$INTERCEPTOR_PORT" \
    --set-string ingressClassName="$INGRESS_CLASS" \
    --set-string commit="$SHORT_SHA" \
    --set-string branch="$PREVIEW_ID" \
    --wait --timeout "${HELM_TIMEOUT:-4m}"
}

# verify: cold-start proof -- HTTP 200 from the public URL within VERIFY_ATTEMPTS x VERIFY_SLEEP.
# Env: HOST [VERIFY_ATTEMPTS=30] [VERIFY_SLEEP=5]
cmd_verify() {
  need HOST
  local url="https://$HOST/" n="${VERIFY_ATTEMPTS:-30}" i code
  for i in $(seq 1 "$n"); do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url" || true)
    log info "verify attempt $i/$n: ${code:-000}"
    [ "$code" = 200 ] && { log info "verify ok $url"; return 0; }
    [ "$i" -eq "$n" ] || sleep "${VERIFY_SLEEP:-5}"
  done
  log error "preview did not return 200 within timeout: $url"
  exit 1
}

# summary: job summary; runs even after a failed step, so every value may be missing.
# Env: BRANCH [SHORT_SHA NAMESPACE HOST IMAGE_REPOSITORY IDLE_TIMEOUT LIFETIME JOB_STATUS]
cmd_summary() {
  local sha="${SHORT_SHA:--}" url="-"
  [ -z "${HOST-}" ] || url="https://$HOST"
  {
    echo "## Preview deployment ${JOB_STATUS:+(${JOB_STATUS})}"
    echo ""
    echo "| | |"
    echo "|---|---|"
    echo "| Branch | \`${BRANCH:--}\` |"
    echo "| Commit | \`$sha\` |"
    echo "| Image | \`${IMAGE_REPOSITORY:--}:$sha\` |"
    echo "| Namespace | \`${NAMESPACE:--}\` |"
    echo "| Idle timeout | ${IDLE_TIMEOUT:--} |"
    echo "| Lifetime | ${LIFETIME:--} |"
    echo ""
    echo "### URL"
    echo "$url"
  } >>"${GITHUB_STEP_SUMMARY:-/dev/stdout}"
}

# destroy: delete preview-<id> for BRANCH (same identity as deploy). Absent -> success; a namespace
# of that name not labeled managed-by=preview-bot is refused, never deleted. Env: BRANCH
cmd_destroy() {
  need BRANCH
  local id ns json owner
  id=$(preview_id "$BRANCH") || exit 1
  ns=$(preview_namespace "$id")
  json=$(kubectl get namespace "$ns" --ignore-not-found -o json)
  if [ -z "$json" ]; then
    log info "destroy: $ns not found, nothing to do"
    summary_line "Nothing to destroy: \`$ns\` does not exist."
    return 0
  fi
  owner=$(jq -r '.metadata.labels["managed-by"] // ""' <<<"$json")
  if [ "$owner" != preview-bot ]; then
    log error "destroy: refusing $ns (managed-by='$owner', want preview-bot)"
    exit 1
  fi
  log info "destroy: deleting $ns"
  kubectl delete namespace "$ns" --ignore-not-found --wait=false
  summary_line "Destroyed \`$ns\` (branch \`$BRANCH\`)."
}

# reap: delete every preview-bot namespace whose preview.expires-at < now. Nothing expired -> exit 0.
# A failed delete doesn't stop the others; the run fails at the end. Env: [REAP_NOW] (epoch, tests)
cmd_reap() {
  local now list expired ns failed=0 n=0
  now="${REAP_NOW:-$(date -u +%s)}"
  list=$(kubectl get namespaces -l managed-by=preview-bot -o json)
  expired=$(expired_namespaces "$now" <<<"$list")
  if [ -z "$expired" ]; then
    log info "reap: nothing to reap (now=$now)"
    summary_line "Nothing to reap."
    return 0
  fi
  while read -r ns; do
    [ -n "$ns" ] || continue
    log info "reap: deleting $ns"
    if kubectl delete namespace "$ns" --ignore-not-found --wait=false; then
      summary_line "Reaped \`$ns\`."; n=$((n + 1))
    else
      log error "reap: failed to delete $ns"; summary_line "FAILED to reap \`$ns\`."; failed=1
    fi
  done <<<"$expired"
  log info "reap: deleted $n namespace(s)"
  [ "$failed" -eq 0 ] || exit 1
}

summary_line() { printf '%s\n' "$1" >>"${GITHUB_STEP_SUMMARY:-/dev/stdout}"; }

# purge: delete stale preview image tags from ACR (Basic SKU has no retention policy, ACR Tasks are
# blocked — DEC-025/DEC-034). Never a tag a live preview runs: if the namespace list can't be read,
# nothing is deleted. In use = namespace `preview.commit` labels + images of Deployment templates and
# pods in preview-* (an old ReplicaSet can still run after a failed upgrade relabeled the namespace).
# Env: ACR_NAME APP_IMAGE_NAME [PURGE_MAX_AGE=7d PURGE_KEEP=3 PURGE_DRY_RUN=false]
cmd_purge() {
  need ACR_NAME APP_IMAGE_NAME
  local now age keep dry list workloads running tags in_use victims tag updated failed=0 n=0
  now="${PURGE_NOW:-$(date -u +%s)}"
  age=$(to_seconds "${PURGE_MAX_AGE:-7d}") || exit 2
  keep="${PURGE_KEEP:-3}"
  [[ "$keep" =~ ^[0-9]+$ ]] || { log error "PURGE_KEEP must be a non-negative integer: $keep"; exit 2; }
  case "${PURGE_DRY_RUN:-false}" in true) dry=1 ;; false) dry=0 ;;
    *) log error "PURGE_DRY_RUN must be true|false: ${PURGE_DRY_RUN}"; exit 2 ;; esac
  list=$(kubectl get namespaces -l managed-by=preview-bot -o json) || { log error "purge: cannot list previews; deleting nothing"; exit 1; }
  in_use=$(preview_commits <<<"$list") || { log error "purge: malformed namespace list; deleting nothing"; exit 1; }
  workloads=$(kubectl get deployments,pods -A -o json) || { log error "purge: cannot list preview workloads; deleting nothing"; exit 1; }
  running=$(image_tags_in_use "$APP_IMAGE_NAME" <<<"$workloads") ||
    { log error "purge: malformed workload list; deleting nothing"; exit 1; }
  in_use=$(printf '%s\n%s\n' "$in_use" "$running" | sed '/^$/d' | sort -u)
  tags=$(az acr repository show-tags -n "$ACR_NAME" --repository "$APP_IMAGE_NAME" --detail -o json) ||
    { log error "purge: cannot list tags of $APP_IMAGE_NAME"; exit 1; }
  # shellcheck disable=SC2086  # in_use: one sha per word
  victims=$(purge_tags "$now" "$age" "$keep" $in_use <<<"$tags") || exit 1
  log info "purge: in use [${in_use//$'\n'/ }], keep newest $keep, older than ${PURGE_MAX_AGE:-7d}"
  if [ -z "$victims" ]; then
    log info "purge: nothing to purge"; summary_line "Nothing to purge."; return 0
  fi
  while read -r tag; do
    if [ "$dry" -eq 1 ]; then
      log info "purge: [dry-run] would delete $APP_IMAGE_NAME:$tag"; summary_line "Would purge \`$APP_IMAGE_NAME:$tag\`."; continue
    fi
    # A deploy re-pushes its tag (refreshing lastUpdateTime) before relabeling the namespace; re-read
    # right before deleting so a redeploy racing this run keeps its image.
    if ! updated=$(az acr repository show -n "$ACR_NAME" --image "$APP_IMAGE_NAME:$tag" --query lastUpdateTime -o tsv) ||
      ! updated=$(iso_epoch "$updated"); then
      log error "purge: cannot re-read $APP_IMAGE_NAME:$tag; skipped"; failed=1; continue
    fi
    if [ "$updated" -ge $(( now - age )) ]; then
      log info "purge: $APP_IMAGE_NAME:$tag refreshed since listing (redeployed); skipped"; continue
    fi
    log info "purge: deleting $APP_IMAGE_NAME:$tag"
    if az acr repository delete -n "$ACR_NAME" --image "$APP_IMAGE_NAME:$tag" --yes >/dev/null; then
      summary_line "Purged \`$APP_IMAGE_NAME:$tag\`."; n=$((n + 1))
    else
      log error "purge: failed to delete $APP_IMAGE_NAME:$tag"; summary_line "FAILED to purge \`$APP_IMAGE_NAME:$tag\`."; failed=1
    fi
  done <<<"$victims"
  log info "purge: deleted $n tag(s)"
  [ "$failed" -eq 0 ] || exit 1
}

case "${1-}" in
  plan|namespace|deploy|verify|summary|destroy|reap|purge) "cmd_$1" ;;
  -h|--help) sed -n '2,5p' "$0" ;;
  *) log error "unknown command '${1-}' (want plan|namespace|deploy|verify|summary|destroy|reap|purge)"; exit 2 ;;
esac
