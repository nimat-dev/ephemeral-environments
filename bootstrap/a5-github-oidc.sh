#!/usr/bin/env bash
# A5: GitHub Actions -> Azure OIDC identity for preview workflows (no secrets).
#  - AKS: Entra ID integration + Azure RBAC (needed for kubelogin); operator gets RBAC Cluster Admin
#  - Entra app + SP + federated credential repo:<GH_REPO>:environment:preview (+ the repo's
#    immutable-id subject when GitHub issues one)
#  - SP: AcrPush + AcrDelete (ACR; purge of stale preview tags, F011), AKS Cluster User Role (kubeconfig)
#  - k8s ClusterRole `preview-deployer` bound to the SP (spec's RBAC Writer can't create
#    namespaces, resourcequotas or HTTPScaledObjects — DEC-024); no secrets (DEC-026)
#  - ValidatingAdmissionPolicy `preview-deployer-guard`: SP writes only preview-* (F009), self-verified
# Usage: bootstrap/a5-github-oidc.sh [--apply] [--env FILE]   (default: dry-run)
set -euo pipefail
export SCRIPT_NAME=a5-github-oidc
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_common.sh
. "$here/_common.sh"
parse_apply_args "$@"
load_env "$env_file"
require_context
[[ "${GH_REPO:-}" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || { log error "GH_REPO must be owner/repo: ${GH_REPO:-}"; exit 2; }
GH_APP_NAME="${GH_APP_NAME:-gh-preview-deployer}"
az_s() { az "$@" --subscription "$AZ_SUBSCRIPTION_ID"; }

# ensure_role OBJECT_ID ROLE SCOPE
ensure_role() {
  local n
  n=$(az_s role assignment list --assignee "$1" --role "$2" --scope "$3" --query 'length(@)' -o tsv 2>/dev/null || echo 0)
  if [ "${n:-0}" -ge 1 ]; then log info "skip role '$2' (assigned)"
  else run az role assignment create --assignee-object-id "$1" --assignee-principal-type "${4:-ServicePrincipal}" \
    --role "$2" --scope "$3" --subscription "$AZ_SUBSCRIPTION_ID"; fi
}

aks_id=$(az_s aks show -g "$AZ_RESOURCE_GROUP" -n "$AKS_NAME" --query id -o tsv)
acr_id=$(az_s acr show -g "$AZ_RESOURCE_GROUP" -n "$ACR_NAME" --query id -o tsv)

# 1. Entra ID + Azure RBAC on the cluster
rbac=$(az_s aks show -g "$AZ_RESOURCE_GROUP" -n "$AKS_NAME" --query aadProfile.enableAzureRbac -o tsv 2>/dev/null || true)
if [ "$rbac" = true ]; then log info "skip AKS Entra ID + Azure RBAC (enabled)"
else run az aks update -g "$AZ_RESOURCE_GROUP" -n "$AKS_NAME" --enable-aad --enable-azure-rbac --subscription "$AZ_SUBSCRIPTION_ID"; fi

# 2. operator keeps cluster access
me=$(az ad signed-in-user show --query id -o tsv)
ensure_role "$me" "Azure Kubernetes Service RBAC Cluster Admin" "$aks_id" User
if [ "$APPLY" -eq 1 ]; then
  run az aks get-credentials -g "$AZ_RESOURCE_GROUP" -n "$AKS_NAME" --overwrite-existing --subscription "$AZ_SUBSCRIPTION_ID"
  run kubelogin convert-kubeconfig -l azurecli
  for _ in $(seq 1 "${RBAC_WAIT_TRIES:-30}"); do
    # concrete verb: Azure RBAC webhook answers "unknown" to wildcard can-i
    kubectl auth can-i create namespaces >/dev/null 2>&1 && break
    sleep "${RBAC_WAIT_SECONDS:-10}"
  done
  kubectl auth can-i create namespaces >/dev/null 2>&1 || { log error "operator has no cluster access after role assignment"; exit 1; }
fi

# 3. app registration + service principal + federated credential
app_id=$(az ad app list --display-name "$GH_APP_NAME" --query '[0].appId' -o tsv 2>/dev/null || true)
if [ -n "$app_id" ]; then log info "skip app $GH_APP_NAME (exists: $app_id)"
else
  run az ad app create --display-name "$GH_APP_NAME"
  app_id=$(az ad app list --display-name "$GH_APP_NAME" --query '[0].appId' -o tsv 2>/dev/null || true)
fi
app_id="${app_id:-<app-id>}"
sp_id=$(az ad sp show --id "$app_id" --query id -o tsv 2>/dev/null || true)
if [ -n "$sp_id" ]; then log info "skip service principal (exists)"
else
  run az ad sp create --id "$app_id"
  sp_id=$(az ad sp show --id "$app_id" --query id -o tsv 2>/dev/null || true)
fi
sp_id="${sp_id:-<sp-object-id>}"

# ensure_fic NAME SUBJECT -- create, or update when the stored subject drifted (repo rename/transfer)
ensure_fic() {
  local cur params
  cur=$(az ad app federated-credential list --id "$app_id" --query "[?name=='$1'].subject | [0]" -o tsv 2>/dev/null || true)
  params="{\"name\":\"$1\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"$2\",\"audiences\":[\"api://AzureADTokenExchange\"]}"
  if [ "$cur" = "$2" ]; then log info "skip federated credential $1 (exists)"
  elif [ -n "$cur" ]; then
    log warn "federated credential $1 subject drift: $cur -> $2"
    run az ad app federated-credential update --id "$app_id" --federated-credential-id "$1" --parameters "$params"
  else
    run az ad app federated-credential create --id "$app_id" --parameters "$params"
  fi
}
ensure_fic gh-preview-env "repo:$GH_REPO:environment:preview"
# Repos on GitHub's immutable subject format send repo:<owner>@<id>/<repo>@<id>:... (AADSTS700213
# otherwise). Read the repo's actual prefix and federate it too. A failed lookup is not "legacy":
# skipping the credential would break azure/login, so --apply stops.
if ! prefix=$(gh api "repos/$GH_REPO/actions/oidc/customization/sub" --jq '.sub_claim_prefix // ""' 2>/dev/null); then
  if [ "$APPLY" -eq 1 ]; then
    log error "cannot read OIDC subject prefix for $GH_REPO (gh missing, not logged in, or active account lacks access)"
    exit 1
  fi
  log warn "cannot read OIDC subject prefix for $GH_REPO; --apply will fail until gh can"
  prefix="?"
fi
case "$prefix" in
  "?") ;;
  ""|"repo:$GH_REPO") log info "oidc subject prefix: legacy repo:$GH_REPO" ;;
  *) ensure_fic gh-preview-env-immutable "$prefix:environment:preview" ;;
