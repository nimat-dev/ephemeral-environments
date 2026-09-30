#!/usr/bin/env bash
# A7: add a project preview domain to this cluster (F017, DEC-040): Azure DNS zone (+ delegation from a
# parent zone in the same RG, or NS records printed for the registrar), wildcard A -> Traefik LB,
# cert-manager DNS-01 rights on the zone, a ClusterIssuer + wildcard Certificate for it, and the cert
# added to Traefik's default TLSStore so SNI serves it. Idempotent.
# Usage: bootstrap/a7-project-domain.sh --domain D [--parent-zone P] [--apply] [--env FILE]   (default: dry-run)
set -euo pipefail
export SCRIPT_NAME=a7-project-domain
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_common.sh
. "$here/_common.sh"

domain="" parent="" args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --domain) [ $# -ge 2 ] || { log error "--domain needs a value"; exit 2; }; domain="$2"; shift 2 ;;
    --parent-zone) [ $# -ge 2 ] || { log error "--parent-zone needs a value"; exit 2; }; parent="$2"; shift 2 ;;
    *) args+=("$1"); shift ;;
  esac
done
parse_apply_args ${args[@]+"${args[@]}"}
load_env "$env_file"
domain_re='^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$'
[[ "$domain" =~ $domain_re ]] || { log error "--domain must be a lowercase DNS name: '${domain}'"; exit 2; }
if [ -n "$parent" ]; then
  [[ "$parent" =~ $domain_re ]] || { log error "--parent-zone must be a lowercase DNS name: '$parent'"; exit 2; }
  case "$domain" in *".$parent") ;; *) log error "$domain is not under --parent-zone $parent"; exit 2 ;; esac
fi
require_context

UAMI="cert-manager-dns"
CERT_NS=traefik
slug=$(printf '%s' "$domain" | tr '.' '-' | cut -c1-40 | sed -E 's/-+$//')
issuer="letsencrypt-dns-$slug" cert="wildcard-$slug" secret="wildcard-$slug-tls"
az_s() { az "$@" --subscription "$AZ_SUBSCRIPTION_ID"; }

# 1. zone
if az_s network dns zone show -g "$AZ_RESOURCE_GROUP" -n "$domain" -o none 2>/dev/null; then
  log info "skip zone $domain (exists)"
else
  run az network dns zone create -g "$AZ_RESOURCE_GROUP" -n "$domain" --subscription "$AZ_SUBSCRIPTION_ID"
fi
ns=$(az_s network dns zone show -g "$AZ_RESOURCE_GROUP" -n "$domain" --query nameServers -o tsv 2>/dev/null || true)

# 2. delegation
if [ -n "$parent" ]; then
  rel="${domain%."$parent"}"
  cur=$(az_s network dns record-set ns show -g "$AZ_RESOURCE_GROUP" -z "$parent" -n "$rel" --query 'NSRecords[].nsdname' -o tsv 2>/dev/null || true)
  for n in $ns; do
    if grep -qxF "$n" <<<"$cur"; then log info "skip NS $rel.$parent -> $n (exists)"
    else run az network dns record-set ns add-record -g "$AZ_RESOURCE_GROUP" -z "$parent" -n "$rel" -d "$n" --subscription "$AZ_SUBSCRIPTION_ID"; fi
  done
else
  log warn "no --parent-zone: delegate $domain at its registrar with these NS records:"
  for n in ${ns:-<zone-name-servers>}; do echo "NS $domain -> $n"; done
fi

