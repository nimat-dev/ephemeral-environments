#!/usr/bin/env bats
# F006: scripts/preview-ci.sh (workflow step entrypoint) against fakes + preview-deploy.yml shape.
# The real dispatch is the e2e evidence.

ROOT="$BATS_TEST_DIRNAME/.."
CI="$ROOT/scripts/preview-ci.sh"
WF="$ROOT/.github/workflows/preview-deploy.yml"

setup() {
  T="$(mktemp -d)"
  REAL_HELM="$(command -v helm)"
  export HELM_LOG="$T/helm.log" KUBECTL_LOG="$T/kubectl.log"; : >"$HELM_LOG"; : >"$KUBECTL_LOG"
  export PATH="$ROOT/tests/fakes:$HOME/go/bin:$PATH" GITHUB_OUTPUT="$T/out" GITHUB_STEP_SUMMARY="$T/summary"
  unset HELM_DRIVER
  git -C "$T" init -q src && git -C "$T/src" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  export SRC_DIR="$T/src" BRANCH='Feature/JIRA-1' LIFETIME=48h LIFETIME_CUSTOM='' IDLE_TIMEOUT=30m \
    MAX_REPLICAS=3 PREVIEW_DOMAIN=preview.example.com
}
teardown() { rm -rf "$T"; }

deploy_env() {
  export PREVIEW_ID=feature-jira-1 NAMESPACE=preview-feature-jira-1 HOST=feature-jira-1.preview.example.com \
    SHORT_SHA=1234e56 IDLE_SECONDS=1800 IMAGE_REPOSITORY=acr.example/todo \
    INTERCEPTOR_FQDN=icp.keda INTERCEPTOR_PORT=8080 INGRESS_CLASS=traefik
}

# --- plan ---
@test "plan: writes identity to GITHUB_OUTPUT with HEAD short sha" {
  run "$CI" plan
  [ "$status" -eq 0 ]
  sha=$(git -C "$SRC_DIR" rev-parse --short HEAD)
  grep -qx preview_id=feature-jira-1 "$GITHUB_OUTPUT"
  grep -qx namespace=preview-feature-jira-1 "$GITHUB_OUTPUT"
  grep -qx host=feature-jira-1.preview.example.com "$GITHUB_OUTPUT"
  grep -qx "short_sha=$sha" "$GITHUB_OUTPUT"
  grep -qx idle=1800 "$GITHUB_OUTPUT"
  grep -qx lifetime=48h "$GITHUB_OUTPUT"
  grep -qE '^expires_at=[0-9]+$' "$GITHUB_OUTPUT"
}

@test "plan: invalid input -> exit 1, nothing written" {
  LIFETIME=custom run "$CI" plan
  [ "$status" -eq 1 ]; [[ "$output" == *"lifetime_custom is empty"* ]] || false
  [ ! -s "$GITHUB_OUTPUT" ]
  MAX_REPLICAS=50 run "$CI" plan
  [ "$status" -eq 1 ]; [ ! -s "$GITHUB_OUTPUT" ]
  BRANCH='///' run "$CI" plan
  [ "$status" -eq 1 ]; [ ! -s "$GITHUB_OUTPUT" ]
}

@test "plan: missing env -> exit 2 naming it; bad src dir -> exit 1" {
  PREVIEW_DOMAIN='' run "$CI" plan
  [ "$status" -eq 2 ]; [[ "$output" == *"missing env: PREVIEW_DOMAIN"* ]] || false
  SRC_DIR="$T/nope" run "$CI" plan
  [ "$status" -eq 1 ]
}

