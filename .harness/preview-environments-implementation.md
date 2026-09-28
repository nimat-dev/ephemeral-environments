# Branch Preview Environments on AKS — Implementation Spec

Ephemeral per-branch preview environments on AKS with **idle scale-to-zero** and **wake-on-request**, driven by a GitHub Actions `workflow_dispatch`. Hand this to your coding harness; every file below is meant to be written verbatim, then wired per the build order in Part E.

---

## How your requirements map

| Your requirement | Mechanism in this design |
|---|---|
| Deploy a custom branch via dispatch | `preview-deploy.yml`, `workflow_dispatch` with a `branch` input |
| Build image, push to ACR, tag with hash | `docker/build-push-action`, tag = short Git SHA |
| Run k8s config, deploy to AKS | Helm chart `deploy/preview`, `helm upgrade --install -n preview-<id>` |
| Custom URL per branch | `https://<sanitized-branch>.preview.alleghenycounty.us`, single wildcard cert + wildcard DNS |
| Replicas → 0 after idle (24h/48h/1w, customizable) | Split into two knobs (see below): **idle timeout** (KEDA `scaledownPeriod`) and **lifetime** (scheduled namespace delete) |
| Hit URL again → scale back up | KEDA HTTP add-on interceptor: holds the request, scales 0→1, forwards |
| Easy via dispatch, URL surfaced | Typed dispatch inputs + URL written to the job summary |

**On "replicas become zero after 24h/48h/1week":** that conflates two different things, so this design gives you two independent controls:

- **Idle timeout** — no traffic for N minutes/hours → KEDA scales the Deployment to 0. Hitting the URL wakes it. This is the scale-to-zero loop.
- **Lifetime** — after 24h/48h/7d (or custom) the whole namespace is deleted regardless of traffic. This is teardown; the URL 404s afterward and you redeploy.

Your "become zero after 24h/48h/1w" is really the **lifetime** knob; the idle timeout is what produces the sleep/wake behavior while the preview is alive. If you genuinely want a hard "force to 0 at exactly T but keep it wakeable," that's an optional one-shot CronJob — noted at the end, not built by default.

---

## Final architecture (decisions locked)

```
Developer
  │  workflow_dispatch (branch, lifetime, idle_timeout, max_replicas)
  ▼
GitHub Actions ──OIDC──► Azure (no stored secrets)
  ├─ checkout <branch>
  ├─ docker build → push  ACR/<app>:<short-sha>
  ├─ kubectl apply namespace  (labels: expires-at, branch, commit)
  ├─ helm upgrade --install  → Deployment, Service, HTTPScaledObject, ExternalName, Ingress, ResourceQuota
  └─ verify: curl the URL (cold-start proof) → write URL to job summary

Request path when live:
  Browser → nginx Ingress → ExternalName(svc) → KEDA HTTP interceptor (keda ns)
          → app Service → pod   (interceptor scales 0→1 and holds the request if asleep)

Wildcard, created once:
  *.preview.alleghenycounty.us  A  → nginx LoadBalancer IP
  *.preview.alleghenycounty.us  TLS → cert-manager (DNS-01), set as nginx default cert
```

**Three assumptions — flip in Part A / values if wrong:**

