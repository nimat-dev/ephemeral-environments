# Loop State

Live state for the maker-checker loop. Overwrite the "Current" block each round; append
finished features to History. A cold agent reads this to know which round it is on. The
active feature also lives in `../CURRENT_TASK.md`; keep them consistent.

## Parameters (current feature)
- Feature: F013 — Provision Azure prerequisites
- REQUIRED_PASSES: 2
- MAX_ROUNDS: 6

## Current
- Round: 0
- consecutivePasses: 0
- Last Maker change: provision.sh/teardown.sh + tests (offline)
- Last Checker verdict: none
- Standing defects: none
- Next action: human OK → --apply → online evidence → Checker

## History
```
(feature id | rounds used | final verdict | date)
F003 | 1 round (2 consecutive passes) | PASS 4.8 | 2026-09-28
F002 | 1 round (2 consecutive passes) | PASS 5.0 | 2026-09-28
F001 | 1 round (2 consecutive passes: checker run + post-tracking init) | PASS 4.8 | 2026-09-28
```

## Escalations
```
(date | feature | reason | resolution)
--- none yet ---
```