# --- namespace ---
@test "namespace: applies label contract via kubectl apply -f -" {
  export NAMESPACE=preview-feature-jira-1 PREVIEW_ID=feature-jira-1 SHORT_SHA=abc1234 EXPIRES_AT=1700000000
  run "$CI" namespace
  [ "$status" -eq 0 ]
  grep -q 'apply -f -' "$KUBECTL_LOG"
  [ "$(jq -r '.metadata.labels["preview.expires-at"]' "$KUBECTL_LOG.apply")" = 1700000000 ]
  [ "$(jq -r '.metadata.labels["managed-by"]' "$KUBECTL_LOG.apply")" = preview-bot ]
  [ "$(jq -r '.metadata.annotations["preview.branch-original"]' "$KUBECTL_LOG.apply")" = 'Feature/JIRA-1' ]
}

# --- deploy ---
@test "deploy: helm upgrade --install with configmap driver, string-safe values, traefik class" {
  deploy_env
  cat >"$T/helm" <<'SH'
#!/usr/bin/env bash
echo "HELM_DRIVER=${HELM_DRIVER-} $*" >>"$HELM_LOG"
SH
  chmod +x "$T/helm"
  PATH="$T:$PATH" run "$CI" deploy
  [ "$status" -eq 0 ]
  log=$(cat "$HELM_LOG")
  [[ "$log" == "HELM_DRIVER=configmap upgrade --install feature-jira-1 "*" -n preview-feature-jira-1 "* ]] || false
  for a in 'set-string image.tag=1234e56' 'set-string commit=1234e56' 'set-string name=feature-jira-1' \
           'set-string host=feature-jira-1.preview.example.com' 'set-string image.repository=acr.example/todo' \
           'set-string ingressClassName=traefik' 'set idleTimeoutSeconds=1800' 'set replicas.max=3' \
           'set interceptor.port=8080' 'set-string interceptor.fqdn=icp.keda' '--wait --timeout 4m'; do
    [[ "$log" == *"$a"* ]] || { echo "missing: $a"; return 1; }
  done
}

@test "deploy: helm failure propagates; missing env -> exit 2" {
  deploy_env
  FAKE_HELM_FAIL=upgrade run "$CI" deploy
  [ "$status" -eq 1 ]
  INGRESS_CLASS='' run "$CI" deploy
  [ "$status" -eq 2 ]; [[ "$output" == *"missing env: INGRESS_CLASS"* ]] || false
}

@test "deploy passes strings via --set-string: branch 'null'/'true' renders (plain --set breaks the chart)" {
  for id in null true 1234e56; do
    run "$REAL_HELM" template x "$ROOT/deploy/preview" --set-string name="$id" --set-string host=h.example \
      --set-string image.repository=r --set-string image.tag=abc1234 --set-string branch="$id"
    [ "$status" -eq 0 ] || { echo "set-string failed for $id: $output"; return 1; }
    [[ "$output" == *"  name: $id"* ]] || { echo "name lost for $id"; return 1; }
  done
  run "$REAL_HELM" template x "$ROOT/deploy/preview" --set name=null --set host=h.example \
    --set image.repository=r --set image.tag=abc1234
  [ "$status" -ne 0 ]   # documents why deploy must not use plain --set for strings
}

# --- verify ---
@test "verify: 200 on first try -> ok, one request" {
  HOST=h.example VERIFY_SLEEP=0 FAKE_CURL_OUT=200 run "$CI" verify
  [ "$status" -eq 0 ]
  [ "$(grep -c 'curl ' "$KUBECTL_LOG")" -eq 1 ]
  grep -q 'https://h.example/' "$KUBECTL_LOG"
}

@test "verify: cold start (000, 502) then 200 -> ok after 3 attempts" {
  printf '%s\n' 000 502 200 >"$T/seq"
  HOST=h.example VERIFY_SLEEP=0 FAKE_CURL_SEQ="$T/seq" run "$CI" verify
  [ "$status" -eq 0 ]
  [ "$(grep -c 'curl ' "$KUBECTL_LOG")" -eq 3 ]
}