1. **Scale engine = KEDA HTTP add-on.** Alternative: Knative Serving (request-driven scale-to-zero is its core purpose, but it's a heavier platform that wants to own routing). If you'd rather go Knative, the workflows and DNS/TLS stay; only the chart's `httpscaledobject.yaml` + interceptor wiring change to a Knative `Service`.
2. **One preview per branch** (stable, shareable URL; redeploys roll into the same Deployment). If you need multiple concurrent commits of one branch live at once, set `previewId = <branch>-<short-sha>` in the deploy workflow (one-line change, flagged inline).
3. **`alleghenycounty.us` is in Azure DNS** and the cluster can write a wildcard record + solve DNS-01. If DNS lives elsewhere (Cloudflare/Route53), swap the cert-manager solver and create the wildcard A record in that provider — everything else is unchanged.

---

## Prerequisites

- AKS Standard (or Automatic) cluster, `kubectl` + `helm` reachable.
- An ACR.
- Ability to create an Azure App Registration (or user-assigned managed identity) with a federated credential.
- Control of a `preview.` sub-zone under `alleghenycounty.us` in Azure DNS. **Use a sub-zone, not the county apex** — you almost certainly can't get a wildcard on the apex, and a sub-zone keeps blast radius tiny.

### GitHub repository variables (Settings → Secrets and variables → Actions → Variables)

No long-lived secrets — OIDC only.

| Variable | Example |
|---|---|
| `AZURE_CLIENT_ID` | app registration / UAMI client id |
| `AZURE_TENANT_ID` | tenant id |
| `AZURE_SUBSCRIPTION_ID` | subscription id |
| `ACR_NAME` | `mycountyacr` |
| `ACR_LOGIN_SERVER` | `mycountyacr.azurecr.io` |
| `APP_IMAGE_NAME` | `myapp` |
| `AKS_CLUSTER` | `myaks` |
| `AKS_RESOURCE_GROUP` | `rg-aks` |
| `PREVIEW_DOMAIN` | `preview.alleghenycounty.us` |
| `INTERCEPTOR_FQDN` | `keda-add-ons-http-interceptor-proxy.keda.svc.cluster.local` |
| `INTERCEPTOR_PORT` | `8080` |

---

## Part A — One-time cluster + Azure bootstrap

Run these once (manually or via a bootstrap script). Not part of the per-preview flow.

### A1. ingress-nginx

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.externalTrafficPolicy=Local

# Grab the public IP once it's provisioned:
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### A2. Wildcard DNS (once)

Point the whole preview sub-zone at the nginx LB IP. After this, **no preview ever touches DNS.**

```bash
LB_IP=<ip-from-A1>
az network dns record-set a add-record \
  --resource-group <dns-rg> \
  --zone-name preview.alleghenycounty.us \
  --record-set-name "*" \
  --ipv4-address "$LB_IP"
```

> If DNS isn't in Azure, you can instead run external-dns to auto-manage records — but with a wildcard A record you don't need it. One record is simpler and has no moving parts.

### A3. cert-manager + wildcard cert (once)

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true
```

Give cert-manager permission to solve DNS-01 on the zone (workload identity path shown; a service-principal secret also works):

```bash
# UAMI federated to cert-manager's SA, with DNS Zone Contributor on the sub-zone.
az identity create -g <dns-rg> -n cert-manager-dns
CM_CLIENT_ID=$(az identity show -g <dns-rg> -n cert-manager-dns --query clientId -o tsv)
CM_OBJ_ID=$(az identity show -g <dns-rg> -n cert-manager-dns --query principalId -o tsv)
ZONE_ID=$(az network dns zone show -g <dns-rg> -n preview.alleghenycounty.us --query id -o tsv)
az role assignment create --assignee-object-id "$CM_OBJ_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "DNS Zone Contributor" --scope "$ZONE_ID"

OIDC_ISSUER=$(az aks show -g <aks-rg> -n <aks> --query oidcIssuerProfile.issuerUrl -o tsv)
az identity federated-credential create \
  --name cert-manager --identity-name cert-manager-dns -g <dns-rg> \
  --issuer "$OIDC_ISSUER" \
  --subject system:serviceaccount:cert-manager:cert-manager \
  --audience api://AzureADTokenExchange
# annotate the cert-manager SA with azure.workload.identity/client-id=$CM_CLIENT_ID
```

`clusterissuer.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: platform@alleghenycounty.us
    privateKeySecretRef:
      name: letsencrypt-dns-key
    solvers:
      - dns01:
          azureDNS:
            subscriptionID: <sub-id>
            resourceGroupName: <dns-rg>
            hostedZoneName: preview.alleghenycounty.us
            environment: AzurePublicCloud
            managedIdentity:
              clientID: <CM_CLIENT_ID>
```

`wildcard-cert.yaml` (issue into the ingress namespace, then make it the controller default):

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-preview
  namespace: ingress-nginx
spec:
  secretName: wildcard-preview-tls
  issuerRef:
    name: letsencrypt-dns
    kind: ClusterIssuer
  commonName: "*.preview.alleghenycounty.us"
  dnsNames:
    - "*.preview.alleghenycounty.us"
```

Set it as the nginx default cert so **every** preview host gets HTTPS with zero per-preview config:

```bash
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --reuse-values \
  --set controller.extraArgs.default-ssl-certificate=ingress-nginx/wildcard-preview-tls
```

### A4. KEDA core + HTTP add-on

Core KEDA — either the AKS managed add-on **or** Helm:

```bash
# Managed (recommended if available). Provides CORE keda only.
az aks update -g <aks-rg> -n <aks> --enable-keda
# OR self-managed:
# helm install keda kedacore/keda -n keda --create-namespace
```

HTTP add-on — **separate install, not covered by the managed add-on**, depends on core KEDA being present:

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm upgrade --install http-add-on kedacore/keda-add-ons-http \
  --namespace keda --create-namespace
```

> **Version caveat (real):** the HTTP add-on is pre-1.0 and its `HTTPScaledObject` schema + the interceptor service name/port have shifted across releases. Pin to a chart version compatible with your KEDA core version, then confirm the interceptor service name/port against your install and update `INTERCEPTOR_FQDN` / `INTERCEPTOR_PORT` if they differ:
> ```bash
> kubectl get svc -n keda | grep interceptor
> ```

### A5. GitHub → Azure OIDC (no secrets)

```bash
# App registration (or reuse a UAMI). Federate to the repo's `preview` environment.
APP_ID=$(az ad app create --display-name gh-preview-deployer --query appId -o tsv)
az ad sp create --id "$APP_ID"
SP_OBJ=$(az ad sp show --id "$APP_ID" --query id -o tsv)

az ad app federated-credential create --id "$APP_ID" --parameters '{
  "name": "gh-preview-env",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<org>/<repo>:environment:preview",
  "audiences": ["api://AzureADTokenExchange"]
}'

