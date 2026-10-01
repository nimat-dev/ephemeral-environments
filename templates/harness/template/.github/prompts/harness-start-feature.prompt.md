---
mode: agent
description: "Start the next feature: branch, sprint contract, tests first"
---
<!-- GENERATED from .harness/commands/start-feature.md by scripts/sync-agent-commands.sh — edit the source. -->
1. Confirm in `.harness/ROADMAP.md` that the previous feature is `COMPLETE` and exactly one feature is `IN PROGRESS`.
2. Branch `feat/<FID>` from the default branch.
3. Write `.harness/verification/contracts/<FID>.md` from `verification/sprint-contract.md`: acceptance criteria copied
   from the phase file, the applicable `verification/edge-cases.md` battery, the e2e scenario, out-of-scope items.
4. Record any new decision in `.harness/DECISIONS.md` before relying on it.
5. Write failing tests first, then implement (Maker). Keep every step small and reversible.
