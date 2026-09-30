#!/usr/bin/env bats
# F004: in-cluster bootstrap scripts (A1 Traefik, A4 KEDA) against fake helm/kubectl.

ROOT="$BATS_TEST_DIRNAME/.."
A1="$ROOT/bootstrap/a1-ingress.sh"
A4="$ROOT/bootstrap/a4-keda.sh"

setup() {
  T="$(mktemp -d)"
  export HELM_LOG="$T/helm.log" KUBECTL_LOG="$T/kubectl.log"; : >"$HELM_LOG"; : >"$KUBECTL_LOG"
  export PATH="$ROOT/tests/fakes:$PATH" FAKE_CTX=aks-preview LB_WAIT_SECONDS=0 LB_WAIT_TRIES=2
  ENV="$T/env"; sed 's/^AZ_SUBSCRIPTION_ID=.*/AZ_SUBSCRIPTION_ID=sub-1/' "$ROOT/bootstrap/.env.example" >"$ENV"
}
teardown() { rm -rf "$T"; }

helm_calls() { grep -c . "$HELM_LOG" || true; }

@test "A1 dry-run: plans pinned traefik install, calls no helm" {
  run "$A1" --env "$ENV"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] helm upgrade --install traefik traefik/traefik -n traefik --create-namespace --version 41.6.0"* ]] || false
  [[ "$output" == *"values/traefik.yaml"* ]] || false
  [ "$(helm_calls)" -eq 0 ]
}

@test "A1 apply: installs and prints LB IP" {
  FAKE_LB_IP=20.1.2.3 run "$A1" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  grep -q '^upgrade --install traefik traefik/traefik' "$HELM_LOG"
  [[ "$output" == *"LB_IP=20.1.2.3"* ]] || false
}

@test "A1 apply: no LB IP within timeout fails" {
  FAKE_LB_IP= run "$A1" --env "$ENV" --apply
  [ "$status" -eq 1 ]; [[ "$output" == *"no LoadBalancer IP"* ]] || false
}

@test "wrong kube context refuses before any helm call" {
  FAKE_CTX=some-other-cluster run "$A1" --env "$ENV" --apply
  [ "$status" -eq 1 ]; [[ "$output" == *"expected 'aks-preview'"* ]] || false
  FAKE_CTX= run "$A4" --env "$ENV" --apply
  [ "$status" -eq 1 ]
  [ "$(helm_calls)" -eq 0 ]
}

@test "A4 dry-run: plans keda + http add-on at pinned versions" {
  run "$A4" --env "$ENV"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] helm upgrade --install keda kedacore/keda -n keda --create-namespace --version 2.21.0"* ]] || false
  [[ "$output" == *"[dry-run] helm upgrade --install http-add-on kedacore/keda-add-ons-http -n keda --version 0.16.0 -f "*"values/keda-http.yaml"* ]] || false
  [ "$(helm_calls)" -eq 0 ]
}

@test "A4 apply: verifies interceptor proxy service and port" {
  FAKE_ICP_PORT=8080 run "$A4" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"INTERCEPTOR_FQDN=keda-add-ons-http-interceptor-proxy.keda.svc.cluster.local"* ]] || false
  [[ "$output" == *"INTERCEPTOR_PORT=8080"* ]] || false
}

@test "A4 apply: interceptor missing or on another port fails" {
  FAKE_ICP_PORT= run "$A4" --env "$ENV" --apply
  [ "$status" -eq 1 ]; [[ "$output" == *"missing"* ]] || false
  FAKE_ICP_PORT=9091 run "$A4" --env "$ENV" --apply
  [ "$status" -eq 1 ]; [[ "$output" == *"9091"* ]] || false
}

@test "helm failure mid-way exits non-zero; re-run converges" {
  FAKE_HELM_FAIL="http-add-on" FAKE_ICP_PORT=8080 run "$A4" --env "$ENV" --apply
  [ "$status" -ne 0 ]
  FAKE_ICP_PORT=8080 run "$A4" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  [ "$(grep -c 'upgrade --install http-add-on' "$HELM_LOG")" -eq 2 ]
}