esac

# 4. Azure roles for the SP
ensure_role "$sp_id" AcrPush "$acr_id"
ensure_role "$sp_id" AcrDelete "$acr_id"
ensure_role "$sp_id" "Azure Kubernetes Service Cluster User Role" "$aks_id"

# 5. Kubernetes RBAC: exactly what preview deploy/destroy/reap touch
rbac_manifest() {
  cat <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: preview-deployer
rules:
  - apiGroups: [""]
    resources: [namespaces]
    verbs: [get, list, watch, create, update, patch, delete]
  # No secrets: cluster-wide read would expose the wildcard TLS key. Helm release state
  # lives in configmaps instead (workflows set HELM_DRIVER=configmap, DEC-026).
  - apiGroups: [""]
    resources: [services, resourcequotas, configmaps]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: [""]
    resources: [pods, events]
    verbs: [get, list, watch]
  - apiGroups: [apps]
    resources: [deployments, replicasets]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: [networking.k8s.io]
    resources: [ingresses]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: [http.keda.sh]
    resources: [httpscaledobjects]
    verbs: [get, list, watch, create, update, patch, delete]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: preview-deployer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: preview-deployer
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: $sp_id
---
# The ClusterRole is cluster-wide; this confines the SP's writes to preview-* (F009). Matched
# only for the SP, so operators/controllers are unaffected. Auth reviews stay allowed (can-i).
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: preview-deployer-guard
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: ["*"]
        apiVersions: ["*"]
        operations: [CREATE, UPDATE, DELETE, CONNECT]
        resources: ["*/*"]
    excludeResourceRules:
      - apiGroups: [authorization.k8s.io, authentication.k8s.io]
        apiVersions: ["*"]
        operations: [CREATE]
        resources: ["*"]
  matchConditions:
    - name: ci-identity
      expression: request.userInfo.username == '$sp_id'
  validations:
    - expression: >-
        request.resource.group == '' && request.resource.resource == 'namespaces'
        ? request.name.startsWith('preview-')
        : request.namespace.startsWith('preview-')
      messageExpression: >-
        'preview-deployer-guard: CI identity may only write preview-* namespaces (' +
        request.resource.resource + ' ' + request.namespace + '/' + request.name + ')'
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: preview-deployer-guard
spec:
  policyName: preview-deployer-guard
  validationActions: [Deny]
YAML
}

