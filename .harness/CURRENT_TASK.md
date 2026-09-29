# CURRENT TASK

**Feature**: none — roadmap COMPLETE (13/13, Phases 01–03, 2026-09-29)
**Status**: —

## Follow-ups (not on the roadmap; each needs a new FID in ROADMAP + phase file before work starts)
1. BLK-008: `bootstrap/teardown.sh` leaves Entra app `gh-preview-deployer` (+SP, federated creds) and UAMI
   `cert-manager-dns`.
2. Untagged ACR manifests (buildx platform/attestation children) are never purged (F011 contract §5).
3. Node.js 20 deprecation warning on actions (checkout@v4, azure/login@v2, aks-set-context@v4, use-kubelogin@v1)
   — bump when Node 24 majors exist.
4. COST IS RUNNING: pause with `az aks stop -g nimatresourceg -n aks-preview`; remove with `bootstrap/teardown.sh --yes`.

## Definition of done (for any new feature)
`AGENTS.md` → Definition of done.
