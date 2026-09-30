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

# plan: validate dispatch inputs + the app contract, derive identity. Env: BRANCH LIFETIME LIFETIME_CUSTOM
# IDLE_TIMEOUT MAX_REPLICAS PREVIEW_DOMAIN SRC_DIR (checkout of BRANCH) GITHUB_REPOSITORY [PREVIEW_APP].
# Outputs the identity plus sha (full, for the build jobs), config (normalized .preview.yaml JSON),
# components (build matrix) and verify_paths (one per component). Nothing is written unless everything validates.
cmd_plan() {
  need BRANCH LIFETIME IDLE_TIMEOUT MAX_REPLICAS PREVIEW_DOMAIN SRC_DIR GITHUB_REPOSITORY
  local sha full app plan config
  app=$(preview_app "${PREVIEW_APP-}" "$GITHUB_REPOSITORY") || exit 1
  if ! sha=$(git -C "$SRC_DIR" rev-parse --short HEAD) || ! full=$(git -C "$SRC_DIR" rev-parse HEAD); then
    log error "cannot read HEAD of $SRC_DIR"; exit 1
  fi
  plan=$(preview_plan "$app" "$BRANCH" "$LIFETIME" "${LIFETIME_CUSTOM-}" "$IDLE_TIMEOUT" "$MAX_REPLICAS" \
    "$PREVIEW_DOMAIN" "$sha") || exit 1
  config=$(read_config "$SRC_DIR") || exit $?
  log info "plan $(printf '%s' "$plan" | tr '\n' ' ')"
  log info "config $config"
  # shellcheck disable=SC2086 # one KEY=VALUE per line, no spaces by construction
  out $plan "sha=$full" "config=$config" \
    "components=$(jq -c '[.components[] | {name, context, dockerfile}]' <<<"$config")" \
    "verify_paths=$(preview_verify_paths <<<"$config")"
}

# read_config DIR -> normalized app contract from DIR/.preview.yaml (F016), or the default single
# component when absent. Exit 2 when yq is missing, 1 on invalid YAML or config.
read_config() {
  local f="$1/.preview.yaml" json
  if [ ! -e "$f" ]; then
    log info "no .preview.yaml: default single component (context .)"
    preview_config <<<"$PREVIEW_DEFAULT_CONFIG"; return
  fi
  local yq="${YQ:-yq}"
  command -v "$yq" >/dev/null 2>&1 || { log error "yq (mikefarah v4) is required to read $f"; return 2; }
  json=$("$yq" -o=json -I0 '.' "$f") || { log error "invalid YAML in .preview.yaml"; return 1; }
  preview_config <<<"$json" || { log error "invalid .preview.yaml (see message above)"; return 1; }
}

# namespace: apply the Namespace with the reaper's label contract (workflow owns it, DEC-007). An
# existing namespace this repo doesn't own (preview_owns) is refused, never relabeled (F015).
# Env: NAMESPACE PREVIEW_ID SHORT_SHA EXPIRES_AT BRANCH APP GITHUB_REPOSITORY
cmd_namespace() {
  need NAMESPACE PREVIEW_ID SHORT_SHA EXPIRES_AT BRANCH APP GITHUB_REPOSITORY
  local repo json manifest
  repo=$(preview_repo_label "$GITHUB_REPOSITORY") || exit 1
  manifest=$(namespace_manifest "$NAMESPACE" "$PREVIEW_ID" "$SHORT_SHA" "$EXPIRES_AT" "$BRANCH" "$APP" "$GITHUB_REPOSITORY") || exit 1
  json=$(kubectl get namespace "$NAMESPACE" --ignore-not-found -o json)
  if [ -n "$json" ] && ! preview_owns "$repo" <<<"$json"; then
    log error "namespace: refusing $NAMESPACE (owned by '$(jq -r '.metadata.labels["preview.repo"] // .metadata.labels["managed-by"] // "?"' <<<"$json")', not $repo)"
    exit 1
  fi
  log info "apply namespace $NAMESPACE repo=$repo expires-at=$EXPIRES_AT"
  kubectl apply -f - <<<"$manifest"
}

