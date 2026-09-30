#!/usr/bin/env bash
# A6: GitHub `preview` environment + the variables the preview workflows read (no secrets).
# Needs `gh` authenticated with admin on GH_REPO.
# Usage: bootstrap/a6-github-env.sh [--apply] [--env FILE]   (default: dry-run)
set -euo pipefail
export SCRIPT_NAME=a6-github-env
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_common.sh
. "$here/_common.sh"
parse_apply_args "$@"
load_env "$env_file"
[[ "${GH_REPO:-}" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || { log error "GH_REPO must be owner/repo: ${GH_REPO:-}"; exit 2; }

admin=$(gh api "repos/$GH_REPO" --jq '.permissions.admin' 2>/dev/null || true)
if [ "$admin" != true ]; then
  log error "gh account '$(gh api user --jq .login 2>/dev/null || echo '?')' lacks admin on $GH_REPO (gh auth login / gh auth switch) — BLK-006"
  [ "$APPLY" -eq 1 ] && exit 1
fi

client_id=$(az ad app list --display-name "${GH_APP_NAME:-gh-preview-deployer}" --query '[0].appId' -o tsv 2>/dev/null || true)
[ -n "$client_id" ] || { log error "no Entra app ${GH_APP_NAME:-gh-preview-deployer} (run a5-github-oidc.sh --apply)"; exit 1; }
tenant_id=$(az account show --subscription "$AZ_SUBSCRIPTION_ID" --query tenantId -o tsv)

run gh api -X PUT "repos/$GH_REPO/environments/preview" --silent

vars="AZURE_CLIENT_ID=$client_id
AZURE_TENANT_ID=$tenant_id
AZURE_SUBSCRIPTION_ID=$AZ_SUBSCRIPTION_ID
ACR_NAME=$ACR_NAME
ACR_LOGIN_SERVER=$ACR_NAME.azurecr.io
APP_IMAGE_NAME=${APP_IMAGE_NAME:-todo}
PREVIEW_APP=${PREVIEW_APP:-${APP_IMAGE_NAME:-todo}}
AKS_CLUSTER=$AKS_NAME
AKS_RESOURCE_GROUP=$AZ_RESOURCE_GROUP
PREVIEW_DOMAIN=$DNS_ZONE
INTERCEPTOR_FQDN=keda-add-ons-http-interceptor-proxy.keda.svc.cluster.local
INTERCEPTOR_PORT=8080
INGRESS_CLASS=traefik"
while IFS='=' read -r k v; do
  run gh variable set "$k" --env preview --repo "$GH_REPO" --body "$v"
done <<<"$vars"
log info "done"
