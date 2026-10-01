# DECISIONS

Append-only log. Newest first. Don't relitigate a recorded decision — supersede it with a new one.

## Format
`DEC-NNN (YYYY-MM-DD): <decision>. — <why>`

DEC-001: Project harness from the Copier template (agent-agnostic: AGENTS.md canonical, `scripts/harness-check.sh` in
pre-commit + CI). — every agent (Copilot, Claude, others) and every human follows the same loop.