# deploy: helm upgrade --install. Strings go through --set-string so an id/sha like "1234e56" is
# not parsed as a float. With CONFIG (plan's normalized .preview.yaml) each component gets its image
# <IMAGE_REPOSITORY>/<component>:<SHORT_SHA> via a values file (F016); without it, the legacy single image.
# Env: PREVIEW_ID NAMESPACE HOST SHORT_SHA IDLE_SECONDS MAX_REPLICAS IMAGE_REPOSITORY
# INTERCEPTOR_FQDN INTERCEPTOR_PORT INGRESS_CLASS [CONFIG] [HELM_TIMEOUT]
cmd_deploy() {
  need PREVIEW_ID NAMESPACE HOST SHORT_SHA IDLE_SECONDS MAX_REPLICAS IMAGE_REPOSITORY \
    INTERCEPTOR_FQDN INTERCEPTOR_PORT INGRESS_CLASS
  export HELM_DRIVER=configmap   # DEC-026: the CI identity has no access to Secrets
  local image_args vf
  if [ -n "${CONFIG-}" ]; then
    vf="$(mktemp)"
    preview_values "$IMAGE_REPOSITORY" "$SHORT_SHA" <<<"$CONFIG" >"$vf" || { rm -f "$vf"; log error "deploy: invalid CONFIG"; exit 1; }
    image_args=(-f "$vf")
    log info "helm upgrade --install $PREVIEW_ID -n $NAMESPACE components=$(jq -r '[.components[].name] | join(",")' "$vf") tag=$SHORT_SHA"
  else
    image_args=(--set-string image.repository="$IMAGE_REPOSITORY" --set-string image.tag="$SHORT_SHA")
    log info "helm upgrade --install $PREVIEW_ID -n $NAMESPACE image=$IMAGE_REPOSITORY:$SHORT_SHA"
  fi
  helm upgrade --install "$PREVIEW_ID" "$root/deploy/preview" -n "$NAMESPACE" \
    "${image_args[@]}" \
    --set-string name="$PREVIEW_ID" \
    --set-string host="$HOST" \
    --set idleTimeoutSeconds="$IDLE_SECONDS" \
    --set replicas.max="$MAX_REPLICAS" \
    --set-string interceptor.fqdn="$INTERCEPTOR_FQDN" \
    --set interceptor.port="$INTERCEPTOR_PORT" \
    --set-string ingressClassName="$INGRESS_CLASS" \
    --set-string commit="$SHORT_SHA" \
    --set-string branch="$PREVIEW_ID" \
    --wait --timeout "${HELM_TIMEOUT:-4m}"
  [ -z "${vf-}" ] || rm -f "$vf"
}

