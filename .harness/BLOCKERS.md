# BLOCKERS — what's stuck

Open blockers first. Close a blocker by moving it to Resolved with the fix + date. A parked
out-of-scope temptation (scope-guard) also lands here until it becomes a real ROADMAP feature.

## Open
```
(id | opened | feature | description | what would unblock it)
BLK-001 | 2026-09-28 | F004,F005,F006+ | PARTIAL (2026-09-28 discovery via `az`, account nimat.razmjo@outlook.com): tenant 4d0316fd-aae8-410b-8ab1-393e4c3d28c6, subscription 1325f79b-c2c1-437c-a8c7-a0746ab748d4 (`subscription1`, only one), RG `nimatresourceg` (eastus, empty). NO AKS, NO ACR, NO DNS zone exist — spec prerequisites missing | human decides: provision AKS+ACR (cost) — proposed F013; and a preview domain (BLK-005)
BLK-002 | 2026-09-28 | F006 | PARTIAL: app = `todo/` confirmed long-term target (DEC-012). Remaining: spec's deploy builds `context: .` -> must become `context: todo` | F006 sets build context to `todo`
BLK-003 | 2026-09-28 | F006 | Unknown if `preview.alleghenycounty.us` is publicly resolvable; public curl verify fails on internal DNS | confirm; else self-hosted runner or in-cluster verify
BLK-004 | 2026-09-28 | F004 | KEDA core version / HTTP add-on chart version to pin unknown | check cluster (`--enable-keda` managed vs Helm) and pick compatible add-on
BLK-006 | 2026-09-28 | PR loop | `gh` authed as `nimatrazmjo` — not collaborator on `nimat-dev/ephemeral-environments`; `gh pr create` fails (git push via SSH works) | `gh auth login` as org account, or add `nimatrazmjo` as collaborator, or open PR in browser
BLK-005 | 2026-09-28 | F004 | No DNS zone in the subscription; `alleghenycounty.us` not controllable from this (personal) account | pick a domain: own domain in Azure DNS, or sslip.io/nip.io wildcard on the LB IP (no zone, but DNS-01 wildcard cert impossible → per-host HTTP-01 certs)
```

## Resolved
```
(id | resolved | how)
BLK-007 | 2026-09-28 | brew install failed (Xcode license, needs sudo) -> installed yamllint (pipx), kubeconform (go install), bats (npm); DEC-015
```
