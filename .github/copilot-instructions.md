# Copilot instructions

Follow [`AGENTS.md`](../AGENTS.md) at the repository root — it is the canonical, agent-agnostic contract for this
repo (DEC-052). In short:

- Start by reading `.harness/PROJECT_STATE.md`, `.harness/CURRENT_TASK.md`, `.harness/ROADMAP.md` and the rules in
  `.harness/AGENTS.md`. Work only the ONE feature marked `IN PROGRESS`; map every request to a feature id.
- No victory without evidence: run `scripts/init.sh` and record results in `.harness/CHANGELOG.md`.
- Any change outside `.harness/` must come with a `.harness/PROJECT_STATE.md` update — `scripts/harness-check.sh`
  enforces this in the pre-commit hook and in the required `harness-check` CI check.
- Reusable prompts: `.github/prompts/harness-*.prompt.md` (generated from `.harness/commands/`; edit the source).
