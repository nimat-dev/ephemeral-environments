# PRODUCT — the vision

> Source spec: `../preview-environments-implementation.md` (the requirement, verbatim).
> Everything here traces back to it.

## What it is
Ephemeral **per-branch preview environments on AKS**. A developer dispatches a GitHub
Actions workflow with a branch name; the pipeline builds the image, pushes it to ACR
(tagged with the short Git SHA), deploys it into its own namespace, and returns a stable
HTTPS URL: `https://<sanitized-branch>.preview.alleghenycounty.us`.

## The problem
Reviewers and QA need to click through a branch before merge. Long-lived shared staging
gets contended; manually standing up environments is slow; abandoned environments burn
cluster capacity forever.

## Core idea — two independent knobs
- **Idle timeout** — no traffic for N (15m/30m/1h/6h/never) → KEDA scales the Deployment
  to 0. Hitting the URL wakes it (KEDA HTTP interceptor holds the request, scales 0→1,
  forwards). This is sleep/wake.
- **Lifetime** — after 24h/48h/7d/custom the whole namespace is deleted regardless of
  traffic (scheduled reaper reads the `preview.expires-at` label). This is teardown.

## MVP shape
1. One-time cluster bootstrap: ingress-nginx, wildcard DNS, cert-manager wildcard cert as
   nginx default, KEDA core + HTTP add-on, GitHub→Azure OIDC, `preview` GH environment.
2. Helm chart `deploy/preview` (Deployment, Service, ExternalName→interceptor,
   HTTPScaledObject, Ingress, ResourceQuota).
3. Three workflows: `preview-deploy.yml` (dispatch), `preview-destroy.yml` (dispatch),
   `preview-reap.yml` (cron every 30 min).
4. URL + metadata written to the job summary.

## What makes it different
- Zero per-preview DNS/TLS work: one wildcard A record + one wildcard cert.
- No stored secrets: OIDC federation only.
- Idle previews cost ~nothing (0 replicas); forgotten ones die on schedule; a per-namespace
  `ResourceQuota` caps any single preview.

## Non-goals (MVP)
- Hard "force to 0 at exactly T but keep wakeable" CronJob (spec: optional, not built).
- Knative Serving, external-dns (documented alternatives only).
- Multiple concurrent commits per branch (one-line `PREVIEW_ID` change if ever needed).