@test "verify: never 200 -> exit 1 after VERIFY_ATTEMPTS" {
  HOST=h.example VERIFY_SLEEP=0 VERIFY_ATTEMPTS=4 FAKE_CURL_OUT=404 run "$CI" verify
  [ "$status" -eq 1 ]; [[ "$output" == *"did not return 200"* ]] || false
  [ "$(grep -c 'curl ' "$KUBECTL_LOG")" -eq 4 ]
}

# --- summary ---
@test "summary: full table with URL" {
  export SHORT_SHA=abc1234 NAMESPACE=preview-x HOST=x.example IMAGE_REPOSITORY=acr/todo LIFETIME=12h JOB_STATUS=success
  run "$CI" summary
  [ "$status" -eq 0 ]
  for s in '(success)' '`Feature/JIRA-1`' '`abc1234`' '`acr/todo:abc1234`' '`preview-x`' '| 30m |' '| 12h |' 'https://x.example'; do
    grep -qF -- "$s" "$GITHUB_STEP_SUMMARY" || { echo "missing: $s"; return 1; }
  done
}

@test "summary: after an early failure (no plan outputs) still writes, no URL" {
  JOB_STATUS=failure run "$CI" summary
  [ "$status" -eq 0 ]
  grep -qF '(failure)' "$GITHUB_STEP_SUMMARY"
  [ "$(tail -1 "$GITHUB_STEP_SUMMARY")" = - ]
}

@test "unknown command -> exit 2" {
  run "$CI" nope
  [ "$status" -eq 2 ]
}

# --- workflow shape (API_SURFACE.md) ---
@test "workflow: inputs, defaults, concurrency per API_SURFACE" {
  grep -qx 'name: Deploy Preview' "$WF"
  for i in branch lifetime lifetime_custom idle_timeout max_replicas; do grep -qx "      $i:" "$WF" || { echo "no input $i"; return 1; }; done
  grep -qF 'options: ["24h", "48h", "7d", "custom"]' "$WF"
  grep -qF 'options: ["15m", "30m", "1h", "6h", "never"]' "$WF"
  grep -qF 'default: "48h"' "$WF"; grep -qF 'default: "30m"' "$WF"; grep -qF 'default: "3"' "$WF"
  grep -qF 'group: preview-${{ inputs.branch }}' "$WF"
  grep -qF 'cancel-in-progress: false' "$WF"
  grep -qx '    environment: preview' "$WF"
}

@test "workflow: configmap driver, todo context, amd64, ingress class var, summary always" {
  grep -qE '^      HELM_DRIVER: configmap' "$WF"
  grep -qE '^          context: src/todo' "$WF"
  grep -qE '^          platforms: linux/amd64' "$WF"
  grep -qF 'INGRESS_CLASS: ${{ vars.INGRESS_CLASS }}' "$WF"
  grep -qF 'tags: ${{ env.IMAGE_REPOSITORY }}:${{ steps.id.outputs.short_sha }}' "$WF"
  awk '/name: Summary/{f=1} f&&/if: always\(\)/{ok=1} END{exit !ok}' "$WF"
}

@test "workflow: no expression interpolation inside run: (script injection guard)" {
  run awk '/^ *run: /{ if ($0 ~ /\$\{\{/) print FNR": "$0 }' "$WF"
  [ -z "$output" ] || { echo "$output"; false; }
  ! grep -qE '^ *run: *\|' "$WF"   # multi-line run blocks would dodge the check above
}

# --- destroy (F007) ---
DWF="$ROOT/.github/workflows/preview-destroy.yml"
ns_json() { printf '{"metadata":{"name":"%s","labels":{%s}}}' "$1" "$2"; }

