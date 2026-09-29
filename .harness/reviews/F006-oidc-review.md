# PR review — #12 feat/F006-oidc (a5 immutable OIDC subject), 2026-09-29

Round 1 (`/code-review medium 12`, Checker pass over code diff):

| # | Where | Finding | Outcome |
|---|---|---|---|
| 1 | a5:82 (medium) | failed `gh api` lookup (no gh/auth/access) silently treated as legacy → immutable FIC skipped, AADSTS700213 returns | fixed: lookup failure → `--apply` exits 1, dry-run warns (bats `A5: OIDC prefix lookup fails`) |
| 2 | a5 `ensure_fic` (low) | checked name only; subject drift (repo rename/transfer) left stale subject | fixed: compares stored subject, `federated-credential update` on drift (bats `A5: federated credential subject drift`) |
| 3 | bats:193 (low) | legacy-prefix run didn't assert `$status` | fixed |

Round 2: `./scripts/init.sh` BASELINE GREEN, bats 154/154; live dry-run vs Entra app: both FICs "skip (exists)", real `[?name=='X'].subject | [0]` query returns stored subject / empty. Clean.
CI: repo has no PR workflows — gate N/A (same as #8–#11).
