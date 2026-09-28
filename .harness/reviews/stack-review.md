# PR review — Phase 01 stack (#1–#7), 2026-09-28

Checker pass over each stacked diff (code, not harness prose). Round 1.

| PR | Branch | Findings | Outcome |
|---|---|---|---|
| #1 | chore/harness-and-todo | nit: `todo/` UI is Vite starter, not a todo list; nit: stop guard misses a file dirty at baseline and re-edited | accepted (notes) |
| #2 | feat/F001 | **rule 3 bypass**: `secrets.GITHUB_TOKEN_ADMIN` + `secrets['X']` reported clean (probe reproduced) | fixed 73a98ac (+3 tests) |
| #3 | feat/F002 | none | clean |
| #4 | feat/F003 | nit: nginx annotations inert under Traefik (spec byte-identical; smoke proves routing) | accepted |
| #5 | feat/F013 | follow-up: teardown leaves Entra app `gh-preview-deployer` + UAMI `cert-manager-dns` | accepted → BLK-008 follow-up |
| #6 | feat/F004 | **security**: CI ClusterRole granted cluster-wide secrets read (wildcard TLS key) | fixed (DEC-026), applied live, impersonation + SP helm install evidence |
| #7 | feat/F005 | nit: `--image` without value exits 1 not 2 | accepted |

Round 2: `./scripts/init.sh` GREEN on feat/F001 tip and feat/F005 tip (all fixes merged); re-read fix diffs — no new findings. Stack clean.
CI: no workflows exist yet (F006 adds the first) — CI gate N/A for these PRs.