# guard_probe EXPECT ARGS... -- server-side dry-run as the SP; EXPECT allow|guard|rbac. A denial
# must come from the named layer, not an unrelated error (e.g. NotFound, immortal namespace).
# Probes only touch objects that always exist (default) or never need to (AlreadyExists = allowed).
guard_probe() {
  local expect=$1 out rc; shift
  out=$(kubectl "$@" --as="$sp_id" --dry-run=server 2>&1) && rc=0 || rc=$?
  case "$expect:$rc" in
    allow:0) return 0 ;;
    allow:*) [[ "$out" == *AlreadyExists* || "$out" == *"already exists"* ]] && return 0
             log error "guard: denied but must be allowed: kubectl $*: $out"; return 1 ;;
    guard:0|rbac:0) log error "guard: allowed but must be denied: kubectl $*"; return 1 ;;
    guard:*) [[ "$out" == *preview-deployer-guard* ]] && return 0
             log error "guard: unexpected error for kubectl $*: $out"; return 1 ;;
    rbac:*) [[ "$out" == *forbidden* && "$out" != *preview-deployer-guard* ]] && return 0
            log error "guard: unexpected error for kubectl $*: $out"; return 1 ;;
    *) log error "guard: denied but must be allowed: kubectl $*: $out"; return 1 ;;
  esac
}
verify_guard() {
  guard_probe allow create namespace preview-guard-probe &&
  guard_probe guard create namespace guard-probe &&
  guard_probe guard create namespace previewguard-probe &&
  guard_probe guard create configmap guard-probe -n kube-system --from-literal=a=b &&
  guard_probe rbac create secret generic guard-probe -n kube-system --from-literal=a=b &&
  guard_probe guard create deployment guard-probe -n default --image=guard-probe &&
  guard_probe guard label namespace default preview-guard-probe=1   # namespace UPDATE; default always exists
}

if [ "$APPLY" -eq 1 ]; then
  rbac_manifest | run kubectl apply -f -
  ok=0
  for _ in $(seq 1 "${GUARD_WAIT_TRIES:-12}"); do   # policy takes a few seconds to load
    if verify_guard 2>/dev/null; then ok=1; break; fi
    sleep "${GUARD_WAIT_SECONDS:-5}"
  done
  [ "$ok" -eq 1 ] || { verify_guard || true; log error "preview-deployer-guard not effective"; exit 1; }
  log info "guard verified: SP writes confined to preview-* namespaces"
else echo "[dry-run] kubectl apply -f - <<EOF"; rbac_manifest; echo "EOF"; fi

echo "AZURE_CLIENT_ID=$app_id"
echo "AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)"
echo "AZURE_SUBSCRIPTION_ID=$AZ_SUBSCRIPTION_ID"
log info "done"
