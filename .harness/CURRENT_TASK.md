# CURRENT TASK

**Feature**: F013 — Provision Azure prerequisites (AKS + ACR + DNS zone)
**Phase**: Phase 01 — Foundation
**Status**: IN PROGRESS (F004 BLOCKED behind it)

## Exact next step
Offline part DONE (scripts + 16 tests + real dry-run). Waiting on the human:
1. Human approves cost + runs (or OKs Claude running) `bootstrap/provision.sh --apply`
   (~10 min; registers Microsoft.ContainerRegistry, creates ACR, AKS, DNS zone).
2. Verify: `az aks show -g nimatresourceg -n aks-preview --query provisioningState` = Succeeded;
   `kubectl get nodes` Ready; re-run `--apply` → all "skip".
3. Human adds the printed NS records in Namecheap (host `preview`); verify `dig NS preview.nimat.dev`.
4. Checker pass → mark F013 COMPLETE → unblock F004.

## Acceptance (summary)
See `phases/PHASE-01-FOUNDATION.md` → F013.

## Definition of done
Every acceptance item met + evidence in `CHANGELOG.md` + Evaluator PASS + check-architecture
clean + PR reviewed clean (`AGENTS.md` → Definition of done).
