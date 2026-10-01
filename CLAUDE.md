# CLAUDE.md

The canonical, agent-agnostic instructions are in AGENTS.md (DEC-052) — read them first:

@AGENTS.md

Claude Code specifics (imported so they are always in context):

@.harness/CLAUDE.md
@.harness/AGENTS.md

Project hooks in `.claude/settings.json` (`.claude/hooks/`): session start injects harness state, each prompt gets
a reminder, and Stop is blocked if files outside `.harness/` changed without a `.harness/PROJECT_STATE.md` update.
Slash commands `/harness-start-session`, `/harness-start-feature`, `/harness-finish-session` are generated from
`.harness/commands/` (`scripts/sync-agent-commands.sh`).
