#!/usr/bin/env bash
# UserPromptSubmit: short reminder to route the request through the harness.
set -euo pipefail
msg="Harness reminder: before acting, name the feature id this request maps to (or propose a new one / flag as out of scope per .harness/rules/scope-guard.md). Finish with CHANGELOG evidence + PROJECT_STATE/CURRENT_TASK updates."
jq -n --arg c "$msg" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$c}}'