# verify: cold-start proof -- HTTP 200 from every component (VERIFY_PATHS from plan, space-separated,
# default "/") within VERIFY_ATTEMPTS x VERIFY_SLEEP each. Env: HOST [VERIFY_PATHS] [VERIFY_ATTEMPTS=30] [VERIFY_SLEEP=5]
cmd_verify() {
  need HOST
  local path
  for path in ${VERIFY_PATHS:-/}; do
    case "$path" in /*) ;; *) log error "verify: path must start with /: $path"; exit 2 ;; esac
    verify_url "https://$HOST$path"
  done
}

verify_url() {
  local url="$1" n="${VERIFY_ATTEMPTS:-30}" i code
  for i in $(seq 1 "$n"); do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url" || true)
    log info "verify $url attempt $i/$n: ${code:-000}"
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
    if [ -n "${COMPONENTS-}" ]; then
      echo "| Images | $(jq -r --arg r "${IMAGE_REPOSITORY:--}" --arg t "$sha" '[.[] | "`\($r)/\(.name):\($t)`"] | join(" ")' <<<"$COMPONENTS" 2>/dev/null || echo -) |"
    else
      echo "| Image | \`${IMAGE_REPOSITORY:--}:$sha\` |"
    fi
    echo "| Namespace | \`${NAMESPACE:--}\` |"
    echo "| Idle timeout | ${IDLE_TIMEOUT:--} |"
    echo "| Lifetime | ${LIFETIME:--} |"
    echo ""
    echo "### URL"
    echo "$url"
  } >>"${GITHUB_STEP_SUMMARY:-/dev/stdout}"
}

# destroy: delete preview-<app>-<id> for BRANCH (same identity as deploy). Absent -> falls back to the
# pre-F015 name preview-<id>, deleted only when preview-bot made it and it has no preview.repo label
# (a labeled one is some repo's new-format namespace). Absent both -> success. A namespace of the new
# name this repo doesn't own (preview_owns) is refused, never deleted.
# Env: BRANCH GITHUB_REPOSITORY [PREVIEW_APP]
cmd_destroy() {
  need BRANCH GITHUB_REPOSITORY
  local id app repo ns legacy json note=""
  id=$(preview_id "$BRANCH") || exit 1
  app=$(preview_app "${PREVIEW_APP-}" "$GITHUB_REPOSITORY") || exit 1
  repo=$(preview_repo_label "$GITHUB_REPOSITORY") || exit 1
  ns=$(preview_namespace "$app" "$id")
  json=$(kubectl get namespace "$ns" --ignore-not-found -o json)
  if [ -z "$json" ]; then
    legacy="preview-$id"
    json=$(kubectl get namespace "$legacy" --ignore-not-found -o json)
    if [ -n "$json" ] && jq -e '(.metadata.labels // {}) as $l | $l["managed-by"] == "preview-bot" and ($l | has("preview.repo") | not)' \
      >/dev/null <<<"$json"; then
      ns=$legacy note=" (legacy pre-F015 name)"
    else
      log info "destroy: $ns not found, nothing to do"
      summary_line "Nothing to destroy: \`$ns\` does not exist."
      return 0
    fi
  elif ! preview_owns "$repo" <<<"$json"; then
    log error "destroy: refusing $ns (managed-by='$(jq -r '.metadata.labels["managed-by"] // ""' <<<"$json")', repo='$(jq -r '.metadata.labels["preview.repo"] // ""' <<<"$json")'; want preview-bot + $repo)"
    exit 1
  fi
  log info "destroy: deleting $ns$note"
  kubectl delete namespace "$ns" --ignore-not-found --wait=false
  summary_line "Destroyed \`$ns\` (branch \`$BRANCH\`)$note."
}

# reap: delete every preview-bot namespace of this repo (+ legacy unlabeled, F015) whose
# preview.expires-at < now; other repos' previews are theirs to reap. Nothing expired -> exit 0.
# A failed delete doesn't stop the others; the run fails at the end.
# Env: GITHUB_REPOSITORY [REAP_NOW] (epoch, tests)
cmd_reap() {
  need GITHUB_REPOSITORY
  local now repo list expired ns failed=0 n=0
  now="${REAP_NOW:-$(date -u +%s)}"
  repo=$(preview_repo_label "$GITHUB_REPOSITORY") || exit 1
  list=$(kubectl get namespaces -l managed-by=preview-bot -o json)
  expired=$(expired_namespaces "$now" "$repo" <<<"$list")
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
# Repos purged: APP_IMAGE_NAME (legacy single image) and every APP_IMAGE_NAME/<component> (F016, DEC-046).
# Env: ACR_NAME APP_IMAGE_NAME [PURGE_MAX_AGE=7d PURGE_KEEP=3 PURGE_DRY_RUN=false]
cmd_purge() {
  need ACR_NAME APP_IMAGE_NAME
  local now age keep dry list workloads labels repos repo failed=0
  now="${PURGE_NOW:-$(date -u +%s)}"
  age=$(to_seconds "${PURGE_MAX_AGE:-7d}") || exit 2
  keep="${PURGE_KEEP:-3}"
  [[ "$keep" =~ ^[0-9]+$ ]] || { log error "PURGE_KEEP must be a non-negative integer: $keep"; exit 2; }
  case "${PURGE_DRY_RUN:-false}" in true) dry=1 ;; false) dry=0 ;;
    *) log error "PURGE_DRY_RUN must be true|false: ${PURGE_DRY_RUN}"; exit 2 ;; esac
  list=$(kubectl get namespaces -l managed-by=preview-bot -o json) || { log error "purge: cannot list previews; deleting nothing"; exit 1; }
  labels=$(preview_commits <<<"$list") || { log error "purge: malformed namespace list; deleting nothing"; exit 1; }
  workloads=$(kubectl get deployments,pods -A -o json) || { log error "purge: cannot list preview workloads; deleting nothing"; exit 1; }
  repos=$(az acr repository list -n "$ACR_NAME" -o json | jq -r --arg app "$APP_IMAGE_NAME" \
    '.[] | select(. == $app or startswith($app + "/"))') || { log error "purge: cannot list repositories of $ACR_NAME; deleting nothing"; exit 1; }
  [ -n "$repos" ] || { log info "purge: no repositories for $APP_IMAGE_NAME"; summary_line "Nothing to purge."; return 0; }
  while read -r repo; do
    purge_repo "$repo" || failed=1
  done <<<"$repos"
  [ "$failed" -eq 0 ] || exit 1
}

# purge_repo REPO -- one ACR repository; uses now/age/keep/dry/labels/workloads of cmd_purge. Returns 1
# on any failure (the others still run).
purge_repo() {
  local repo="$1" running in_use tags victims tag updated failed=0 n=0
  running=$(image_tags_in_use "$repo" <<<"$workloads") ||
    { log error "purge: malformed workload list; deleting nothing"; return 1; }
  in_use=$(printf '%s\n%s\n' "$labels" "$running" | sed '/^$/d' | sort -u)
  tags=$(az acr repository show-tags -n "$ACR_NAME" --repository "$repo" --detail -o json) ||
    { log error "purge: cannot list tags of $repo"; return 1; }
  # shellcheck disable=SC2086  # in_use: one sha per word
  victims=$(purge_tags "$now" "$age" "$keep" $in_use <<<"$tags") || return 1
  log info "purge: $repo in use [${in_use//$'\n'/ }], keep newest $keep, older than ${PURGE_MAX_AGE:-7d}"
  if [ -z "$victims" ]; then
    log info "purge: $repo nothing to purge"; summary_line "Nothing to purge in \`$repo\`."; return 0
  fi
  while read -r tag; do
    if [ "$dry" -eq 1 ]; then
      log info "purge: [dry-run] would delete $repo:$tag"; summary_line "Would purge \`$repo:$tag\`."; continue
    fi
    # A deploy re-pushes its tag (refreshing lastUpdateTime) before relabeling the namespace; re-read
    # right before deleting so a redeploy racing this run keeps its image.
    if ! updated=$(az acr repository show -n "$ACR_NAME" --image "$repo:$tag" --query lastUpdateTime -o tsv) ||
      ! updated=$(iso_epoch "$updated"); then
      log error "purge: cannot re-read $repo:$tag; skipped"; failed=1; continue
    fi
    if [ "$updated" -ge $(( now - age )) ]; then
      log info "purge: $repo:$tag refreshed since listing (redeployed); skipped"; continue
    fi
    log info "purge: deleting $repo:$tag"
    if az acr repository delete -n "$ACR_NAME" --image "$repo:$tag" --yes >/dev/null; then
      summary_line "Purged \`$repo:$tag\`."; n=$((n + 1))
    else
      log error "purge: failed to delete $repo:$tag"; summary_line "FAILED to purge \`$repo:$tag\`."; failed=1
    fi
  done <<<"$victims"
  log info "purge: $repo deleted $n tag(s)"
  [ "$failed" -eq 0 ]
}

case "${1-}" in
  plan|namespace|deploy|verify|summary|destroy|reap|purge) "cmd_$1" ;;
  -h|--help) sed -n '2,5p' "$0" ;;
  *) log error "unknown command '${1-}' (want plan|namespace|deploy|verify|summary|destroy|reap|purge)"; exit 2 ;;
esac
