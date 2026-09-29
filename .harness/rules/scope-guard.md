# Scope Guard

What is **off-limits right now**. Scope creep is the most common agent failure; this file is
the leash. The active phase is whatever `PROJECT_STATE.md` says. Building ahead of it is a
defect, not initiative. Phases are gated (ROADMAP.md order); a phase's features may not start
until the previous phase's completion criteria pass.

## Current phase: Phase 02 — Workflows (Phase 01 COMPLETE 2026-09-28)

### In scope (current phase only)
- F006 — `preview-deploy.yml`
- F007 — `preview-destroy.yml`
- F008 — `preview-reap.yml`

### Off-limits until their phase (do NOT build now)
- **Phase 03 — Hardening**: F009 namespace-prefix admission guard, F010 quota enforcement proof,
  F011 env reviewers + ACR retention.
- **Never (non-goals)**: Knative, external-dns, hard force-to-0 CronJob, per-commit previews —
  unless a new DEC supersedes.

## Rules of the guard
1. If a task tempts you outside the current phase, stop. Note it in `BLOCKERS.md` (or as a
   future feature in `ROADMAP.md`) and keep going on the active feature.
2. No dependency unless the active feature needs it — record new deps in the sprint contract
   with a justification.
3. Design *for* later phases (stable ids, registries, interfaces) but *build* only the
   current phase.
4. If scope is wrong, propose an edit to this file + `ROADMAP.md` — don't silently expand.
   Record the decision in `DECISIONS.md`.
5. Don't skip a phase's completion criteria. A phase is done only when every feature is
   `COMPLETE` with evidence and the phase smoke test is green.

## Why so strict
A solid, tested foundation beats half of every phase started. Early substrate multiplies its
shakiness across everything built on top of it.
