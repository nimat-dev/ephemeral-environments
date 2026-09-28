# Loop State

Live state for the maker-checker loop. Overwrite the "Current" block each round; append
finished features to History. A cold agent reads this to know which round it is on. The
active feature also lives in `../CURRENT_TASK.md`; keep them consistent.

## Parameters (current feature)
- Feature: F002 — Pure core scripts/lib/preview.sh
- REQUIRED_PASSES: 2
- MAX_ROUNDS: 6

## Current
- Round: 0
- consecutivePasses: 0
- Last Maker change: none (F002 not started)
- Last Checker verdict: none
- Standing defects: none
- Next action: write the sprint contract for F002

## History
```
(feature id | rounds used | final verdict | date)
F001 | 1 round (2 consecutive passes: checker run + post-tracking init) | PASS 4.8 | 2026-09-28
```

## Escalations
```
(date | feature | reason | resolution)
--- none yet ---
```
