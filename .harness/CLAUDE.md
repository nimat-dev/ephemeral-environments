# CLAUDE.md — Session Bootstrap

Quick reference. `AGENTS.md` is the full contract; this is the checklist you run every session.

## On session start (in order)
1. Read `PROJECT_STATE.md` — the master file. Where we are.
2. Read `CURRENT_TASK.md` — the one feature + its exact next step.
3. Read `ROADMAP.md` — the feature list + statuses.
4. Read the active phase file under `phases/` — acceptance criteria.
5. Read `DECISIONS.md` + `BLOCKERS.md`.
6. Run `init` (see `scripts/SCRIPTS.md`) to confirm a clean baseline.
7. **Inspect the actual code.** Never trust the tracking files blindly — the codebase is
   the truth for what exists. If they disagree, correct the tracking files and note it in
   `CHANGELOG.md`.

## The one rule you break most often
Work the ONE feature that is `IN PROGRESS`. Evidence before you move on. Don't "quickly
also add" the next thing.

## Where things live
| I need to know... | Read |
|---|---|
| Where the project is right now | `PROJECT_STATE.md` (master) |
| What to do next | `CURRENT_TASK.md` |
| The whole feature list + status | `ROADMAP.md` |
| Acceptance for the current feature | the active `phases/PHASE-XX-*.md` |
| What's been shipped | `CHANGELOG.md` |
| What's decided (don't relitigate) | `DECISIONS.md` (+ `architecture/decisions/` ADRs) |
| What's stuck | `BLOCKERS.md` |
| Why / for whom | `product/PRODUCT.md`, `product/PERSONAS.md` |
| How it's structured / the data shape | `architecture/ARCHITECTURE.md`, `DATA_MODEL.md` |
| What I may import | `rules/layer-boundaries.md` |
| What's off-limits now | `rules/scope-guard.md` |
| How I prove it works | `verification/evaluator-rubric.md`, `acceptance-evidence.md` |
| The edge cases I must cover | `verification/edge-cases.md` |
| What to do when state is abnormal | `loops/failure-modes.md` |

## Commands
Toolchain: helm, kubectl, az, actionlint, shellcheck, yamllint, kubeconform, bats, jq, yq (mikefarah v4, F016), tofu 1.12.6 + tflint + checkov (F018).

| Action | Command |
|---|---|
| Install | `brew install helm kubectl azure-cli actionlint shellcheck yamllint kubeconform bats-core jq` (no brew: `pipx install yamllint`, `go install github.com/yannh/kubeconform/cmd/kubeconform@latest`, `npm i -g bats`, `go install github.com/mikefarah/yq/v4@v4.54.1`; OpenTofu/tflint: GitHub release zips → ~/.local/bin; `pipx install checkov`) |
| Dev server | N/A (infra repo) |
| Typecheck | `helm template t ./deploy/preview -f tests/fixtures/values.yaml \| kubeconform -strict -summary -ignore-missing-schemas` |
| Lint | `yamllint . && shellcheck scripts/*.sh scripts/lib/*.sh bootstrap/*.sh .claude/hooks/*.sh && actionlint && helm lint ./deploy/preview` |
| Test (full suite) | `bats tests/` |
| E2E | `./scripts/smoke.sh` (real cluster, Part C); Phase 02+: dispatch `Deploy Preview` on a test branch |
| Build | `helm template t ./deploy/preview -f tests/fixtures/values.yaml` |
| Verify baseline | `./scripts/init.sh` (roadmap gate + lint + template + kubeconform + bats + check-architecture); `--roadmap-only` for just the gate |
| Check boundaries | `./scripts/check-architecture.sh [--root DIR]` |
| Progress % | see `scripts/SCRIPTS.md` → progress-counter |

(Commands for paths that don't exist yet are skipped by `init.sh` until their feature lands.)

## Current target
Roadmap COMPLETE (13/13, 2026-09-29). No active feature — see `CURRENT_TASK.md` for follow-ups.

## Before you stop
Run the Session-completion protocol in `AGENTS.md`: update PROJECT_STATE, CURRENT_TASK,
ROADMAP (+ phase file), CHANGELOG, BLOCKERS/DECISIONS as needed; leave the tree clean
(`state/clean-state-checklist.md`); commit on `feat/<FID>` (or `docs/<slug>`/`chore/<slug>`
for harness-only work). If the feature just went COMPLETE: push, open/reuse the PR, review
it, fix findings, and repeat until clean before starting the next feature
(`loops/pr-review-loop.md`).
