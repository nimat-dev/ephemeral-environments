# Ephemeral Preview Environments on Kubernetes (AKS)

Per-branch ephemeral preview environments on Kubernetes with **idle scale-to-zero** and **wake-on-request** (powered by KEDA + KEDA HTTP add-on), wildcard DNS & Let's Encrypt DNS-01 TLS, OIDC-only GitHub Actions workflows (zero stored secrets), and multi-tenant isolation.

Shipped as:
1. **A standalone Helm chart** ([`deploy/preview/`](deploy/preview/)) that works on any Kubernetes cluster (no Terraform/OpenTofu required).
2. **A reusable GitHub Actions Preview Kit** ([`kit/`](kit/) + [`.github/workflows/kit-*.yml`](.github/workflows/)) that any application repo can consume via a `.preview.yaml` contract.
3. **Platform Infrastructure-as-Code** with both an **OpenTofu + Flux GitOps** stack ([`platform/`](platform/), [`clusters/`](clusters/)) and a **pure Bash/CLI bootstrap** alternative ([`bootstrap/`](bootstrap/)).

---

## Architecture

```
Developer
  │  workflow_dispatch (branch, lifetime, idle_timeout, max_replicas)
  ▼
GitHub Actions ──OIDC──► Azure (no stored secrets)
  ├─ checkout <branch> & read .preview.yaml
  ├─ docker build → push ACR/<app>/<component>:<short-sha>
  ├─ kubectl apply namespace preview-<app>-<branch> (labels: expires-at, preview.repo, commit)
  ├─ helm upgrade --install → Deployment, Service, HTTPScaledObject, ExternalName, Ingress, ResourceQuota
  └─ verify: curl https://<branch>.<PREVIEW_DOMAIN><probePath> (proves 0→1 cold-start wake)

Live Request Path:
  Browser ──► Ingress Controller (Traefik / nginx)
          ──► ExternalName Service
          ──► KEDA HTTP Interceptor Proxy (holds request if replicas == 0, scales 0→1)
          ──► App Service ──► Pod
```

---

## Can I Use the Helm Chart Without Terraform / OpenTofu?

**Yes.** The Helm chart in [`deploy/preview/`](deploy/preview/) is completely standalone and has zero dependency on Terraform, OpenTofu, or Azure-specific resources.

### Cluster Prerequisites for Standalone Helm Usage
1. **Kubernetes cluster** (AKS, EKS, GKE, k3s, kind, etc.).
2. **Ingress Controller** (e.g., `traefik` or `nginx`, passed via `--set ingressClassName=<class>`).
3. **KEDA Core + KEDA HTTP Add-on** installed in the `keda` namespace (`http.keda.sh/v1alpha1` `HTTPScaledObject` CRD and `keda-add-ons-http-interceptor-proxy.keda.svc.cluster.local:8080`).

---

## Quick Start Guide

### Option 1: Deploy the Helm Chart Directly (No Terraform / OpenTofu)

#### Single-Component Application
```bash
# 1. Create the preview namespace (the chart intentionally does not template Namespace)
kubectl create namespace preview-my-branch

# 2. Deploy the preview release
helm upgrade --install my-branch ./deploy/preview \
  -n preview-my-branch \
  --set-string name=my-branch \
  --set-string host=my-branch.preview.example.com \
  --set-string image.repository=ghcr.io/my-org/my-app \
  --set-string image.tag=abc1234 \
  --set-string ingressClassName=traefik \
  --set idleTimeoutSeconds=1800 \
  --set replicas.max=3 \
  --wait --timeout 4m
```

#### Multi-Component Application (Path-Based Routing on One Host)
Pass a `components` list (see [`tests/fixtures/values-multi.yaml`](tests/fixtures/values-multi.yaml) and [`deploy/preview/values.yaml`](deploy/preview/values.yaml)):
```yaml
# my-values.yaml
name: feat-login
host: feat-login.preview.example.com
ingressClassName: traefik
idleTimeoutSeconds: 1800
replicas:
  max: 3
components:
  - name: web
    image:
      repository: ghcr.io/my-org/my-app/web
      tag: abc1234
    port: 8080
    probePath: /
    route: /
  - name: api
    image:
      repository: ghcr.io/my-org/my-app/api
      tag: abc1234
    port: 8080
    probePath: /api/health
    route: /api
```

```bash
kubectl create namespace preview-feat-login
helm upgrade --install feat-login ./deploy/preview -n preview-feat-login -f my-values.yaml --wait
```

#### Render & Validate Templates Locally (No Cluster Needed)
```bash
helm lint ./deploy/preview
helm template t ./deploy/preview -f tests/fixtures/values.yaml \
  | kubeconform -strict -summary -ignore-missing-schemas
```

---

### Option 2: Provision the Full Azure Platform *Without* Terraform (Bash Bootstrap)

If you want the complete Azure + AKS setup without using OpenTofu/Terraform, use the idempotent CLI scripts in [`bootstrap/`](bootstrap/):

1. **Create `bootstrap/.env` from the template:**
   ```bash
   cp bootstrap/.env.example bootstrap/.env
   # Edit bootstrap/.env with your AZ_SUBSCRIPTION_ID, AZ_RESOURCE_GROUP, ACR_NAME, AKS_NAME, DNS_ZONE, etc.
   ```
2. **Provision Azure resources (ACR, AKS with OIDC + Workload Identity, Azure DNS Zone):**
   ```bash
   ./bootstrap/provision.sh          # dry-run preflight & quota checks
   ./bootstrap/provision.sh --apply  # provisions ACR, AKS, DNS zone & configures kubectl
   ```
