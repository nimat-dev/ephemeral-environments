# Scope Guard

What is **off-limits right now**. The active phase is whatever `PROJECT_STATE.md` says. Building ahead of it is a
defect, not initiative. Phases are gated (ROADMAP order).

## Current phase: Phase 01 — Foundation

### In scope (current phase only)
- F001 (IN PROGRESS) — see `phases/PHASE-01-FOUNDATION.md`.

### Off-limits until their phase (do NOT build now)
- TODO: later phases' features.

## Rules of the guard
1. If a task tempts you outside the current phase, stop. Note it in `BLOCKERS.md` (or as a future feature in
   `ROADMAP.md`) and keep going on the active feature.
2. No dependency unless the active feature needs it — record new deps in the sprint contract.
3. Design *for* later phases (stable ids, registries, interfaces) but *build* only the current phase.
4. If scope is wrong, propose an edit to this file + `ROADMAP.md` — don't silently expand. Record it in `DECISIONS.md`.
5. Don't skip a phase's completion criteria.
