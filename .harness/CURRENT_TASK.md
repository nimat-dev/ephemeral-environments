# CURRENT TASK

**Feature**: F004 — Cluster bootstrap (spec Part A1–A6) on `aks-preview`
**Phase**: Phase 01 — Foundation
**Status**: IN PROGRESS — A1/A4/A5/A6 workable now; A2 (wildcard A) + A3 (DNS-01 wildcard cert)
need the Namecheap NS delegation (BLK-005, human)

## Exact next step
1. Human: add 4 NS records in Namecheap for host `preview` (values in BLOCKERS.md BLK-005).
2. Branch `feat/F004` exists (tracking only) — rebase/continue it on top of `feat/F013`.
3. Sprint contract `verification/contracts/F004.md`; resolve BLK-004 by pinning KEDA core +
   HTTP add-on chart versions compatible with k8s 1.35.
4. Scripts (dry-run default, `--apply`, idempotent, reuse `bootstrap/_common.sh` + `.env`):
   `a1-ingress-nginx.sh`, `a2-wildcard-dns.sh`, `a3-cert-manager.sh` (+ clusterissuer/wildcard-cert
   templated from env, workload identity for DNS-01), `a4-keda.sh`, `a5-github-oidc.sh`, `a6-github-env.sh`.
5. bats with fakes for az/helm/kubectl/gh; then human-approved apply; evidence.
Proof: cert `wildcard-preview` Ready; `dig x.preview.nimat.dev` → LB IP; interceptor svc name/port recorded.

## Acceptance (summary)
See `phases/PHASE-01-FOUNDATION.md` → F004.

## Definition of done
Every acceptance item met + evidence in `CHANGELOG.md` + Evaluator PASS + check-architecture
clean + PR reviewed clean (`AGENTS.md` → Definition of done).