@test "destroy: preview-bot namespace -> delete --ignore-not-found --wait=false, same id as deploy" {
  export FAKE_NS_JSON; FAKE_NS_JSON=$(ns_json preview-feature-jira-1 '"managed-by":"preview-bot"')
  run "$CI" destroy
  [ "$status" -eq 0 ]
  grep -q 'get namespace preview-feature-jira-1 --ignore-not-found -o json' "$KUBECTL_LOG"
  grep -qx 'delete namespace preview-feature-jira-1 --ignore-not-found --wait=false' "$KUBECTL_LOG"
  grep -qF 'Destroyed `preview-feature-jira-1`' "$GITHUB_STEP_SUMMARY"
  # deploy's plan derives the very same namespace
  "$CI" plan 2>/dev/null; grep -qx namespace=preview-feature-jira-1 "$GITHUB_OUTPUT"
}

@test "destroy: non-existent preview -> success, no delete (idempotent)" {
  FAKE_NS_JSON='' run "$CI" destroy
  [ "$status" -eq 0 ]
  ! grep -q '^delete ' "$KUBECTL_LOG"
  grep -qF 'Nothing to destroy' "$GITHUB_STEP_SUMMARY"
}

@test "destroy: namespace not owned by preview-bot is refused, never deleted" {
  for labels in '' '"managed-by":"someone-else"'; do
    : >"$KUBECTL_LOG"
    FAKE_NS_JSON=$(ns_json preview-feature-jira-1 "$labels") run "$CI" destroy
    [ "$status" -eq 1 ]; [[ "$output" == *"refusing preview-feature-jira-1"* ]] || false
    ! grep -q '^delete ' "$KUBECTL_LOG"
  done
}

@test "destroy: invalid branch -> exit 1, missing -> exit 2, kubectl get failure -> exit non-zero, no delete" {
  BRANCH='///' run "$CI" destroy; [ "$status" -eq 1 ]
  BRANCH='' run "$CI" destroy; [ "$status" -eq 2 ]
  FAKE_GET_FAIL=1 run "$CI" destroy; [ "$status" -ne 0 ]
  ! grep -q '^delete ' "$KUBECTL_LOG"
}

@test "destroy workflow: input, concurrency shared with deploy, env-only input, calls entrypoint" {
  grep -qx 'name: Destroy Preview' "$DWF"
  grep -qx '      branch:' "$DWF"
  grep -qF 'group: preview-${{ inputs.branch }}' "$DWF"
  grep -qx '    environment: preview' "$DWF"
  grep -qx '        run: ./scripts/preview-ci.sh destroy' "$DWF"
  run awk '/^ *run: /{ if ($0 ~ /\$\{\{/) print }' "$DWF"; [ -z "$output" ]
}

# --- reap (F008) ---
RWF="$ROOT/.github/workflows/preview-reap.yml"
ns_list() {
  cat <<'JSON'
{"items":[
 {"metadata":{"name":"preview-old","labels":{"managed-by":"preview-bot","preview.expires-at":"100"}}},
 {"metadata":{"name":"preview-live","labels":{"managed-by":"preview-bot","preview.expires-at":"900"}}},
 {"metadata":{"name":"preview-nolabel","labels":{"managed-by":"preview-bot"}}},
 {"metadata":{"name":"default","labels":{"managed-by":"preview-bot","preview.expires-at":"1"}}}
]}
JSON
}

@test "reap: deletes only expired preview-* namespaces, lists by label" {
  FAKE_NS_LIST_JSON=$(ns_list) REAP_NOW=500 run "$CI" reap
  [ "$status" -eq 0 ]
  grep -qx 'get namespaces -l managed-by=preview-bot -o json' "$KUBECTL_LOG"
  [ "$(grep '^delete ' "$KUBECTL_LOG")" = "$(printf '%s\n' \
    'delete namespace preview-old --ignore-not-found --wait=false' \
    'delete namespace preview-nolabel --ignore-not-found --wait=false')" ]
  grep -qF 'Reaped `preview-old`' "$GITHUB_STEP_SUMMARY"
}

