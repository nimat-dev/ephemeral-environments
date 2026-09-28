# Scope Guard

What is **off-limits right now**. Scope creep is the most common agent failure; this file is
the leash. The active phase is whatever `PROJECT_STATE.md` says. Building ahead of it is a
defect, not initiative. Phases are gated (ROADMAP.md order); a phase's features may not start
until the previous phase's completion criteria pass.

## Current phase: Phase 01 — Foundation

### In scope (current phase only)
- F001 — repo tooling: `init.sh`, `check-architecture.sh`, lint configs
- F002 — pure core `scripts/lib/preview.sh` + bats tests
- F003 — Helm chart `deploy/preview` (Part B)
- F004 — bootstrap scripts + manifests (Part A)
- F005 — smoke test script (Part C)

### Off-limits until their phase (do NOT build now)
- **Phase 02 — Workflows**: `preview-deploy.yml`, `preview-destroy.yml`, `preview-reap.yml`.
- **Phase 03 — Hardening**: scoped k8s `ClusterRole` replacing Azure RBAC Writer, quota
  enforcement proof, `preview` env reviewers, ACR retention policy.
- **Never (non-goals)**: Knative, external-dns, hard force-to-0 CronJob, per-commit
  previews — unless a new DEC supersedes.

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
