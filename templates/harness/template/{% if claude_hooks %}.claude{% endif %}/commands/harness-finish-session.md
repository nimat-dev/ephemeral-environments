---
description: "Finish a session: evidence, tracking files, commit — the Session-completion protocol"
---
<!-- GENERATED from .harness/commands/finish-session.md by scripts/sync-agent-commands.sh — edit the source. -->
Run the Session-completion protocol from `.harness/AGENTS.md`:

1. Run the full verify (`scripts/init.sh`) and the e2e for any user-facing flow; save output under `.harness/evidence/<FID>/`.
2. Score as Checker with `verification/evaluator-rubric.md` — no approval by assertion.
3. Update the phase file + `ROADMAP.md` (status, counts), `CURRENT_TASK.md` (exact next step), `PROJECT_STATE.md`
   (phase, feature, last verified, git), `CHANGELOG.md` (evidence), `BLOCKERS.md` / `DECISIONS.md` as needed.
4. `scripts/harness-check.sh --staged` must pass (the pre-commit hook runs it), then commit on `feat/<FID>`.
5. If the feature went COMPLETE: push, open/reuse the PR, review it, fix findings until clean (`loops/pr-review-loop.md`).
