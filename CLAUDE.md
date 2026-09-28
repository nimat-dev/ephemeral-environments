# CLAUDE.md

Per-branch preview environments on AKS (idle scale-to-zero, wake-on-request) + a sample
`todo/` app to preview. All project state, rules, and specs live in [`.harness/`](.harness/README.md).

## Start every session here
Follow the harness bootstrap and operating contract:

@.harness/CLAUDE.md
@.harness/AGENTS.md

Then read, in order:
1. [`.harness/PROJECT_STATE.md`](.harness/PROJECT_STATE.md) — master file: where we are.
2. [`.harness/CURRENT_TASK.md`](.harness/CURRENT_TASK.md) — the one feature in progress.
3. [`.harness/ROADMAP.md`](.harness/ROADMAP.md) — all features + status.
4. Active phase file in [`.harness/phases/`](.harness/phases/).
5. [`.harness/DECISIONS.md`](.harness/DECISIONS.md) + [`.harness/BLOCKERS.md`](.harness/BLOCKERS.md).

## Key references
- Source spec: [`.harness/preview-environments-implementation.md`](.harness/preview-environments-implementation.md) — wins on exact file contents.
- Architecture: [`.harness/architecture/`](.harness/architecture/ARCHITECTURE.md)
- Boundaries: [`.harness/rules/layer-boundaries.md`](.harness/rules/layer-boundaries.md)
- Scope: [`.harness/rules/scope-guard.md`](.harness/rules/scope-guard.md)

## Enforcement
Project hooks in `.claude/settings.json` (see `.claude/hooks/`): session start injects
harness state, each prompt gets a reminder, and Stop is blocked if files outside
`.harness/` changed without a `.harness/PROJECT_STATE.md` update.

## Repo layout
```
.claude/    project hooks enforcing the harness loop
.harness/   tracking system, rules, specs (no app code)
todo/       Vite + React todo app; Dockerfile → nginx-unprivileged on :8080
```