@test "missing versions file exits 2" {
  VERSIONS_FILE="$T/none" run "$A1" --env "$ENV"
  [ "$status" -eq 2 ]
}

@test "unknown argument exits 2" {
  run "$A1" --bogus; [ "$status" -eq 2 ]
  run "$A4" --bogus; [ "$status" -eq 2 ]
}

# --- A2 wildcard DNS ---
A2="$ROOT/bootstrap/a2-wildcard-dns.sh"
A3="$ROOT/bootstrap/a3-cert-manager.sh"
setup_az() { export AZ_LOG="$T/az.log" GH_LOG="$T/gh.log" FAKE_GUARD=1 GUARD_WAIT_SECONDS=0; : >"$AZ_LOG"; : >"$GH_LOG"; }

@test "A2: no record -> add wildcard to LB IP" {
  setup_az
  FAKE_LB_IP=20.1.2.3 run "$A2" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  grep -q "^network dns record-set a add-record .* -n \* --ipv4-address 20.1.2.3" "$AZ_LOG"
  [[ "$output" == *"WILDCARD=*.preview.nimat.dev -> 20.1.2.3"* ]] || false
}

@test "A2: record already correct -> skip" {
  setup_az
  FAKE_LB_IP=20.1.2.3 FAKE_A_IPS=20.1.2.3 run "$A2" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  [ "$(grep -cE 'add-record|remove-record' "$AZ_LOG" || true)" -eq 0 ]
}

@test "A2: stale IP -> removed, new added" {
  setup_az
  FAKE_LB_IP=20.1.2.3 FAKE_A_IPS=9.9.9.9 run "$A2" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  grep -q 'remove-record .* --ipv4-address 9.9.9.9' "$AZ_LOG"
  grep -q 'add-record .* --ipv4-address 20.1.2.3' "$AZ_LOG"
}

@test "A2: no LB IP fails before touching DNS" {
  setup_az
  FAKE_LB_IP= run "$A2" --env "$ENV" --apply
  [ "$status" -eq 1 ]
  [ "$(grep -c 'record-set' "$AZ_LOG" || true)" -eq 0 ]
}

@test "A2 dry-run: no DNS mutation" {
  setup_az
  FAKE_LB_IP=20.1.2.3 run "$A2" --env "$ENV"
  [[ "$output" == *"[dry-run] az network dns record-set a add-record"* ]] || false
  [ "$(grep -cE 'add-record|remove-record' "$AZ_LOG" || true)" -eq 0 ]
}

# --- A3 cert-manager ---
@test "A3 dry-run: plans install, identity, role, federation, manifests; mutates nothing" {
  setup_az
  FAKE_EXISTS="zone aks" run "$A3" --env "$ENV"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] helm upgrade --install cert-manager jetstack/cert-manager"*"--version v1.21.2"* ]] || false
  [[ "$output" == *"[dry-run] az identity create"* ]] || false
  [[ "$output" == *"[dry-run] az role assignment create"*"DNS Zone Contributor"* ]] || false
  [[ "$output" == *"[dry-run] az identity federated-credential create"*"system:serviceaccount:cert-manager:cert-manager"* ]] || false
  [[ "$output" == *'commonName: "*.preview.nimat.dev"'* ]] || false
  [[ "$output" == *"kind: TLSStore"* ]] || false
  [ "$(grep -cE ' create | assignment create' "$AZ_LOG" || true)" -eq 0 ]
  [ "$(grep -c . "$HELM_LOG" || true)" -eq 0 ]
}

@test "A3 apply: manifests use MI client id, zone, no ACME email; waits for cert" {
  setup_az
  FAKE_EXISTS="zone aks uami" run "$A3" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  m="$KUBECTL_LOG.apply"
  grep -q 'clientID: cid-123' "$m"
  grep -q 'hostedZoneName: preview.nimat.dev' "$m"
  grep -q 'namespace: traefik' "$m"
  [ "$(grep -c 'email:' "$m" || true)" -eq 0 ]
  grep -q 'annotate serviceaccount cert-manager -n cert-manager azure.workload.identity/client-id=cid-123' "$KUBECTL_LOG"
  grep -q 'wait --for=condition=Ready certificate/wildcard-preview' "$KUBECTL_LOG"
}

