---
description: "Start a harness session: read state, confirm the one IN PROGRESS feature, verify the baseline"
---
<!-- GENERATED from .harness/commands/start-session.md by scripts/sync-agent-commands.sh — edit the source. -->
Follow the harness bootstrap (`.harness/CLAUDE.md` checklist, `.harness/AGENTS.md` contract):

1. Read, in order: `.harness/PROJECT_STATE.md`, `.harness/CURRENT_TASK.md`, `.harness/ROADMAP.md`, the active
   `.harness/phases/PHASE-*.md`, `.harness/DECISIONS.md`, `.harness/BLOCKERS.md`.
2. Name the ONE feature that is `IN PROGRESS` and its exact next step. If the request is something else, map it to a
   feature id or propose one (ROADMAP + phase file); off-phase work goes to `rules/scope-guard.md` / BLOCKERS.
3. Run the baseline (`scripts/init.sh`, or `scripts/harness-check.sh` where there is no init) and inspect the code;
   if tracking and code disagree, fix the tracking files and note it in CHANGELOG.
4. Reply with: feature id, status, next step, baseline result.