# Least privilege: push to ACR, and RBAC-write on the cluster.
ACR_ID=$(az acr show -n <ACR_NAME> --query id -o tsv)
az role assignment create --assignee-object-id "$SP_OBJ" --assignee-principal-type ServicePrincipal \
  --role AcrPush --scope "$ACR_ID"

AKS_ID=$(az aks show -g <aks-rg> -n <aks> --query id -o tsv)
az role assignment create --assignee-object-id "$SP_OBJ" --assignee-principal-type ServicePrincipal \
  --role "Azure Kubernetes Service Cluster User Role" --scope "$AKS_ID"
az role assignment create --assignee-object-id "$SP_OBJ" --assignee-principal-type ServicePrincipal \
  --role "Azure Kubernetes Service RBAC Writer" --scope "$AKS_ID"
```

> **Hardening note:** `RBAC Writer` at cluster scope lets the runner write anywhere. Azure RBAC namespace scoping only supports *exact* namespaces, not a `preview-*` glob, so you can't scope it to preview namespaces via one assignment. Tighter path when you're ready: bind the SP's AAD object to a **Kubernetes** `ClusterRole` limited to the resource types this pipeline touches (namespaces, deployments, services, ingresses, httpscaledobjects, resourcequotas), and drop the Azure RBAC Writer. Start permissive, tighten in Part E step 5.

### A6. Create the `preview` GitHub environment

Settings → Environments → `preview`. Add the repo variables from Prerequisites here (or at repo level). Optional: required reviewers if you want a human gate on preview spin-ups.

---

## Part B — Helm chart

Namespace lifecycle is owned by the **workflow** (it carries the `expires-at` label the reaper reads); Helm owns the workloads inside it. Do not template the Namespace in the chart — it avoids ownership conflicts and keeps the reaper's metadata authoritative.

```
deploy/preview/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── _helpers.tpl
    ├── deployment.yaml
    ├── service.yaml
    ├── interceptor-externalname.yaml
    ├── httpscaledobject.yaml
    ├── ingress.yaml
    └── resourcequota.yaml