# 3. wildcard A -> Traefik LB
lb_ip=$(kubectl get svc traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
[ -n "$lb_ip" ] || { log error "traefik has no LoadBalancer IP (run a1-ingress.sh --apply)"; exit 1; }
current=$(az_s network dns record-set a show -g "$AZ_RESOURCE_GROUP" -z "$domain" -n '*' --query 'ARecords[].ipv4Address' -o tsv 2>/dev/null || true)
if [ "$current" = "$lb_ip" ]; then log info "skip *.$domain -> $lb_ip (already set)"
else
  for old in $current; do
    run az network dns record-set a remove-record -g "$AZ_RESOURCE_GROUP" -z "$domain" -n '*' \
      --ipv4-address "$old" --keep-empty-record-set --subscription "$AZ_SUBSCRIPTION_ID"
  done
  run az network dns record-set a add-record -g "$AZ_RESOURCE_GROUP" -z "$domain" -n '*' --ipv4-address "$lb_ip" --subscription "$AZ_SUBSCRIPTION_ID"
fi

# 4. cert-manager identity may write TXT records in this zone
client_id=$(az_s identity show -g "$AZ_RESOURCE_GROUP" -n "$UAMI" --query clientId -o tsv 2>/dev/null || true)
principal_id=$(az_s identity show -g "$AZ_RESOURCE_GROUP" -n "$UAMI" --query principalId -o tsv 2>/dev/null || true)
[ -n "$client_id" ] && [ -n "$principal_id" ] || { log error "no identity $UAMI (run a3-cert-manager.sh --apply)"; exit 1; }
zone_id=$(az_s network dns zone show -g "$AZ_RESOURCE_GROUP" -n "$domain" --query id -o tsv 2>/dev/null || echo "<zone-id>")
n=$(az_s role assignment list --assignee "$principal_id" --scope "$zone_id" --role "DNS Zone Contributor" --query 'length(@)' -o tsv 2>/dev/null || echo 0)
if [ "${n:-0}" -ge 1 ]; then log info "skip role DNS Zone Contributor on $domain (assigned)"
else
  run az role assignment create --assignee-object-id "$principal_id" --assignee-principal-type ServicePrincipal \
    --role "DNS Zone Contributor" --scope "$zone_id" --subscription "$AZ_SUBSCRIPTION_ID"
fi

manifests() {
  cat <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: $issuer
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: $issuer-key
    solvers:
      - dns01:
          azureDNS:
            subscriptionID: $AZ_SUBSCRIPTION_ID
            resourceGroupName: $AZ_RESOURCE_GROUP
            hostedZoneName: $domain
            environment: AzurePublicCloud
            managedIdentity:
              clientID: $client_id
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: $cert
  namespace: $CERT_NS
spec:
  secretName: $secret
  issuerRef:
    name: $issuer
    kind: ClusterIssuer
  commonName: "*.$domain"
  dnsNames:
    - "*.$domain"
YAML
}

# 5. issuer + cert, then 6. add the secret to Traefik's default TLSStore (SNI picks it; default cert unchanged)
if [ "$APPLY" -eq 1 ]; then
  manifests | run kubectl apply -f -
  run kubectl wait --for=condition=Ready "certificate/$cert" -n "$CERT_NS" --timeout "${CERT_WAIT:-10m}"
  have=$(kubectl get tlsstore default -n "$CERT_NS" -o json | jq -r --arg s "$secret" '[.spec.certificates[]? | select(.secretName == $s)] | length')
  if [ "$have" -ge 1 ]; then log info "skip TLSStore entry $secret (present)"
  else
    patch=$(jq -cn --arg s "$secret" '{spec: {certificates: [{secretName: $s}]}}')
    if [ "$(kubectl get tlsstore default -n "$CERT_NS" -o json | jq '.spec.certificates | length')" -gt 0 ]; then
      patch=$(jq -cn --arg s "$secret" '[{op: "add", path: "/spec/certificates/-", value: {secretName: $s}}]')
      run kubectl patch tlsstore default -n "$CERT_NS" --type json -p "$patch"
    else
      run kubectl patch tlsstore default -n "$CERT_NS" --type merge -p "$patch"
    fi
  fi
else
  echo "[dry-run] kubectl apply -f - <<EOF"; manifests; echo "EOF"
  echo "[dry-run] kubectl wait --for=condition=Ready certificate/$cert -n $CERT_NS"
  echo "[dry-run] kubectl patch tlsstore default -n $CERT_NS (add certificates[].secretName=$secret)"
fi
echo "DOMAIN=$domain WILDCARD=*.$domain -> $lb_ip CERT=$CERT_NS/$secret"
log info "done"
