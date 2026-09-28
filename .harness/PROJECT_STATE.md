# PROJECT STATE — MASTER FILE

> Read this first, every session. Rewrite it for a cold reader before you stop.

## Where we are
- **Phase**: Phase 02 — Workflows (Phase 01 COMPLETE 2026-09-28)
- **Active feature**: F006 — preview-deploy.yml (IN PROGRESS; real e2e blocked on BLK-006)
- **Overall progress**: 7 / 13 features COMPLETE (54%) — all of Phase 01

## Last verified
- **Date**: 2026-09-28
- **init**: green — `./scripts/init.sh` BASELINE GREEN (2026-09-28)
- **Full suite + check-architecture**: green — `bats tests/` 115/115; check-architecture clean
- **E2E**: `scripts/smoke.sh` 3/3 PASS twice on aks-preview (TLS, cold start ~8–9s, back to 0 after 127s)
- **Git**: branch `feat/F005` (stack chore/harness-and-todo → F001 → F002 → F003 → F004 → F013 → F004 → F005) — pushed; no PRs (BLK-006).

## Next step
Human: fix gh access (BLK-006) and run `bootstrap/a6-github-env.sh --apply`. Agent: F006 workflow. Mirrors `CURRENT_TASK.md`.

## Open blockers
See `BLOCKERS.md`. BLK-001 (no Azure values) blocks F004+; BLK-002 now only = F006 build
context `todo`; BLK-006 blocks opening PRs via `gh`. F001–F003 offline and unblocked.

## Notes for the next agent
- Cluster: Traefik LB 74.151.139.236, `*.preview.nimat.dev` wildcard DNS + LE wildcard cert (Traefik default TLSStore).
  KEDA 2.21 + HTTP add-on 0.16 (interceptor-proxy:8080). Chart needs `--set ingressClassName=traefik`.
- kubectl auth is Entra (kubelogin in ~/go/bin; add to PATH). Break-glass: `az aks get-credentials --admin`.
- GitHub repo variables NOT set yet (A6, BLK-006) — required before F006.
- 2026-09-28 Azure discovery: single subscription, empty RG `nimatresourceg` (eastus); no AKS/ACR/DNS.
  F013 DONE: AKS `aks-preview` (1× D2as_v7, k8s 1.35.8), ACR `nimatpreviewacr`, zone `preview.nimat.dev`.
  COST IS RUNNING — pause: `az aks stop -g nimatresourceg -n aks-preview`; remove: `bootstrap/teardown.sh --yes`.
- Tooling lives outside brew: yamllint (~/.local/bin, pipx), kubeconform (~/go/bin), bats (npm).
  `scripts/init.sh` adds those to PATH. Brew blocked until `sudo xcodebuild -license accept`.
- Hooks (`.claude/settings.json`, DEC-013) enforce the loop: Stop is blocked if you change
  files outside `.harness/` without updating this file.
- App to preview = `todo/` (F012). Deploy workflow (F006) must build `context: todo`.
- The requirement is `.harness/preview-environments-implementation.md` — verbatim file
  contents for chart, workflows, bootstrap. Harness files distill it; the spec wins on detail.
- DEC-010: preview-id sanitizer lives once in `scripts/lib/preview.sh` (spec inlines it twice).
- Most drift-prone file: `httpscaledobject.yaml` (KEDA HTTP add-on pre-1.0).
