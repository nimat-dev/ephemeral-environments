# CURRENT TASK

**Feature**: F004 — Cluster bootstrap (spec Part A1–A6)
**Phase**: Phase 01 — Foundation
**Status**: IN PROGRESS — script writing is offline; **applying is BLOCKED** on BLK-001 (Azure
values/access), BLK-004 (KEDA / HTTP add-on versions), BLK-005 (preview. sub-zone delegation)

## Exact next step
1. Branch `feat/F004` (from `feat/F003`).
2. Sprint contract `verification/contracts/F004.md`.
3. `bootstrap/.env.example` (all env-specific values; real `bootstrap/.env` gitignored).
4. Idempotent scripts, one per spec step, each with `--dry-run` (print commands, change nothing):
   `bootstrap/a1-ingress-nginx.sh`, `a2-wildcard-dns.sh`, `a3-cert-manager.sh`
   (+ `clusterissuer.yaml`, `wildcard-cert.yaml` templated from env), `a4-keda.sh` (pinned
   versions), `a5-github-oidc.sh`, `a6-github-env.sh` (gh variables).
5. bats: dry-run output per script against a sample env; shellcheck clean; `--dry-run` is the default
   when `.env` is missing.
Proof (offline): `./scripts/init.sh` GREEN. Proof (online, after BLK-001): scripts applied twice
(second run = no changes), `kubectl get certificate -n ingress-nginx` Ready, wildcard A → LB IP.

## Acceptance (summary)
See `phases/PHASE-01-FOUNDATION.md` → F004.

## Definition of done
Every acceptance item met + evidence in `CHANGELOG.md` + Evaluator PASS + check-architecture
clean + PR reviewed clean (`AGENTS.md` → Definition of done).
