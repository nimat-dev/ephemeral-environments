# CURRENT TASK

**Feature**: none — roadmap COMPLETE (14/14, Phases 01–04, 2026-09-29); last: F014 (issue #17)
**Status**: —

## Exact next step
Roadmap done. Follow-ups (not on the roadmap; each needs a new FID in ROADMAP + phase file before work starts):
1. BLK-008: `bootstrap/teardown.sh` leaves Entra app `gh-preview-deployer` (+SP, federated creds) and UAMI
   `cert-manager-dns`.
2. Untagged ACR manifests (buildx platform/attestation children) are never purged (F011 contract §5).
3. `ubuntu-latest` migrates to Ubuntu 26 from 2026-10-19 (runner notice on every run) — re-run workflows after; pin `ubuntu-24.04` if anything breaks.
4. COST IS RUNNING: pause with `az aks stop -g nimatresourceg -n aks-preview`; remove with `bootstrap/teardown.sh --yes`.

## Definition of done (for any new feature)
`AGENTS.md` → Definition of done.