@test "A3 idempotent: identity, role, federation present -> none recreated" {
  setup_az
  FAKE_EXISTS="zone aks uami fic" FAKE_ROLE_COUNT=1 run "$A3" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  [ "$(grep -cE '^identity create|^role assignment create|^identity federated-credential create' "$AZ_LOG" || true)" -eq 0 ]
}

@test "A3: certificate never Ready -> fails" {
  setup_az
  FAKE_EXISTS="zone aks uami fic" FAKE_ROLE_COUNT=1 FAKE_WAIT_FAIL=1 run "$A3" --env "$ENV" --apply
  [ "$status" -ne 0 ]
}

# --- A5 GitHub OIDC ---
A5="$ROOT/bootstrap/a5-github-oidc.sh"
a5_env() { printf 'GH_REPO=nimat-dev/ephemeral-environments\nGH_APP_NAME=gh-preview-deployer\n' >>"$ENV"; }

@test "A5 dry-run: plans AAD/RBAC, identity, roles, k8s RBAC; mutates nothing" {
  setup_az; a5_env
  run "$A5" --env "$ENV"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] az aks update"*"--enable-aad --enable-azure-rbac"* ]] || false
  [[ "$output" == *"[dry-run] az role assignment create --assignee-object-id me-oid --assignee-principal-type User --role Azure Kubernetes Service RBAC Cluster Admin"* ]] || false
  [[ "$output" == *"[dry-run] az ad app create --display-name gh-preview-deployer"* ]] || false
  [[ "$output" == *'"subject":"repo:nimat-dev/ephemeral-environments:environment:preview"'* ]] || false
  [[ "$output" == *"--role AcrPush --scope /acr-id"* ]] || false
  [[ "$output" == *"--role AcrDelete --scope /acr-id"* ]] || false
  [[ "$output" == *"--role Azure Kubernetes Service Cluster User Role --scope /aks-id"* ]] || false
  [[ "$output" == *"kind: ClusterRole"* ]] || false
  [ "$(grep -cE ' create | update ' "$AZ_LOG" || true)" -eq 0 ]
}

@test "A5: immutable OIDC subject prefix -> second federated credential; legacy -> none" {
  setup_az; a5_env; export GH_LOG="$T/gh.log"; : >"$GH_LOG"
  FAKE_GH_SUB_PREFIX='repo:nimat-dev@1/ephemeral-environments@2' run "$A5" --env "$ENV"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"name":"gh-preview-env-immutable"'*'"subject":"repo:nimat-dev@1/ephemeral-environments@2:environment:preview"'* ]] || false
  FAKE_GH_SUB_PREFIX='repo:nimat-dev/ephemeral-environments' run "$A5" --env "$ENV"
  [ "$status" -eq 0 ]; [[ "$output" != *gh-preview-env-immutable* ]] || false
  FAKE_GH_SUB_PREFIX='' run "$A5" --env "$ENV"
  [ "$status" -eq 0 ]; [[ "$output" != *gh-preview-env-immutable* ]] || false
}

@test "A5: OIDC prefix lookup fails -> --apply exits 1, dry-run warns" {
  setup_az; a5_env
  FAKE_GH_SUB_FAIL=1 FAKE_EXISTS="app sp ghfic" FAKE_AZURE_RBAC=true FAKE_ROLE_COUNT=1 run "$A5" --env "$ENV" --apply
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot read OIDC subject prefix"* ]] || false
  [[ "$output" != *"legacy"* ]] || false
  FAKE_GH_SUB_FAIL=1 run "$A5" --env "$ENV"
  [ "$status" -eq 0 ]; [[ "$output" == *"[warn]"*"cannot read OIDC subject prefix"* ]] || false
}

