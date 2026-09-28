# BLOCKERS — what's stuck

Open blockers first. Close a blocker by moving it to Resolved with the fix + date. A parked
out-of-scope temptation (scope-guard) also lands here until it becomes a real ROADMAP feature.

## Open
```
(id | opened | feature | description | what would unblock it)
BLK-001 | 2026-09-28 | F004,F005,F006+ | PARTIAL (2026-09-28 discovery via `az`, account nimat.razmjo@outlook.com): tenant 4d0316fd-aae8-410b-8ab1-393e4c3d28c6, subscription 1325f79b-c2c1-437c-a8c7-a0746ab748d4 (`subscription1`, only one), RG `nimatresourceg` (eastus, empty). NO AKS, NO ACR, NO DNS zone exist — spec prerequisites missing | F013 approved (DEC-019): create AKS+ACR+zone via bootstrap/provision.sh --apply after human OK on the dry-run
BLK-002 | 2026-09-28 | F006 | PARTIAL: app = `todo/` confirmed long-term target (DEC-012). Remaining: spec's deploy builds `context: .` -> must become `context: todo` | F006 sets build context to `todo`
BLK-003 | 2026-09-28 | F006 | Unknown if `preview.alleghenycounty.us` is publicly resolvable; public curl verify fails on internal DNS | confirm; else self-hosted runner or in-cluster verify
BLK-004 | 2026-09-28 | F004 | KEDA core version / HTTP add-on chart version to pin unknown | check cluster (`--enable-keda` managed vs Helm) and pick compatible add-on
BLK-006 | 2026-09-28 | PR loop | `gh` authed as `nimatrazmjo` — not collaborator on `nimat-dev/ephemeral-environments`; `gh pr create` fails (git push via SSH works) | `gh auth login` as org account, or add `nimatrazmjo` as collaborator, or open PR in browser
BLK-005 | 2026-09-28 | F004 | Domain = preview.nimat.dev (DEC-020). nimat.dev DNS at Namecheap (dns1/dns2.registrar-servers.com). Needs NS records for host `preview` → Azure zone name servers | F013 creates zone + prints NS; human adds 4 NS records in Namecheap
```

## Resolved
```
(id | resolved | how)
BLK-007 | 2026-09-28 | brew install failed (Xcode license, needs sudo) -> installed yamllint (pipx), kubeconform (go install), bats (npm); DEC-015
```