3. **Install in-cluster controllers and GitHub OIDC:**
   ```bash
   ./bootstrap/a1-ingress.sh --apply       # Ingress controller + static public IP
   ./bootstrap/a2-dns-wildcard.sh --apply  # *.preview.<domain> A record -> LB IP
   ./bootstrap/a3-cert-manager.sh --apply  # cert-manager + Let's Encrypt DNS-01 wildcard certificate
   ./bootstrap/a4-keda-http.sh --apply     # KEDA core + KEDA HTTP add-on
   ./bootstrap/a5-ci-identity.sh --apply   # Entra app/SP + federated OIDC + K8s RBAC & ValidatingAdmissionPolicy guard
   ./bootstrap/a6-github-env.sh --apply    # GitHub 'preview' environment + 12 variables
   ```
4. **Run the cluster smoke test:**
   ```bash
   ./scripts/smoke.sh
   ```

---

### Option 3: Provision the Platform with OpenTofu + Flux GitOps

For declarative multi-repo platform management:

1. **Bootstrap encrypted OpenTofu state storage (one-time):**
   ```bash
   ./bootstrap/a0-tofu-state.sh --apply
   ```
2. **Apply the OpenTofu environment (`platform/envs/<team>`):**
   ```bash
   export GITHUB_TOKEN="$(gh auth token)"
   tofu -chdir=platform/envs/nimat init
   tofu -chdir=platform/envs/nimat plan
   tofu -chdir=platform/envs/nimat apply
   ```
   OpenTofu provisions AKS, ACR, DNS zones, managed identities, GitHub environment variables, the Flux AKS extension, and generates per-repo Kubernetes RBAC/ValidatingAdmissionPolicy manifests under [`clusters/nimat/config/repos/`](clusters/nimat/config/repos/).
3. **Flux GitOps reconciliation:**
   Flux automatically reconciles [`clusters/nimat/`](clusters/nimat/) (Traefik, cert-manager, KEDA, ClusterIssuers, wildcard certificates, TLSStore, and per-repo isolation guards).

---

## Consuming the Reusable Preview Kit in Another Repo

Application repositories only need a [`.preview.yaml`](.preview.yaml) file and thin caller workflows (see [`examples/consumer/`](examples/consumer/)):

1. **Add `.preview.yaml` to the root of your app repository:**
   ```yaml
   components:
     - name: web
       context: todo
       route: /
     - name: api
       context: examples/echo-api
       route: /api
       probePath: /api/health
   defaults:
     lifetime: 48h
     idle: 30m
     maxReplicas: 3
   ```
2. **Copy the caller workflows from [`examples/consumer/.github/workflows/`](examples/consumer/.github/workflows/):**
   - `preview.yml` — calls `kit-deploy.yml` and `kit-destroy.yml`
   - `preview-cleanup.yml` — scheduled reaper (`kit-reap.yml`) and ACR tag purger (`kit-purge.yml`)

---

## Managing Preview Environments

| Operation | GitHub Actions Workflow | CLI Entrypoint (`scripts/preview-ci.sh`) |
|---|---|---|
| **Deploy / Update** | `Actions → Deploy Preview → Run workflow` | `scripts/preview-ci.sh plan \| namespace \| deploy \| verify \| summary` |
| **Destroy Branch Preview** | `Actions → Destroy Preview → Run workflow` | `scripts/preview-ci.sh destroy` |
| **Reap Expired Previews** | Runs automatically every 30 min (`preview-reap.yml`) | `scripts/preview-ci.sh reap` |
| **Purge Stale ACR Tags** | Runs automatically daily (`preview-purge.yml`) | `scripts/preview-ci.sh purge` |

---

## Local Development & Verification

### Install Toolchain
```bash
brew install helm kubectl azure-cli actionlint shellcheck yamllint kubeconform bats-core jq yq opentofu tflint checkov
```

### Run the Full Verification Suite
[`./scripts/init.sh`](scripts/init.sh) runs the roadmap gate, YAML/shell/workflow/Helm linters, chart template rendering + `kubeconform` schema validation, unit/integration tests (`bats tests/`), OpenTofu fmt/validate/test/tflint/checkov, and architecture boundary checks:

```bash
./scripts/init.sh
```

Individual commands:
```bash
bats tests/                        # Run all 294 bats unit & integration tests
./scripts/check-architecture.sh    # Enforce layer boundary rules (1–9)
./scripts/harness-check.sh         # Verify harness state, roadmap gate & command mirrors
./scripts/smoke.sh                 # Run live cluster smoke checks
```

---

## Repository Layout

```
.harness/     Project state, architecture specs, ADRs, verification contracts & evidence
kit/          Composite action used by reusable workflows (.github/workflows/kit-*.yml)
scripts/      preview-ci.sh (+ scripts/lib/preview.sh pure core), init.sh, smoke.sh, harness-check.sh
deploy/       Standalone Helm chart (deploy/preview)
platform/     OpenTofu modules (team-cluster, repo-onboarding) & live environments (envs/nimat)
clusters/     Flux GitOps manifests (base controllers + team config & per-repo RBAC guards)
bootstrap/    Standalone bash provisioning scripts (no-Terraform alternative + a0 state / a7 child DNS)
examples/     Consumer repo workflow templates (examples/consumer) + sample echo-api backend
templates/    Copier template for scaffolding the agentic harness into new repositories
todo/         Sample Vite + React frontend application
tests/        Bats test suites and Helm chart render fixtures
```