@test "A5: federated credential subject drift -> update, not skip" {
  setup_az; a5_env
  FAKE_GH_SUB_PREFIX='repo:nimat-dev@1/ephemeral-environments@2' FAKE_GHFIC_IMM_SUBJECT='repo:old@1/old@2:environment:preview' \
    FAKE_EXISTS="app sp ghfic" FAKE_AZURE_RBAC=true FAKE_ROLE_COUNT=1 run "$A5" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  grep -q 'federated-credential update .*--federated-credential-id gh-preview-env-immutable .*repo:nimat-dev@1/ephemeral-environments@2:environment:preview' "$AZ_LOG"
  [ "$(grep -c 'federated-credential create' "$AZ_LOG" || true)" -eq 0 ]
  [[ "$output" == *"skip federated credential gh-preview-env (exists)"* ]] || false
}

@test "A5: renders preview-deployer-guard VAP keyed on the SP object id (F009)" {
  setup_az; a5_env
  FAKE_EXISTS="app sp" run "$A5" --env "$ENV"
  [ "$status" -eq 0 ]
  [[ "$output" == *"kind: ValidatingAdmissionPolicy"*"name: preview-deployer-guard"* ]] || false
  [[ "$output" == *"expression: request.userInfo.username == 'sp-oid'"* ]] || false
  [[ "$output" == *"? request.name.startsWith('preview-')"*": request.namespace.startsWith('preview-')"* ]] || false
  [[ "$output" == *"kind: ValidatingAdmissionPolicyBinding"*"validationActions: [Deny]"* ]] || false
  [[ "$output" == *"apiGroups: [authorization.k8s.io, authentication.k8s.io]"* ]] || false
  [ "$(grep -c 'dry-run=server' "$KUBECTL_LOG" 2>/dev/null || true)" -eq 0 ]
}

@test "A5 apply: guard effective -> probes as SP pass (preview-* allowed; kube-system, default, foo denied)" {
  setup_az; a5_env
  FAKE_EXISTS="app sp ghfic" FAKE_AZURE_RBAC=true FAKE_ROLE_COUNT=1 run "$A5" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"guard verified"* ]] || false
  grep -q 'kind: ValidatingAdmissionPolicy$' "$KUBECTL_LOG.apply"
  grep -q '^create namespace preview-guard-probe --as=sp-oid --dry-run=server' "$KUBECTL_LOG"
  grep -q '^create configmap guard-probe -n kube-system .*--as=sp-oid --dry-run=server' "$KUBECTL_LOG"
  grep -q '^create secret generic guard-probe -n kube-system .*--as=sp-oid --dry-run=server' "$KUBECTL_LOG"
  grep -q '^create deployment guard-probe -n default .*--as=sp-oid --dry-run=server' "$KUBECTL_LOG"
  grep -q '^label namespace default preview-guard-probe=1 --as=sp-oid --dry-run=server' "$KUBECTL_LOG"
  ! grep -q 'keda' "$KUBECTL_LOG"
  grep -q '^create namespace previewguard-probe --as=sp-oid --dry-run=server' "$KUBECTL_LOG"
}

@test "A5 apply: probe namespace already exists -> still allowed, guard verified" {
  setup_az; a5_env
  FAKE_PROBE_NS_EXISTS=1 FAKE_EXISTS="app sp ghfic" FAKE_AZURE_RBAC=true FAKE_ROLE_COUNT=1 run "$A5" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"guard verified"* ]] || false
}

@test "A5 apply: guard not effective (permissive) -> exit 1 after retries" {
  setup_az; a5_env
  FAKE_GUARD= GUARD_WAIT_TRIES=2 FAKE_EXISTS="app sp ghfic" FAKE_AZURE_RBAC=true FAKE_ROLE_COUNT=1 \
    run "$A5" --env "$ENV" --apply
  [ "$status" -eq 1 ]
  [[ "$output" == *"allowed but must be denied: kubectl create namespace guard-probe"* ]] || false
  [[ "$output" == *"preview-deployer-guard not effective"* ]] || false
}

@test "A5: spec's RBAC Writer is not granted; ClusterRole covers what deploy creates" {
  setup_az; a5_env
  run "$A5" --env "$ENV"
  [[ "$output" != *"RBAC Writer"* ]] || false
  for r in namespaces resourcequotas httpscaledobjects deployments ingresses services configmaps; do
    [[ "$output" == *"$r"* ]] || { echo "missing $r"; false; }
  done
}

