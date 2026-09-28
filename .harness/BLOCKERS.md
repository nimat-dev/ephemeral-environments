# BLOCKERS — what's stuck

Open blockers first. Close a blocker by moving it to Resolved with the fix + date. A parked
out-of-scope temptation (scope-guard) also lands here until it becomes a real ROADMAP feature.

## Open
```
(id | opened | feature | description | what would unblock it)
BLK-001 | 2026-09-28 | F004,F005,F006+ | No real Azure values (sub, tenant, ACR, AKS, RGs, DNS zone, GitHub org/repo) | human provides values / access
BLK-002 | 2026-09-28 | F006 | PARTIAL: app = `todo/` confirmed long-term target (DEC-012). Remaining: spec's deploy builds `context: .` -> must become `context: todo` | F006 sets build context to `todo`
BLK-003 | 2026-09-28 | F006 | Unknown if `preview.alleghenycounty.us` is publicly resolvable; public curl verify fails on internal DNS | confirm; else self-hosted runner or in-cluster verify
BLK-004 | 2026-09-28 | F004 | KEDA core version / HTTP add-on chart version to pin unknown | check cluster (`--enable-keda` managed vs Helm) and pick compatible add-on
BLK-005 | 2026-09-28 | F004 | Control of `preview.` sub-zone delegation under alleghenycounty.us unconfirmed | DNS owner delegates sub-zone
```

## Resolved
```
(id | resolved | how)
--- none ---
```