```

### `deploy/preview/Chart.yaml`

```yaml
apiVersion: v2
name: preview
description: Ephemeral per-branch preview environment
type: application
version: 0.1.0
appVersion: "1.0.0"
```

### `deploy/preview/values.yaml`

```yaml
# All overridden per-deploy from the workflow via --set.
name: preview            # release name; used as app/deployment/service name
host: ""                 # e.g. branch-123.preview.alleghenycounty.us

image:
  repository: ""         # ACR_LOGIN_SERVER/APP_IMAGE_NAME
  tag: ""                # short git sha
  pullPolicy: IfNotPresent

containerPort: 8080
probePath: /             # set to a real health endpoint if / doesn't 200

replicas:
  min: 0
  max: 3

idleTimeoutSeconds: 1800 # scale to 0 after this much no-traffic (KEDA scaledownPeriod)

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

# One quota per preview namespace so 40 abandoned branches can't eat the cluster.
quota:
  cpu: "2"
  memory: 4Gi
  pods: "6"

interceptor:
  fqdn: keda-add-ons-http-interceptor-proxy.keda.svc.cluster.local
  port: 8080

ingressClassName: nginx
commit: ""
branch: ""
```

### `deploy/preview/templates/_helpers.tpl`

```yaml
{{- define "preview.fullname" -}}
{{- .Values.name | trunc 50 | trimSuffix "-" -}}
{{- end -}}

{{- define "preview.labels" -}}
app.kubernetes.io/name: {{ include "preview.fullname" . }}
app.kubernetes.io/managed-by: helm
preview.commit: {{ .Values.commit | quote }}
{{- end -}}
```

### `deploy/preview/templates/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "preview.fullname" . }}
  labels:
    {{- include "preview.labels" . | nindent 4 }}
  annotations:
    preview.branch: {{ .Values.branch | quote }}
    preview.commit: {{ .Values.commit | quote }}
spec:
  # No replicas field: KEDA owns the replica count. Setting it here fights the autoscaler.
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ include "preview.fullname" . }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ include "preview.fullname" . }}
    spec:
      containers:
        - name: app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.containerPort }}
          readinessProbe:
            httpGet:
              path: {{ .Values.probePath }}
              port: {{ .Values.containerPort }}
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: {{ .Values.probePath }}
              port: {{ .Values.containerPort }}
            initialDelaySeconds: 20
            periodSeconds: 15
            failureThreshold: 4
          resources:
            requests:
              cpu: {{ .Values.resources.requests.cpu }}
              memory: {{ .Values.resources.requests.memory }}
            limits:
              cpu: {{ .Values.resources.limits.cpu }}
              memory: {{ .Values.resources.limits.memory }}
```

### `deploy/preview/templates/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "preview.fullname" . }}
  labels:
    {{- include "preview.labels" . | nindent 4 }}
spec:
  selector:
    app.kubernetes.io/name: {{ include "preview.fullname" . }}
  ports:
    - name: http
      port: 80
      targetPort: {{ .Values.containerPort }}
```

### `deploy/preview/templates/interceptor-externalname.yaml`

Bridges the per-namespace Ingress to the shared interceptor in the `keda` namespace (Ingress backends must be in-namespace; ExternalName is the standard hop).

```yaml
apiVersion: v1
kind: Service
metadata:
  name: keda-http-interceptor
  labels:
    {{- include "preview.labels" . | nindent 4 }}
spec:
  type: ExternalName
  externalName: {{ .Values.interceptor.fqdn }}
  ports:
    - name: proxy
      port: {{ .Values.interceptor.port }}
      targetPort: {{ .Values.interceptor.port }}