@test "A5: ClusterRole never grants secrets (helm uses configmap driver, DEC-026)" {
  setup_az; a5_env
  run "$A5" --env "$ENV"
  [ "$status" -eq 0 ]
  [ "$(grep -cE '^ *resources:.*secrets' <<<"$output" || true)" -eq 0 ]
}

@test "A5 apply: converts kubeconfig and binds ClusterRole to the SP object id" {
  setup_az; a5_env
  FAKE_EXISTS="app sp" run "$A5" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  grep -q '^kubelogin convert-kubeconfig -l azurecli' "$KUBECTL_LOG"
  grep -q 'name: sp-oid' "$KUBECTL_LOG.apply"
  [[ "$output" == *"AZURE_CLIENT_ID=app-123"* ]] || false
}

@test "A5 idempotent: everything present -> no creates" {
  setup_az; a5_env
  FAKE_EXISTS="app sp ghfic" FAKE_AZURE_RBAC=true FAKE_ROLE_COUNT=1 run "$A5" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  [ "$(grep -cE '^ad app create|^ad sp create|federated-credential create|^role assignment create|^aks update' "$AZ_LOG" || true)" -eq 0 ]
}

@test "A5: operator without cluster access after role assignment fails" {
  setup_az; a5_env
  FAKE_EXISTS="app sp" FAKE_CANI_FAIL=1 RBAC_WAIT_TRIES=1 RBAC_WAIT_SECONDS=0 run "$A5" --env "$ENV" --apply
  [ "$status" -eq 1 ]; [[ "$output" == *"no cluster access"* ]] || false
}

@test "A5: invalid GH_REPO exits 2" {
  setup_az; printf 'GH_REPO=not-a-repo\n' >>"$ENV"
  run "$A5" --env "$ENV"
  [ "$status" -eq 2 ]
}

# --- A6 GitHub environment ---
A6="$ROOT/bootstrap/a6-github-env.sh"

@test "A6 apply: creates env and all workflow variables" {
  setup_az; a5_env; export GH_LOG="$T/gh.log"; : >"$GH_LOG"
  FAKE_EXISTS=app FAKE_GH_ADMIN=true run "$A6" --env "$ENV" --apply
  [ "$status" -eq 0 ]
  grep -q '^api -X PUT repos/nimat-dev/ephemeral-environments/environments/preview' "$GH_LOG"
  for k in AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID ACR_NAME ACR_LOGIN_SERVER APP_IMAGE_NAME \
           AKS_CLUSTER AKS_RESOURCE_GROUP PREVIEW_DOMAIN INTERCEPTOR_FQDN INTERCEPTOR_PORT INGRESS_CLASS PREVIEW_APP; do
    grep -q "^variable set $k --env preview" "$GH_LOG" || { echo "missing $k"; false; }
  done
  grep -q 'variable set AZURE_CLIENT_ID .* --body app-123' "$GH_LOG"
  grep -q 'variable set INGRESS_CLASS .* --body traefik' "$GH_LOG"
  [ "$(grep -c secret "$GH_LOG" || true)" -eq 0 ]
}

@test "A6: no repo admin -> apply refuses, dry-run warns" {
  setup_az; a5_env; export GH_LOG="$T/gh.log"; : >"$GH_LOG"
  FAKE_EXISTS=app FAKE_GH_ADMIN=false run "$A6" --env "$ENV" --apply
  [ "$status" -eq 1 ]; [[ "$output" == *"lacks admin"* ]] || false
  [ "$(grep -c 'variable set' "$GH_LOG" || true)" -eq 0 ]
  FAKE_EXISTS=app FAKE_GH_ADMIN=false run "$A6" --env "$ENV"
  [ "$status" -eq 0 ]
}

@test "A6: missing Entra app fails" {
  setup_az; a5_env; export GH_LOG="$T/gh.log"; : >"$GH_LOG"
  FAKE_GH_ADMIN=true run "$A6" --env "$ENV" --apply
  [ "$status" -eq 1 ]; [[ "$output" == *"no Entra app"* ]] || false
}
