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
