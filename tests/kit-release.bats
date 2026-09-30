#!/usr/bin/env bats
# F021: scripts/kit-release.sh (prepare/verify on a temp copy; publish/github-release against fakes)
# + the consumer example stays a thin, pinned caller.

ROOT="$BATS_TEST_DIRNAME/.."
KR="$ROOT/scripts/kit-release.sh"

setup() {
  T="$(mktemp -d)"
  export PATH="$ROOT/tests/fakes:$HOME/go/bin:$PATH"
  export AZ_LOG="$T/az.log" HELM_LOG="$T/helm.log" GH_LOG="$T/gh.log"; : >"$AZ_LOG"; : >"$HELM_LOG"; : >"$GH_LOG"
  C="$T/repo"; mkdir -p "$C/scripts" "$C/.github/workflows" "$C/deploy" "$C/kit" "$C/examples/consumer/.github"
  cp "$KR" "$C/scripts/"
  cp "$ROOT"/.github/workflows/kit-*.yml "$C/.github/workflows/"
  cp -R "$ROOT/deploy/preview" "$C/deploy/"
  cp "$ROOT/kit/VERSION" "$C/kit/"
  cp -R "$ROOT/examples/consumer/.github/workflows" "$C/examples/consumer/.github/"
}
teardown() { rm -rf "$T"; }

@test "repo is consistent for its own kit/VERSION" {
  TAG="v$(cat "$ROOT/kit/VERSION")" run "$KR" verify
  [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "prepare bumps every pinned place; verify accepts only the matching tag" {
  run "$C/scripts/kit-release.sh" prepare 2.3.4
  [ "$status" -eq 0 ]
  [ "$(cat "$C/kit/VERSION")" = 2.3.4 ]
  for f in "$C"/.github/workflows/kit-{deploy,destroy,reap,purge}.yml; do
    [ "$(yq -r '.on.workflow_call.inputs.kit_ref.default' "$f")" = v2.3.4 ] || { echo "$f"; return 1; }
  done
  [ "$(yq -r .version "$C/deploy/preview/Chart.yaml")" = 2.3.4 ]
  [ "$(grep -ohE 'kit-[a-z]+\.yml@v[0-9.]+' "$C"/examples/consumer/.github/workflows/*.yml | sort -u | sed 's/.*@//' | uniq)" = v2.3.4 ]
  TAG=v2.3.4 run "$C/scripts/kit-release.sh" verify; [ "$status" -eq 0 ]
  TAG=v2.3.5 run "$C/scripts/kit-release.sh" verify; [ "$status" -eq 1 ]
  [[ "$output" == *"tag 'v2.3.5' != kit/VERSION v2.3.4"* ]] || false
}

@test "verify catches a single stale pin" {
  "$C/scripts/kit-release.sh" prepare 1.2.0 2>/dev/null
  yq -i '.on.workflow_call.inputs.kit_ref.default = "v1.1.0"' "$C/.github/workflows/kit-reap.yml"
  TAG=v1.2.0 run "$C/scripts/kit-release.sh" verify
  [ "$status" -eq 1 ]; [[ "$output" == *"kit-reap.yml: v1.1.0"* ]] || false
}

@test "prepare rejects non-semver" {
  for v in 1.2 v1.2.3 01.2.3 x ''; do
    run "$C/scripts/kit-release.sh" prepare "$v"
    [ "$status" -eq 2 ] || { echo "want 2 for '$v'"; return 1; }
  done
}

@test "publish-chart: packages the chart, logs into the ACR with a token, pushes to oci://<acr>/helm" {
  cat >"$T/helm" <<'SH'
#!/usr/bin/env bash
echo "$*" >>"$HELM_LOG"
if [ "$1" = package ]; then d=$(sed -E 's/.* -d ([^ ]+).*/\1/' <<<"$*"); touch "$d/preview-1.0.0.tgz"; fi
[ "$1 $2" = "registry login" ] && cat >>"$HELM_LOG.stdin"
exit 0
SH
  chmod +x "$T/helm"
  PATH="$T:$PATH" ACR_NAME=acr1 ACR_LOGIN_SERVER=acr1.azurecr.io run "$KR" --root "$C" publish-chart
  [ "$status" -eq 0 ]
  grep -q '^acr login -n acr1 --expose-token --query accessToken -o tsv' "$AZ_LOG"
  grep -q '^registry login acr1.azurecr.io --username 00000000-0000-0000-0000-000000000000 --password-stdin' "$HELM_LOG"
  grep -qE '^push .*/preview-1.0.0.tgz oci://acr1.azurecr.io/helm$' "$HELM_LOG"
}

@test "github-release: creates the tag's release, verified tag, pin snippet in notes" {
  TAG=v1.0.0 GITHUB_REPOSITORY=acme/kit run "$KR" --root "$C" github-release
  [ "$status" -eq 0 ]
  grep -q '^release create v1.0.0 --verify-tag --title Preview kit v1.0.0 --notes' "$GH_LOG"
  grep -q 'acme/kit/.github/workflows/kit-deploy.yml@v1.0.0' "$GH_LOG"
}

@test "consumer example: thin callers pinned to a full kit tag, only the two job-level permissions" {
  for f in "$ROOT"/examples/consumer/.github/workflows/*.yml; do
    [ "$(yq -r '.permissions | to_entries | map(.key + ":" + .value) | sort | join(",")' "$f")" = 'contents:read,id-token:write' ] || return 1
    [ "$(yq -r '[.jobs[].uses] | map(test("^nimat-dev/ephemeral-environments/\\.github/workflows/kit-[a-z]+\\.yml@v[0-9]+\\.[0-9]+\\.[0-9]+$")) | all' "$f")" = true ] || { echo "$f"; return 1; }
  done
  [ "$(wc -l <"$ROOT/examples/consumer/.github/workflows/preview.yml")" -le 25 ]
  actionlint "$ROOT"/examples/consumer/.github/workflows/*.yml
}

@test "unknown subcommand exits 2" {
  run "$KR" nope; [ "$status" -eq 2 ]
}