```

### `deploy/preview/templates/httpscaledobject.yaml`

The interceptor matches on `hosts`, forwards to `service`, and scales `scaleTargetRef`. `scaledownPeriod` is your idle timeout.

```yaml
apiVersion: http.keda.sh/v1alpha1
kind: HTTPScaledObject
metadata:
  name: {{ include "preview.fullname" . }}
  labels:
    {{- include "preview.labels" . | nindent 4 }}
spec:
  hosts:
    - {{ .Values.host | quote }}
  scaleTargetRef:
    name: {{ include "preview.fullname" . }}
    kind: Deployment
    apiVersion: apps/v1
    service: {{ include "preview.fullname" . }}
    port: 80
  replicas:
    min: {{ .Values.replicas.min }}
    max: {{ .Values.replicas.max }}
  scaledownPeriod: {{ .Values.idleTimeoutSeconds }}
```

> Field names here (`scaleTargetRef.service`/`.port`, `scaledownPeriod`, `replicas.min/max`) track recent add-on versions. If your pinned version rejects them, `kubectl explain httpscaledobject.spec` against your install and adjust — this is the one file most exposed to add-on version drift.

### `deploy/preview/templates/ingress.yaml`

TLS is served by the controller's default wildcard cert (A3), so no per-host `secretName` needed. `upstream-vhost` preserves the original Host so the interceptor can match the `HTTPScaledObject`.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "preview.fullname" . }}
  labels:
    {{- include "preview.labels" . | nindent 4 }}
  annotations:
    nginx.ingress.kubernetes.io/upstream-vhost: {{ .Values.host | quote }}
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: {{ .Values.ingressClassName }}
  rules:
    - host: {{ .Values.host | quote }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: keda-http-interceptor
                port:
                  number: {{ .Values.interceptor.port }}
  tls:
    - hosts:
        - {{ .Values.host | quote }}
      # secretName omitted on purpose: nginx serves its default wildcard cert.
```

### `deploy/preview/templates/resourcequota.yaml`

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: preview-quota
  labels:
    {{- include "preview.labels" . | nindent 4 }}
spec:
  hard:
    requests.cpu: {{ .Values.quota.cpu | quote }}
    requests.memory: {{ .Values.quota.memory | quote }}
    limits.cpu: {{ .Values.quota.cpu | quote }}
    limits.memory: {{ .Values.quota.memory | quote }}
    pods: {{ .Values.quota.pods | quote }}
```

---

## Part C — Manual smoke test (do this before automating)

Prove the chart + wake path by hand. If this doesn't work, no workflow will.

```bash
NS=preview-smoke
kubectl create namespace $NS
helm upgrade --install smoke ./deploy/preview -n $NS \
  --set name=smoke \
  --set host=smoke.preview.alleghenycounty.us \
  --set image.repository=<ACR_LOGIN_SERVER>/<APP_IMAGE_NAME> \
  --set image.tag=<a-real-sha-you-pushed> \
  --set idleTimeoutSeconds=120 \
  --wait --timeout 3m

# It should be at 0 replicas with no traffic. This request should wake it:
curl -sSf https://smoke.preview.alleghenycounty.us/ -o /dev/null -w "%{http_code}\n"
kubectl get pods -n $NS -w   # watch it scale 0→1 on that hit

# cleanup
kubectl delete namespace $NS
```

Checkpoints: (1) HTTPS resolves with a valid cert → A2/A3 good. (2) first curl returns 200 after a short delay → interceptor wiring good. (3) pod scales back to 0 after 120s idle → `scaledownPeriod` good.

---

## Part D — GitHub Actions workflows

Keep all three on your **default branch** so they show up in the Actions UI; the `branch` input selects what code gets built.

### `.github/workflows/preview-deploy.yml`

```yaml
name: Deploy Preview
on:
  workflow_dispatch:
    inputs:
      branch:
        description: Branch to deploy
        required: true
        type: string
      lifetime:
        description: Delete the whole preview after
        required: true
        default: "48h"
        type: choice
        options: ["24h", "48h", "7d", "custom"]
      lifetime_custom:
        description: Custom lifetime (e.g. 12h, 3d) — used only when lifetime=custom
        required: false
        type: string
      idle_timeout:
        description: Scale to 0 after this much idle
        required: true
        default: "30m"
        type: choice
        options: ["15m", "30m", "1h", "6h", "never"]
      max_replicas:
        description: Max replicas when awake
        required: false
        default: "3"
        type: string

