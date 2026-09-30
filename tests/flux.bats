#!/usr/bin/env bats
# F019: clusters/ (Flux GitOps for in-cluster add-ons) — static contract, offline.

ROOT="$BATS_TEST_DIRNAME/.."
REL="$ROOT/clusters/base/releases"

setup() { export PATH="$HOME/go/bin:$PATH"; }

hr() { yq -o=json -I0 "$REL/$1.yaml"; }

@test "HelmRelease chart versions == bootstrap/versions.env pins" {
  # shellcheck disable=SC1091
  . "$ROOT/bootstrap/versions.env"
  [ "$(hr traefik | jq -r .spec.chart.spec.version)" = "$TRAEFIK_CHART_VERSION" ]
  [ "$(hr cert-manager | jq -r .spec.chart.spec.version)" = "$CERT_MANAGER_CHART_VERSION" ]
  [ "$(hr keda | jq -r .spec.chart.spec.version)" = "$KEDA_CHART_VERSION" ]
  [ "$(hr keda-http | jq -r .spec.chart.spec.version)" = "$KEDA_HTTP_CHART_VERSION" ]
}

@test "HelmRelease values == bootstrap/values files (single source for bash + Flux)" {
  for p in traefik:traefik cert-manager:cert-manager keda:keda keda-http:keda-http; do
    f=${p%%:*} v=${p##*:}
    [ "$(hr "$f" | jq -cS .spec.values)" = "$(yq -o=json -I0 "$ROOT/bootstrap/values/$v.yaml" | jq -cS .)" ] || { echo "drift: $f"; return 1; }
  done
}

@test "adoption: releaseName, targetNamespace and storageNamespace match what a1-a4 installed" {
  for p in traefik:traefik:traefik cert-manager:cert-manager:cert-manager keda:keda:keda keda-http:http-add-on:keda; do
    IFS=: read -r f name ns <<<"$p"
    [ "$(hr "$f" | jq -r '[.spec.releaseName, .spec.targetNamespace, .spec.storageNamespace] | join(" ")')" = "$name $ns $ns" ] || { echo "$f"; return 1; }
  done
  grep -q 'helm upgrade --install http-add-on kedacore/keda-add-ons-http -n keda' "$ROOT/bootstrap/a4-keda.sh"
}

@test "http-add-on waits for keda; every release has drift detection with runtime-field ignores" {
  [ "$(hr keda-http | jq -r '.spec.dependsOn[0].name')" = keda ]
  for f in traefik cert-manager keda keda-http; do
    j=$(hr "$f")
    [ "$(jq -r .spec.driftDetection.mode <<<"$j")" = enabled ] || return 1
    [ "$(jq -r '[.spec.driftDetection.ignore[].target.kind] | sort | join(",")' <<<"$j")" = \
      APIService,CustomResourceDefinition,Deployment,MutatingWebhookConfiguration,ValidatingWebhookConfiguration ] || { echo "$f ignores"; return 1; }
  done
}

@test "team overlay builds; objects pass kubeconform; cert-manager gets the workload identity client id" {
  for k in releases config; do
    kubectl kustomize "$ROOT/clusters/nimat/$k" | kubeconform -strict -summary -ignore-missing-schemas
  done
  kubectl kustomize "$ROOT/clusters/nimat/releases" |
    yq -e 'select(.kind == "HelmRelease" and .metadata.name == "cert-manager") | .spec.values.serviceAccount.annotations["azure.workload.identity/client-id"] | test("^[0-9a-f-]{36}$")'
}

@test "config overlay: issuer + wildcard cert per project domain, TLSStore lists every non-default cert" {
  out=$(kubectl kustomize "$ROOT/clusters/nimat/config")
  issuers=$(yq -N 'select(.kind == "ClusterIssuer") | .spec.acme.solvers[0].dns01.azureDNS.hostedZoneName' <<<"$out" | sort | tr '\n' ' ')
  [ "$issuers" = "preview.nimat.dev shop.preview.nimat.dev " ]
  secrets=$(yq -N 'select(.kind == "Certificate") | .spec.secretName' <<<"$out" | sort | tr '\n' ' ')
  [ "$secrets" = "wildcard-preview-tls wildcard-shop-preview-nimat-dev-tls " ]
  [ "$(yq -N 'select(.kind == "TLSStore") | .spec.defaultCertificate.secretName' <<<"$out")" = wildcard-preview-tls ]
  [ "$(yq -N 'select(.kind == "TLSStore") | .spec.certificates[].secretName' <<<"$out")" = wildcard-shop-preview-nimat-dev-tls ]
}

@test "config overlay: ClusterRole identical to a5's; each repo guard confines its SP to preview-<app>-*" {
  a5=$(sed -n '/^rbac_manifest()/,/^YAML$/p' "$ROOT/bootstrap/a5-github-oidc.sh" | sed '1,2d;$d' | yq -o=json -I0 'select(.kind == "ClusterRole")' | jq -cS .)
  [ "$a5" = "$(yq -o=json -I0 '.' "$ROOT/clusters/base/config/clusterrole.yaml" | jq -cS .)" ]
  out=$(kubectl kustomize "$ROOT/clusters/nimat/config")
  for app in $(yq -N '.resources[]' "$ROOT/clusters/nimat/config/repos/kustomization.yaml" | sed 's/\.yaml$//'); do
    sp=$(yq -N "select(.kind == \"ClusterRoleBinding\" and .metadata.name == \"preview-deployer-$app\") | .subjects[0].name" <<<"$out")
    [[ "$sp" =~ ^[0-9a-f-]{36}$ ]] || { echo "no binding for $app"; return 1; }
    vap=$(yq -o=json -I0 "select(.kind == \"ValidatingAdmissionPolicy\" and .metadata.name == \"preview-deployer-guard-$app\")" <<<"$out")
    [ "$(jq -r '.spec.matchConditions[0].expression' <<<"$vap")" = "request.userInfo.username == '$sp'" ]
    [[ "$(jq -r '.spec.validations[0].expression' <<<"$vap")" == *"startsWith('preview-$app-')"* ]] || false
    [ "$(yq -N "select(.kind == \"ValidatingAdmissionPolicyBinding\" and .metadata.name == \"preview-deployer-guard-$app\") | .spec.policyName" <<<"$out")" = "preview-deployer-guard-$app" ]
  done
  ! grep -rq 'preview-deployer-guard$' "$ROOT/clusters/nimat/config"/*.yaml
}