@test "reap: nothing expired / no previews -> 'nothing to reap', exit 0, no delete" {
  for list in "$(ns_list | jq 'del(.items[] | select(.metadata.name == "preview-nolabel"))')" '{"items":[]}'; do
    : >"$KUBECTL_LOG"
    FAKE_NS_LIST_JSON="$list" REAP_NOW=50 run "$CI" reap
    [ "$status" -eq 0 ]; [[ "$output" == *"nothing to reap"* ]] || false
    ! grep -q '^delete ' "$KUBECTL_LOG"
  done
}

@test "reap: one delete fails -> others still deleted, run fails" {
  FAKE_NS_LIST_JSON=$(ns_list) REAP_NOW=500 FAKE_DELETE_FAIL=preview-old run "$CI" reap
  [ "$status" -eq 1 ]
  grep -q 'delete namespace preview-nolabel' "$KUBECTL_LOG"
  grep -qF 'FAILED to reap `preview-old`' "$GITHUB_STEP_SUMMARY"
}

@test "reap: list failure or malformed list -> non-zero, no delete" {
  FAKE_GET_FAIL=1 run "$CI" reap; [ "$status" -ne 0 ]
  FAKE_NS_LIST_JSON='{bad' run "$CI" reap; [ "$status" -ne 0 ]
  ! grep -q '^delete ' "$KUBECTL_LOG"
}

@test "reap workflow: cron */30 + dispatch, own concurrency group, calls entrypoint" {
  grep -qx 'name: Reap Expired Previews' "$RWF"
  grep -qF -- '- cron: "*/30 * * * *"' "$RWF"
  grep -qx '  workflow_dispatch: {}' "$RWF"
  grep -qx '  group: preview-reap' "$RWF"
  grep -qx '        run: ./scripts/preview-ci.sh reap' "$RWF"
}

# --- purge (F011) ---
PWF="$ROOT/.github/workflows/preview-acr-purge.yml"
purge_env() {
  export AZ_LOG="$T/az.log" ACR_NAME=acr1 APP_IMAGE_NAME=todo PURGE_NOW=1790726400; : >"$AZ_LOG"
  export FAKE_TAGS_JSON='[
    {"name":"aaaaaaa","lastUpdateTime":"2026-09-01T00:00:00Z"},
    {"name":"bbbbbbb","lastUpdateTime":"2026-09-02T00:00:00Z"},
    {"name":"ccccccc","lastUpdateTime":"2026-09-03T00:00:00Z"},
    {"name":"ddddddd","lastUpdateTime":"2026-09-29T00:00:00Z"}]'
  export FAKE_NS_LIST_JSON='{"items":[{"metadata":{"name":"preview-x","labels":{"managed-by":"preview-bot","preview.commit":"bbbbbbb"}}}]}'
}

@test "purge: deletes old unused sha tags, keeps in-use + newest, summary" {
  purge_env
  PURGE_KEEP=1 run "$CI" purge
  [ "$status" -eq 0 ]
  grep -qx 'get namespaces -l managed-by=preview-bot -o json' "$KUBECTL_LOG"
  grep -q '^acr repository show-tags -n acr1 --repository todo --detail -o json' "$AZ_LOG"
  [ "$(grep '^acr repository delete' "$AZ_LOG")" = "$(printf '%s\n' \
    'acr repository delete -n acr1 --image todo:ccccccc --yes' \
    'acr repository delete -n acr1 --image todo:aaaaaaa --yes')" ]
  grep -qF 'Purged `todo:aaaaaaa`' "$GITHUB_STEP_SUMMARY"
  [[ "$output" == *"in use [bbbbbbb]"* ]] || false
}

