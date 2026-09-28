#!/usr/bin/env bats
# F003: deploy/preview chart — verbatim to spec + render assertions.

ROOT="$BATS_TEST_DIRNAME/.."
CHART="$ROOT/deploy/preview"
VALUES="$ROOT/tests/fixtures/values.yaml"
HOST=feature-login.preview.example.com

setup() { export PATH="$HOME/go/bin:$PATH"; }

render() { helm template t "$CHART" -f "$VALUES" "$@"; }
only()   { local t="$1"; shift; render --show-only "templates/$t" "$@"; }

@test "spec files are byte-identical to spec Part B" {
  run python3 - "$ROOT" <<'PY'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
spec = (root / ".harness/preview-environments-implementation.md").read_text()
blocks = re.findall(r"### `(deploy/preview/[^`]+)`\n(?:.*?\n)*?```yaml\n(.*?)```", spec, re.S)
assert len(blocks) == 9, f"expected 9 spec blocks, got {len(blocks)}"
bad = [p for p, body in blocks if (root / p).read_text() != body]
if bad: sys.exit("drift from spec: " + ", ".join(bad))
PY
  [ "$status" -eq 0 ] || { echo "$output"; false; }
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
