# PR review — #13 feat/F009 (preview-deployer-guard), 2026-09-29

Round 1 (`/code-review medium 13`): guard logic sound (SP-oid match, ns by name, rest by namespace, cluster-scoped denied).

| # | Where | Finding | Outcome |
|---|---|---|---|
| 1 | `.claude/settings.json` (low) | user's permission rule `Bash(./bootstrap/a5-github-oidc.sh --apply*)` (added during this session) swept into the PR via `git add -A` — would pre-approve a5 --apply for every future agent session; `*` also matches `--env <any file>`; file re-indented | fixed by user: `settings.json` restored to main; rule (exact `--apply`, no `*`) now in gitignored `.claude/settings.local.json` |
| 2 | a5 probes (low) | `delete namespace keda` needs A4 ns (NotFound → false "not effective"); allow probe fails if `preview-guard-probe` exists (AlreadyExists) | fixed: probe `label namespace default` (UPDATE, always exists); AlreadyExists = allowed; bats `A5 apply: probe namespace already exists…`; live re-apply "guard verified" |

Round 2: `./scripts/init.sh` BASELINE GREEN (bats 158/158). Round 3: #1 fixed; no open findings. Clean.
