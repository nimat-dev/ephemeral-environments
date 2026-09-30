# AGENTS.md

Canonical instructions for every coding agent in this repo — GitHub Copilot, Claude Code, Codex, or any
other (DEC-052). Agent-specific files only point here: `CLAUDE.md` (imports this), `.github/copilot-instructions.md`.

**What this repo is**: per-branch preview environments on AKS (idle scale-to-zero, wake-on-request), shipped as a
reusable kit other repos consume, the OpenTofu platform + Flux GitOps behind it, and a sample `todo/` app.
All project state, rules and specs live in [`.harness/`](.harness/README.md).

## Start every session here
1. Read the operating contract [`.harness/AGENTS.md`](.harness/AGENTS.md) (the ten rules — it overrides your
   defaults) and the session checklist [`.harness/CLAUDE.md`](.harness/CLAUDE.md) (agent-neutral despite the name).
2. Then, in order: [`PROJECT_STATE.md`](.harness/PROJECT_STATE.md) (master file) →
   [`CURRENT_TASK.md`](.harness/CURRENT_TASK.md) (the ONE feature in progress + exact next step) →
   [`ROADMAP.md`](.harness/ROADMAP.md) → the active [`phases/`](.harness/phases/) file →
   [`DECISIONS.md`](.harness/DECISIONS.md) + [`BLOCKERS.md`](.harness/BLOCKERS.md).
3. Every request maps to a feature id (or a proposed one); work only the one `IN PROGRESS` feature.
4. Before you stop: the Session-completion protocol in `.harness/AGENTS.md` (evidence in CHANGELOG, tracking files updated).

Reusable prompts for the loop (same text for every agent, generated from [`.harness/commands/`](.harness/commands/)):
`harness-start-session`, `harness-start-feature`, `harness-finish-session` — Claude: `/harness-…` commands;
Copilot: `#harness-…` prompt files in `.github/prompts/`.

## Enforcement (works for any agent, and for humans)
- `scripts/harness-check.sh`: roadmap gate (one `IN PROGRESS`), state rule (changes outside `.harness/` need a
  `.harness/PROJECT_STATE.md` update), agent command mirrors in sync.
- Pre-commit: `git config core.hooksPath .githooks` once per clone → runs it on every commit (`--staged`).
- CI: `harness-check` workflow on every PR — a required status check on `main`.
- Claude Code additionally gets session hooks (`.claude/settings.json`); they are a convenience, not the gate.

## Commands
`scripts/init.sh` is the full baseline (lint, chart render + kubeconform, bats, OpenTofu fmt/validate/test,
tflint, checkov, check-architecture). Toolchain and every other command: [`.harness/CLAUDE.md`](.harness/CLAUDE.md) → Commands.

## Key references
- Source spec: [`.harness/preview-environments-implementation.md`](.harness/preview-environments-implementation.md)
- Architecture: [`.harness/architecture/`](.harness/architecture/ARCHITECTURE.md) · boundaries:
  [`rules/layer-boundaries.md`](.harness/rules/layer-boundaries.md) · scope: [`rules/scope-guard.md`](.harness/rules/scope-guard.md)

## Repo layout
```
.harness/     tracking system, rules, specs, evidence (no app code)
kit/          composite action; .github/workflows/kit-*.yml = the reusable preview kit (F021)
scripts/      preview-ci.sh (+ lib), init.sh, harness-check.sh, kit-release.sh, …
deploy/       Helm chart deploy/preview
platform/     OpenTofu: modules/team-cluster, modules/repo-onboarding, envs/<team>
clusters/     Flux GitOps: base/ + <team>/ (add-ons, issuers/certs, per-repo guards)
bootstrap/    bash bootstrap (a0 state, a7 domains; a1–a6 superseded by OpenTofu/Flux)
examples/     consumer example (kit callers) + echo-api test backend
templates/    Copier template of this harness for new repos (F022)
todo/         Vite + React todo app
```
