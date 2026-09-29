# F007 review — PR #10

## Round 1 (2026-09-28) — CLEAN
- Identity: destroy uses `preview_id` + `preview_namespace` (lib), no inline sanitizer (rule 2). OK
- Safety: ownership checked from live object before delete; `kubectl get` failure aborts before any delete (bats). OK
- Race: owner check → delete is not atomic (label could change in between); acceptable — only preview-bot writes the label.
- Injection: branch only via env; namespace name is lib-sanitized. OK
Accepted note: `--wait=false` returns while Terminating (spec behavior).
