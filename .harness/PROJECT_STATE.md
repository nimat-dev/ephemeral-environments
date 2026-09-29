# PROJECT STATE — MASTER FILE

> Read this first, every session. Rewrite it for a cold reader before you stop.

## Where we are
- **Phase**: Phase 02 — Workflows (Phase 01 COMPLETE 2026-09-28)
- **Active feature**: F006 — preview-deploy.yml (IN PROGRESS; unblocked — A6 vars set, Phase 01 PRs reviewed clean)
- **Overall progress**: 7 / 13 features COMPLETE (54%) — all of Phase 01

## Last verified
- **Date**: 2026-09-28
- **init**: green — `./scripts/init.sh` BASELINE GREEN (2026-09-28)
- **Full suite + check-architecture**: green — `bats tests/` 115/115; check-architecture clean
- **E2E**: `scripts/smoke.sh` 3/3 PASS twice on aks-preview (TLS, cold start ~8–9s, back to 0 after 127s)
- **Git**: branch `feat/F005` (stack chore/harness-and-todo → F001 → F002 → F003 → F013 → F004 → F005) — pushed; stacked PRs #1–#7 open, reviewed clean round 2 (`reviews/stack-review.md`).

## Next step
Agent: branch `feat/F006` from `feat/F005`, sprint contract, build the deploy workflow (must set `HELM_DRIVER=configmap`, DEC-026). Human: merge PRs #1–#7 in order when ready. Mirrors `CURRENT_TASK.md`.

## Open blockers
See `BLOCKERS.md`. BLK-002 = F006 build context `todo`; BLK-008 = teardown leaves Entra app + UAMI
(follow-up). BLK-003/BLK-006 resolved.

## Notes for the next agent
- Cluster: Traefik LB 74.151.139.236, `*.preview.nimat.dev` wildcard DNS + LE wildcard cert (Traefik default TLSStore).
  KEDA 2.21 + HTTP add-on 0.16 (interceptor-proxy:8080). Chart needs `--set ingressClassName=traefik`.
- kubectl auth is Entra (kubelogin in ~/go/bin; add to PATH). Break-glass: `az aks get-credentials --admin`.
- GitHub env `preview` + 12 variables SET (A6, 2026-09-28). `gh` active account must be `nimat-dev` (admin); `nimatrazmjo` also logged in but not a collaborator.
- CI SP has NO secrets access (DEC-026): every workflow helm call needs `HELM_DRIVER=configmap`.
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