@test "purge: image still run by a pod (failed upgrade relabeled ns) is protected" {
  purge_env
  FAKE_WORKLOADS_JSON='{"items":[{"kind":"Pod","metadata":{"namespace":"preview-x"},"spec":{"containers":[{"image":"acr1.azurecr.io/todo:aaaaaaa"}]}}]}' \
    PURGE_KEEP=0 run "$CI" purge
  [ "$status" -eq 0 ]
  grep -qx 'get deployments,pods -A -o json' "$KUBECTL_LOG"
  ! grep -q 'todo:aaaaaaa' "$AZ_LOG"
  grep -q 'todo:ccccccc' "$AZ_LOG"
  [[ "$output" == *"in use [aaaaaaa bbbbbbb]"* ]] || false
}

@test "purge: dry run lists, deletes nothing" {
  purge_env
  PURGE_KEEP=0 PURGE_DRY_RUN=true run "$CI" purge
  [ "$status" -eq 0 ]
  ! grep -q '^acr repository delete' "$AZ_LOG"
  grep -qF 'Would purge `todo:aaaaaaa`' "$GITHUB_STEP_SUMMARY"
}

@test "purge: namespace list or tag list unreadable -> exit 1, deletes nothing" {
  purge_env
  FAKE_GET_FAIL=1 run "$CI" purge; [ "$status" -eq 1 ]
  [[ "$output" == *"cannot list previews; deleting nothing"* ]] || false
  FAKE_NS_LIST_JSON='{bad' run "$CI" purge; [ "$status" -eq 1 ]
  FAKE_TAGS_FAIL=1 run "$CI" purge; [ "$status" -eq 1 ]
  FAKE_WORKLOADS_FAIL=1 run "$CI" purge; [ "$status" -eq 1 ]
  [[ "$output" == *"cannot list preview workloads; deleting nothing"* ]] || false
  FAKE_WORKLOADS_JSON='{bad' run "$CI" purge; [ "$status" -eq 1 ]
  ! grep -q '^acr repository delete' "$AZ_LOG"
}

@test "purge: nothing stale -> 'nothing to purge', exit 0" {
  purge_env
  PURGE_KEEP=10 run "$CI" purge
  [ "$status" -eq 0 ]; [[ "$output" == *"nothing to purge"* ]] || false
  ! grep -q '^acr repository delete' "$AZ_LOG"
}

@test "purge: one delete fails -> others still deleted, run fails" {
  purge_env
  PURGE_KEEP=0 FAKE_FAIL='todo:ccccccc' run "$CI" purge
  [ "$status" -eq 1 ]
  grep -q 'delete -n acr1 --image todo:aaaaaaa' "$AZ_LOG"
  grep -qF 'FAILED to purge `todo:ccccccc`' "$GITHUB_STEP_SUMMARY"
}

@test "purge: config errors -> exit 2, nothing listed" {
  purge_env
  ACR_NAME= run "$CI" purge; [ "$status" -eq 2 ]
  PURGE_MAX_AGE=soon run "$CI" purge; [ "$status" -eq 2 ]
  PURGE_KEEP=-1 run "$CI" purge; [ "$status" -eq 2 ]
  PURGE_DRY_RUN=yes run "$CI" purge; [ "$status" -eq 2 ]
  [ ! -s "$AZ_LOG" ]
}

@test "purge workflow: daily cron + dispatch dry_run, own concurrency, env-only inputs, entrypoint" {
  grep -qx 'name: Purge Stale Preview Images' "$PWF"
  grep -qF -- '- cron: "17 3 * * *"' "$PWF"
  grep -qx '      dry_run:' "$PWF"
  grep -qx '  group: preview-acr-purge' "$PWF"
  grep -qx '    environment: preview' "$PWF"
  grep -qx '          PURGE_DRY_RUN: ${{ inputs.dry_run || false }}' "$PWF"
  grep -qx "          PURGE_MAX_AGE: \${{ inputs.max_age || '7d' }}" "$PWF"
  grep -qx "          PURGE_KEEP: \${{ inputs.keep || '3' }}" "$PWF"
  ! grep -q 'run:.*\${{' "$PWF"
  grep -qx '        run: ./scripts/preview-ci.sh purge' "$PWF"
}
