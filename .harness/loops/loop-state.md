# Loop State

Live state for the maker-checker loop. Overwrite the "Current" block each round; append
finished features to History. A cold agent reads this to know which round it is on. The
active feature also lives in `../CURRENT_TASK.md`; keep them consistent.

## Parameters (current feature)
- Feature: F006 — preview-deploy.yml
- REQUIRED_PASSES: 2
- MAX_ROUNDS: 6

## Current
- Round: 0
- consecutivePasses: 0
- Last Maker change: none (F004 not started)
- Last Checker verdict: none
- Standing defects: none
- Next action: F006 sprint contract (after BLK-006 for real e2e)

## History
```
(feature id | rounds used | final verdict | date)
F005 | 2 rounds (checker hardened asleep/ready) | PASS 5.0 | 2026-09-28
F004 | 3 rounds (cpu sizing, can-i fixes) | PASS 4.6 | 2026-09-28
F013 | 2 rounds (real-apply bugs fixed) | PASS 4.8 | 2026-09-28
F003 | 1 round (2 consecutive passes) | PASS 4.8 | 2026-09-28
F002 | 1 round (2 consecutive passes) | PASS 5.0 | 2026-09-28
F001 | 1 round (2 consecutive passes: checker run + post-tracking init) | PASS 4.8 | 2026-09-28
```

## Escalations
```
(date | feature | reason | resolution)
--- none yet ---
```