permissions:
  id-token: write
  contents: read

concurrency:
  group: preview-${{ inputs.branch }}
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: preview
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ inputs.branch }}

      - name: Compute preview identity
        id: id
        run: |
          set -euo pipefail
          BRANCH="${{ inputs.branch }}"
          SHORT_SHA=$(git rev-parse --short HEAD)

          # RFC1123 label: lowercase, non-alnum -> -, trim, cap length.
          PREVIEW_ID=$(echo "$BRANCH" | tr '[:upper:]' '[:lower:]' \
            | sed -E 's#[^a-z0-9]+#-#g; s#^-+##; s#-+$##' | cut -c1-40 | sed -E 's#-+$##')
          [ -n "$PREVIEW_ID" ] || { echo "empty preview id"; exit 1; }
          # For per-run isolation instead of per-branch, use:
          # PREVIEW_ID="${PREVIEW_ID}-${SHORT_SHA}"

          NAMESPACE="preview-${PREVIEW_ID}"
          HOST="${PREVIEW_ID}.${{ vars.PREVIEW_DOMAIN }}"

          to_seconds() { local v="$1"; local n="${v%[hdm]}"; local u="${v: -1}";
            case "$u" in h) echo $((n*3600));; d) echo $((n*86400));; m) echo $((n*60));; *) echo "$v";; esac; }

          case "${{ inputs.idle_timeout }}" in
            never) IDLE=31536000 ;;
            *) IDLE=$(to_seconds "${{ inputs.idle_timeout }}") ;;
          esac

          LT="${{ inputs.lifetime }}"
          [ "$LT" = "custom" ] && LT="${{ inputs.lifetime_custom }}"
          [ -n "$LT" ] || { echo "custom lifetime empty"; exit 1; }
          LIFETIME_SECONDS=$(to_seconds "$LT")
          EXPIRES_AT=$(( $(date -u +%s) + LIFETIME_SECONDS ))

          {
            echo "preview_id=$PREVIEW_ID"
            echo "namespace=$NAMESPACE"
            echo "host=$HOST"
            echo "short_sha=$SHORT_SHA"
            echo "idle=$IDLE"
            echo "expires_at=$EXPIRES_AT"
          } >> "$GITHUB_OUTPUT"

      - uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}

      - name: ACR login
        run: az acr login -n ${{ vars.ACR_NAME }}

      - uses: docker/setup-buildx-action@v3

      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ vars.ACR_LOGIN_SERVER }}/${{ vars.APP_IMAGE_NAME }}:${{ steps.id.outputs.short_sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - uses: azure/aks-set-context@v4
        with:
          cluster-name: ${{ vars.AKS_CLUSTER }}
          resource-group: ${{ vars.AKS_RESOURCE_GROUP }}
          admin: false
          use-kubelogin: true

      - name: Create/label namespace
        run: |
          set -euo pipefail
          cat <<EOF | kubectl apply -f -
          apiVersion: v1
          kind: Namespace
          metadata:
            name: ${{ steps.id.outputs.namespace }}
            labels:
              managed-by: preview-bot
              preview.branch: ${{ steps.id.outputs.preview_id }}
              preview.commit: ${{ steps.id.outputs.short_sha }}
              preview.expires-at: "${{ steps.id.outputs.expires_at }}"
            annotations:
              preview.branch-original: "${{ inputs.branch }}"
          EOF

      - name: Deploy chart
        run: |
          set -euo pipefail
          helm upgrade --install ${{ steps.id.outputs.preview_id }} ./deploy/preview \
            -n ${{ steps.id.outputs.namespace }} \
            --set name=${{ steps.id.outputs.preview_id }} \
            --set host=${{ steps.id.outputs.host }} \
            --set image.repository=${{ vars.ACR_LOGIN_SERVER }}/${{ vars.APP_IMAGE_NAME }} \
            --set image.tag=${{ steps.id.outputs.short_sha }} \
            --set idleTimeoutSeconds=${{ steps.id.outputs.idle }} \
            --set replicas.max=${{ inputs.max_replicas }} \
            --set interceptor.fqdn=${{ vars.INTERCEPTOR_FQDN }} \
            --set interceptor.port=${{ vars.INTERCEPTOR_PORT }} \
            --set commit=${{ steps.id.outputs.short_sha }} \
            --set branch=${{ steps.id.outputs.preview_id }} \
            --wait --timeout 4m

      - name: Verify (cold-start proof)
        run: |
          set -euo pipefail
          URL="https://${{ steps.id.outputs.host }}/"
          for i in $(seq 1 30); do
            code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL" || true)
            echo "attempt $i: $code"
            [ "$code" = "200" ] && exit 0
            sleep 5
          done
          echo "Preview did not return 200 within timeout"; exit 1

      - name: Summary
        if: always()
        run: |
          {
            echo "## Preview deployment"
            echo ""
            echo "| | |"
            echo "|---|---|"
            echo "| Branch | \`${{ inputs.branch }}\` |"
            echo "| Commit | \`${{ steps.id.outputs.short_sha }}\` |"
            echo "| Image | \`${{ vars.ACR_LOGIN_SERVER }}/${{ vars.APP_IMAGE_NAME }}:${{ steps.id.outputs.short_sha }}\` |"
            echo "| Namespace | \`${{ steps.id.outputs.namespace }}\` |"
            echo "| Idle timeout | ${{ inputs.idle_timeout }} |"
            echo "| Lifetime | ${{ inputs.lifetime }}${{ inputs.lifetime_custom }} |"
            echo ""
            echo "### URL"
            echo "https://${{ steps.id.outputs.host }}"
          } >> "$GITHUB_STEP_SUMMARY"
```

> **Verification reachability:** the verify step curls the public URL from the runner. If `preview.alleghenycounty.us` resolves only on an internal network, the runner can't reach it — either run the workflow on a self-hosted runner inside the network, or replace the verify step with an in-cluster check (`kubectl run curl --rm -it --image=curlimages/curl -- curl -sf http://<interceptor-fqdn>:<port>/ -H "Host: <host>"`).

### `.github/workflows/preview-destroy.yml`

```yaml
name: Destroy Preview
on:
  workflow_dispatch:
    inputs:
      branch:
        description: Branch whose preview to destroy
        required: true
        type: string

permissions:
  id-token: write
  contents: read

jobs:
  destroy:
    runs-on: ubuntu-latest
    environment: preview
    steps:
      - name: Compute namespace
        id: id
        run: |
          PREVIEW_ID=$(echo "${{ inputs.branch }}" | tr '[:upper:]' '[:lower:]' \
            | sed -E 's#[^a-z0-9]+#-#g; s#^-+##; s#-+$##' | cut -c1-40 | sed -E 's#-+$##')
          echo "namespace=preview-${PREVIEW_ID}" >> "$GITHUB_OUTPUT"

      - uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}

      - uses: azure/aks-set-context@v4
        with:
          cluster-name: ${{ vars.AKS_CLUSTER }}
          resource-group: ${{ vars.AKS_RESOURCE_GROUP }}
          admin: false
          use-kubelogin: true

      - name: Delete namespace
        run: kubectl delete namespace ${{ steps.id.outputs.namespace }} --ignore-not-found --wait=false
```

### `.github/workflows/preview-reap.yml`

```yaml
name: Reap Expired Previews
on:
  schedule:
    - cron: "*/30 * * * *"   # every 30 min
  workflow_dispatch: {}

permissions:
  id-token: write
  contents: read

jobs:
  reap:
    runs-on: ubuntu-latest
    environment: preview
    steps:
      - uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}

      - uses: azure/aks-set-context@v4
        with:
          cluster-name: ${{ vars.AKS_CLUSTER }}
          resource-group: ${{ vars.AKS_RESOURCE_GROUP }}
          admin: false
          use-kubelogin: true

      - name: Delete expired preview namespaces
        run: |
          set -euo pipefail
          now=$(date -u +%s)
          expired=$(kubectl get ns -l managed-by=preview-bot -o json \
            | jq -r --argjson now "$now" \
              '.items[] | select((.metadata.labels["preview.expires-at"] // "0" | tonumber) < $now) | .metadata.name')
          if [ -z "$expired" ]; then echo "nothing to reap"; exit 0; fi
          echo "$expired" | while read -r ns; do
            [ -n "$ns" ] || continue
            echo "deleting $ns"
            kubectl delete ns "$ns" --wait=false
          done
```

---

## Part E — Build order for the harness

1. **Bootstrap (Part A).** nginx → wildcard DNS → cert-manager + wildcard cert + default-ssl-certificate → KEDA core + HTTP add-on → OIDC identity + role assignments → repo variables + `preview` environment. Confirm the interceptor service name/port and update `INTERCEPTOR_FQDN`/`INTERCEPTOR_PORT`.
2. **Write the Helm chart (Part B).** `helm lint ./deploy/preview` and `helm template` to eyeball rendered output.
3. **Manual smoke test (Part C).** Do not proceed until the cold-start curl returns 200 and the pod scales back to 0.
4. **Add `preview-deploy.yml` (Part D).** Dispatch it against a test branch. Confirm the URL in the job summary works and wakes on hit.
5. **Add `preview-destroy.yml` + `preview-reap.yml`.** Deploy something with a 1h lifetime, confirm the reaper deletes it on the next run.
6. **Harden.** Swap cluster-scope Azure RBAC Writer for a scoped Kubernetes `ClusterRole` (A5 hardening note); confirm the per-namespace `ResourceQuota` is enforced; add required reviewers on the `preview` environment if you want a spin-up gate; set an ACR retention policy so SHA-tagged preview images don't pile up.

---

## Version-sensitive knobs (check these first if something breaks)

- **HTTPScaledObject schema** — the field names in `httpscaledobject.yaml`. Most likely thing to drift.
- **Interceptor service name/port** — `INTERCEPTOR_FQDN` / `INTERCEPTOR_PORT` and the ExternalName target.
- **nginx ExternalName routing** — if the interceptor never sees the right Host, it's the `upstream-vhost` annotation. If per-namespace Ingress→ExternalName proves flaky on your nginx version, the fallback is a single centralized Ingress in the `keda` namespace routing all preview hosts to the interceptor (you lose per-namespace Ingress isolation, keep everything else).

## Alternatives, if you want to reconsider a locked decision

- **Knative Serving** instead of KEDA HTTP add-on: request-driven scale-to-zero is first-class and battle-tested, no pre-1.0 interceptor in the path. Cost: it's a platform to learn and it wants to own routing (Kourier/Istio), which fights the plain-Deployment + nginx model here. Worth it only if you're heading toward a broader internal PaaS.
- **external-dns** instead of a wildcard A record: needed only if you can't or won't use a wildcard record. The wildcard is one record and zero per-preview DNS calls, so prefer it.
- **Hard scale-to-0 at exactly T (still wakeable):** if you truly want this on top of the idle+lifetime model, add a one-shot CronJob per preview that patches the HTTPScaledObject's `replicas.min`/`max` to 0 at time T, or scales the Deployment and pauses KEDA. Not built here — the idle timeout covers the realistic case.
