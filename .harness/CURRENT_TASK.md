# CURRENT TASK

**Feature**: F017 — Multiple project domains per cluster (Phase 05, `phases/PHASE-05-MULTI-REPO.md`)
**Status**: IN PROGRESS (2026-09-30). Last: F016 COMPLETE.

## Exact next step
1. Branch `feat/F017`; contract `verification/contracts/F017.md`.
2. `bootstrap/a7-project-domain.sh --domain D [--parent-zone P]`: zone, delegation (NS in parent Azure zone or printed for
   registrar), wildcard A → Traefik LB, UAMI DNS Zone Contributor, ClusterIssuer + wildcard Certificate per domain, secret
   added to Traefik default TLSStore `certificates`. Tests with fake az/kubectl. a6: `PREVIEW_DOMAIN` overridable per repo.
3. e2e: `--domain shop.preview.nimat.dev --parent-zone preview.nimat.dev --apply`; smoke on both domains (valid cert each).
4. Cluster RUNNING — `az aks stop -g nimatresourceg -n aks-preview` when idle.

Follow-ups (not on the roadmap; each needs a new FID first; several fold into Phase 05):
1. BLK-008 (→ F020): `bootstrap/teardown.sh` leaves Entra app `gh-preview-deployer` (+SP, federated creds) and UAMI
   `cert-manager-dns`.
2. Untagged ACR manifests (buildx platform/attestation children) are never purged (F011 contract §5).
3. `ubuntu-latest` migrates to Ubuntu 26 from 2026-10-19 (runner notice on every run) — re-run workflows after; pin `ubuntu-24.04` if anything breaks.
4. Cluster RUNNING since 2026-09-30 (F015 e2e) — stop with `az aks stop -g nimatresourceg -n aks-preview` when idle.

## Definition of done (for any new feature)
`AGENTS.md` → Definition of done.
