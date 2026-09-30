#!/usr/bin/env bats
# F003/F016: deploy/preview chart — legacy render golden + component render assertions.

ROOT="$BATS_TEST_DIRNAME/.."
CHART="$ROOT/deploy/preview"
VALUES="$ROOT/tests/fixtures/values.yaml"
HOST=feature-login.preview.example.com

setup() { export PATH="$HOME/go/bin:$PATH"; }

render() { helm template t "$CHART" -f "$VALUES" "$@"; }
only()   { local t="$1"; shift; render --show-only "templates/$t" "$@"; }

@test "legacy (no components) render is byte-identical to the pre-F016 chart (golden, DEC-044)" {
  diff <(render) "$ROOT/tests/fixtures/legacy-render.yaml"
}

@test "helm lint passes" {
  run helm lint "$CHART"
  [ "$status" -eq 0 ]
}

@test "fixture render passes kubeconform strict" {
  run bash -c "helm template t '$CHART' -f '$VALUES' | kubeconform -strict -summary -ignore-missing-schemas"
  [ "$status" -eq 0 ]; [[ "$output" == *"Invalid: 0, Errors: 0"* ]] || false
}

@test "no Namespace rendered" {
  [ "$(render | grep -cE '^kind: Namespace' || true)" -eq 0 ]
}

@test "Deployment has no replicas field; image is repo:tag" {
  out=$(only deployment.yaml)
  [ "$(grep -cE '^[[:space:]]*replicas:' <<<"$out" || true)" -eq 0 ]
  grep -q 'image: "example.azurecr.io/todo:abc1234"' <<<"$out"
}

@test "Ingress routes host to interceptor and preserves Host" {
  out=$(only ingress.yaml)
  grep -q "host: \"$HOST\"" <<<"$out"
  grep -q "upstream-vhost: \"$HOST\"" <<<"$out"
  grep -q 'name: keda-http-interceptor' <<<"$out"
  grep -q 'number: 8080' <<<"$out"
}

@test "Ingress has no secretName (nginx default wildcard cert)" {
  [ "$(only ingress.yaml | grep -c 'secretName:' || true)" -eq 0 ]
}

@test "HTTPScaledObject: host, idle timeout, replica bounds" {
  out=$(only httpscaledobject.yaml)
  grep -qe "- \"$HOST\"" <<<"$out"
  grep -q 'scaledownPeriod: 1800' <<<"$out"
  grep -q 'min: 0' <<<"$out"
  grep -q 'max: 3' <<<"$out"
}

@test "never idle timeout renders as integer" {
  only httpscaledobject.yaml --set idleTimeoutSeconds=31536000 | grep -q 'scaledownPeriod: 31536000'
}

@test "overrides: interceptor fqdn/port and max replicas" {
  out=$(render --set interceptor.fqdn=icp.keda.svc.cluster.local --set interceptor.port=9090 --set replicas.max=5)
  grep -q 'externalName: icp.keda.svc.cluster.local' <<<"$out"
  grep -q 'number: 9090' <<<"$out"
  grep -q 'max: 5' <<<"$out"
}

@test "ResourceQuota from values" {
  out=$(only resourcequota.yaml)
  grep -q 'requests.cpu: "2"' <<<"$out"
  grep -q 'pods: "6"' <<<"$out"
}

@test "name exactly 50 kept" {
  n=$(printf 'a%.0s' {1..50})
  only service.yaml --set name="$n" | grep -q "^  name: $n$"
}

@test "name > 50 truncated, trailing '-' trimmed" {
  n="$(printf 'a%.0s' {1..49})-bbbb"
  only service.yaml --set name="$n" | grep -q "^  name: $(printf 'a%.0s' {1..49})$"
}

@test "missing host fails render" {
  run helm template t "$CHART" -f "$VALUES" --set host=
  [ "$status" -ne 0 ]; [[ "$output" == *"host is required"* ]] || false
}

