#!/usr/bin/env bash
# A3: cert-manager + DNS-01 via workload identity + wildcard cert for *.<DNS_ZONE>,
# served by Traefik's default TLSStore (secret lives in the traefik namespace).
# Usage: bootstrap/a3-cert-manager.sh [--apply] [--env FILE]   (default: dry-run)
set -euo pipefail
export SCRIPT_NAME=a3-cert-manager
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_common.sh
. "$here/_common.sh"
parse_apply_args "$@"
load_env "$env_file"
load_versions
require_context

UAMI=cert-manager-dns
CERT_NS=traefik
az_s() { az "$@" --subscription "$AZ_SUBSCRIPTION_ID"; }

run helm repo add jetstack https://charts.jetstack.io --force-update
run helm upgrade --install cert-manager jetstack/cert-manager -n cert-manager --create-namespace \
  --version "$CERT_MANAGER_CHART_VERSION" -f "$here/values/cert-manager.yaml" --wait --timeout 5m

# Identity: user-assigned MI, DNS Zone Contributor on the zone, federated to cert-manager's SA.
if ! az_s identity show -g "$AZ_RESOURCE_GROUP" -n "$UAMI" -o none 2>/dev/null; then
  run az identity create -g "$AZ_RESOURCE_GROUP" -n "$UAMI" -l "$AZ_LOCATION" --subscription "$AZ_SUBSCRIPTION_ID"
else log info "skip identity $UAMI (exists)"; fi

client_id=$(az_s identity show -g "$AZ_RESOURCE_GROUP" -n "$UAMI" --query clientId -o tsv 2>/dev/null || echo '<client-id>')
principal_id=$(az_s identity show -g "$AZ_RESOURCE_GROUP" -n "$UAMI" --query principalId -o tsv 2>/dev/null || echo '<principal-id>')
zone_id=$(az_s network dns zone show -g "$AZ_RESOURCE_GROUP" -n "$DNS_ZONE" --query id -o tsv)
issuer=$(az_s aks show -g "$AZ_RESOURCE_GROUP" -n "$AKS_NAME" --query oidcIssuerProfile.issuerUrl -o tsv)

n=$(az_s role assignment list --assignee "$principal_id" --scope "$zone_id" --role "DNS Zone Contributor" --query 'length(@)' -o tsv 2>/dev/null || echo 0)
if [ "${n:-0}" -ge 1 ]; then log info "skip role DNS Zone Contributor (assigned)"
else
  run az role assignment create --assignee-object-id "$principal_id" --assignee-principal-type ServicePrincipal \
    --role "DNS Zone Contributor" --scope "$zone_id" --subscription "$AZ_SUBSCRIPTION_ID"
fi

if az_s identity federated-credential show -g "$AZ_RESOURCE_GROUP" --identity-name "$UAMI" -n cert-manager -o none 2>/dev/null; then
  log info "skip federated credential cert-manager (exists)"
else
  run az identity federated-credential create -g "$AZ_RESOURCE_GROUP" --identity-name "$UAMI" -n cert-manager \
    --issuer "$issuer" --subject system:serviceaccount:cert-manager:cert-manager \
    --audiences api://AzureADTokenExchange --subscription "$AZ_SUBSCRIPTION_ID"
fi

manifests() {
  cat <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-dns-key
    solvers:
      - dns01:
          azureDNS:
            subscriptionID: $AZ_SUBSCRIPTION_ID
            resourceGroupName: $AZ_RESOURCE_GROUP
            hostedZoneName: $DNS_ZONE
            environment: AzurePublicCloud
            managedIdentity:
              clientID: $client_id
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-preview
  namespace: $CERT_NS
spec:
  secretName: wildcard-preview-tls
  issuerRef:
    name: letsencrypt-dns
    kind: ClusterIssuer
  commonName: "*.$DNS_ZONE"
  dnsNames:
    - "*.$DNS_ZONE"
---
apiVersion: traefik.io/v1alpha1
kind: TLSStore
metadata:
  name: default
  namespace: $CERT_NS
spec:
  defaultCertificate:
    secretName: wildcard-preview-tls
YAML
}

if [ "$APPLY" -eq 1 ]; then
  run kubectl annotate serviceaccount cert-manager -n cert-manager \
    "azure.workload.identity/client-id=$client_id" --overwrite
  run kubectl rollout restart deployment/cert-manager -n cert-manager
  run kubectl rollout status deployment/cert-manager -n cert-manager --timeout 3m
  manifests | run kubectl apply -f -
  run kubectl wait --for=condition=Ready certificate/wildcard-preview -n "$CERT_NS" --timeout "${CERT_WAIT:-10m}"
else
  printf '[dry-run] kubectl annotate serviceaccount cert-manager -n cert-manager azure.workload.identity/client-id=%s\n' "$client_id"
  echo "[dry-run] kubectl apply -f - <<EOF"; manifests; echo "EOF"
  echo "[dry-run] kubectl wait --for=condition=Ready certificate/wildcard-preview -n $CERT_NS"
fi
log info "done"
