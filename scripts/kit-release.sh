#!/usr/bin/env bash
# Kit releases (F021, DEC-051). The kit = kit/action.yml + .github/workflows/kit-*.yml + scripts/ + deploy/preview,
# versioned as one semver (kit/VERSION); consumers pin `…/kit-deploy.yml@vX.Y.Z` (full tags, DEC-035).
# Usage: scripts/kit-release.sh prepare X.Y.Z   -- bump VERSION, kit_ref defaults, chart version, consumer example
#        scripts/kit-release.sh verify            -- TAG (vX.Y.Z) matches every pinned place   (env: TAG)
#        scripts/kit-release.sh publish-chart     -- helm package + push to oci://<ACR>/helm    (env: ACR_NAME ACR_LOGIN_SERVER)
#        scripts/kit-release.sh github-release    -- GitHub release for TAG                     (env: TAG GH_TOKEN)
# Options: --root DIR (tests). Exit: 0 ok, 1 failed check, 2 usage.
set -euo pipefail

log() { printf '[%s] kit-release: %s\n' "$1" "$2" >&2; }
root="$(cd "$(dirname "$0")/.." && pwd)"
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --root) [ $# -ge 2 ] || { log error "--root needs a directory"; exit 2; }; root="$(cd "$2" && pwd)"; shift 2 ;;
    *) args+=("$1"); shift ;;
  esac
done
set -- ${args[@]+"${args[@]}"}
cd "$root"

semver_re='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
kit_wfs=(.github/workflows/kit-deploy.yml .github/workflows/kit-destroy.yml .github/workflows/kit-reap.yml .github/workflows/kit-purge.yml)
examples=(examples/consumer/.github/workflows/*.yml)

# kit_ref_defaults -> one "file: vX.Y.Z" line per kit workflow (the default of its kit_ref input)
kit_ref_defaults() {
  local f
  for f in "${kit_wfs[@]}"; do printf '%s: %s\n' "$f" "$(yq -r '.on.workflow_call.inputs.kit_ref.default' "$f")"; done
}

cmd_prepare() {
  local v="${1-}" f
  [[ "$v" =~ $semver_re ]] || { log error "version must be X.Y.Z: '${v}'"; exit 2; }
  printf '%s\n' "$v" >kit/VERSION
  for f in "${kit_wfs[@]}"; do
    yq -i ".on.workflow_call.inputs.kit_ref.default = \"v$v\"" "$f"
  done
  yq -i ".version = \"$v\"" deploy/preview/Chart.yaml
  for f in "${examples[@]}"; do
    sed -E -i.bak "s#(/\.github/workflows/kit-[a-z]+\.yml@)v[0-9]+\.[0-9]+\.[0-9]+#\1v$v#" "$f" && rm -f "$f.bak"
  done
  log info "prepared v$v (commit, merge, then tag v$v on main)"
}

cmd_verify() {
  local tag="${TAG:-}" v bad=0 line
  v=$(tr -d '[:space:]' <kit/VERSION)
  [[ "$v" =~ $semver_re ]] || { log error "kit/VERSION is not X.Y.Z: '$v'"; exit 1; }
  [ "$tag" = "v$v" ] || { log error "tag '$tag' != kit/VERSION v$v"; bad=1; }
  while read -r line; do
    [ "${line##*: }" = "v$v" ] || { log error "kit_ref default mismatch: $line (want v$v)"; bad=1; }
  done < <(kit_ref_defaults)
  [ "$(yq -r .version deploy/preview/Chart.yaml)" = "$v" ] || { log error "Chart.yaml version != $v"; bad=1; }
  if grep -hoE 'kit-[a-z]+\.yml@v[0-9.]+' "${examples[@]}" | grep -v "@v$v\$" >/dev/null; then
    log error "consumer example pins another kit version"; bad=1
  fi
  [ "$bad" -eq 0 ] || exit 1
  log info "v$v consistent (VERSION, kit_ref defaults, chart, example)"
}

cmd_publish_chart() {
  : "${ACR_NAME:?}" "${ACR_LOGIN_SERVER:?}"
  local out token
  out=$(mktemp -d)
  helm package deploy/preview -d "$out" >/dev/null
  token=$(az acr login -n "$ACR_NAME" --expose-token --query accessToken -o tsv)
  helm registry login "$ACR_LOGIN_SERVER" --username 00000000-0000-0000-0000-000000000000 --password-stdin <<<"$token" >/dev/null
  helm push "$out"/preview-*.tgz "oci://$ACR_LOGIN_SERVER/helm"
  log info "pushed chart $(basename "$out"/preview-*.tgz) to oci://$ACR_LOGIN_SERVER/helm"
}

cmd_github_release() {
  : "${TAG:?}"
  local repo="${GITHUB_REPOSITORY:-nimat-dev/ephemeral-environments}" notes
  notes=$(printf '%s\n' "Pin the kit in the consuming repository workflows:" "" '```yaml' "jobs:" "  preview:" \
    "    uses: $repo/.github/workflows/kit-deploy.yml@$TAG" '```' "" \
    "Chart: oci://<acr>/helm/preview --version ${TAG#v}. See examples/consumer/.")
  gh release create "$TAG" --verify-tag --title "Preview kit $TAG" --notes "$notes"
}

case "${1-}" in
  prepare) cmd_prepare "${2-}" ;;
  verify) cmd_verify ;;
  publish-chart) cmd_publish_chart ;;
  github-release) cmd_github_release ;;
  *) sed -n '2,9p' "$0" >&2; exit 2 ;;
esac