@test "missing image.repository fails render" {
  run helm template t "$CHART" -f "$VALUES" --set image.repository=
  [ "$status" -ne 0 ]; [[ "$output" == *"image.repository is required"* ]] || false
}

@test "missing image.tag fails render" {
  run helm template t "$CHART" -f "$VALUES" --set image.tag=
  [ "$status" -ne 0 ]; [[ "$output" == *"image.tag is required"* ]] || false
}

# --- F016 components ---
COMP="$ROOT/tests/fixtures/components.yaml"
crender() { helm template t "$CHART" -f "$COMP" "$@"; }
kinds() { crender | yq -N '.kind + "/" + .metadata.name' | sort; }

@test "components: one Deployment/Service/HSO per component + one Ingress, kubeconform strict" {
  [ "$(kinds | tr '\n' ' ')" = "Deployment/feature-login-api Deployment/feature-login-web HTTPScaledObject/feature-login-api HTTPScaledObject/feature-login-web Ingress/feature-login ResourceQuota/preview-quota Service/feature-login-api Service/feature-login-web Service/keda-http-interceptor " ]
  crender | kubeconform -strict -summary -ignore-missing-schemas
}

@test "components: image, port, probe, selector per component; resources merged over defaults" {
  d=$(crender --show-only templates/deployment.yaml | yq -o=json -I0 'select(.metadata.name == "feature-login-api")')
  [ "$(jq -r '.spec.template.spec.containers[0].image' <<<"$d")" = example.azurecr.io/todo/api:abc1234 ]
  [ "$(jq -r '.spec.template.spec.containers[0].ports[0].containerPort' <<<"$d")" = 3000 ]
  [ "$(jq -r '.spec.template.spec.containers[0].readinessProbe.httpGet.path' <<<"$d")" = /api/health ]
  [ "$(jq -r '.spec.selector.matchLabels["app.kubernetes.io/name"]' <<<"$d")" = feature-login-api ]
  [ "$(jq -cS '.spec.template.spec.containers[0].resources' <<<"$d")" = '{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"250m","memory":"128Mi"}}' ]
  s=$(crender --show-only templates/service.yaml | yq -o=json -I0 'select(.metadata.name == "feature-login-api")')
  [ "$(jq -r '.spec.ports[0].targetPort' <<<"$s")" = 3000 ]
}

@test "components: HSO routes host + path prefix; legacy HSO has no pathPrefixes" {
  h=$(crender --show-only templates/httpscaledobject.yaml | yq -o=json -I0 'select(.metadata.name == "feature-login-api")')
  [ "$(jq -c '.spec.pathPrefixes' <<<"$h")" = '["/api"]' ]
  [ "$(jq -c '.spec.hosts' <<<"$h")" = '["feature-login.preview.example.com"]' ]
  [ "$(jq -r '.spec.scaleTargetRef.service' <<<"$h")" = feature-login-api ]
  [ -z "$(render --show-only templates/httpscaledobject.yaml | grep pathPrefixes)" ]
}

@test "components: ingress keeps a single / path to the interceptor" {
  i=$(crender --show-only templates/ingress.yaml | yq -o=json -I0 .)
  [ "$(jq -c '[.spec.rules[0].http.paths[] | .path + ">" + .backend.service.name]' <<<"$i")" = '["/>keda-http-interceptor"]' ]
}

@test "components: missing component image fails render; long release name keeps names <= 63" {
  run helm template t "$CHART" --set host=h.example --set 'components[0].name=web' --set 'components[0].image.tag=abc1234'
  [ "$status" -ne 0 ]; [[ "$output" == *"components[web].image.repository is required"* ]] || false
  n=$(crender --set name="$(printf 'x%.0s' {1..60})" | yq -N 'select(.kind == "Deployment") | .metadata.name' | awk '{ print length }' | sort -n | tail -1)
  [ "$n" -le 63 ]
}
