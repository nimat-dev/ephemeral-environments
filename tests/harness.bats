#!/usr/bin/env bats
# F022: agent-agnostic harness — harness-check.sh (roadmap gate, state rule, mirrors), command sync,
# entry files, CI workflow, Copier template (render + gate passes in the generated repo).

ROOT="$BATS_TEST_DIRNAME/.."
HC="$ROOT/scripts/harness-check.sh"

setup() {
  T="$(mktemp -d)"
  export PATH="$HOME/go/bin:$HOME/.local/bin:$PATH"
  # a minimal git repo carrying the harness pieces under test
  R="$T/repo"; mkdir -p "$R/.harness/commands" "$R/scripts"
  cp "$ROOT/scripts/harness-check.sh" "$ROOT/scripts/sync-agent-commands.sh" "$R/scripts/"
  cp "$ROOT"/.harness/commands/*.md "$R/.harness/commands/"
  printf '# ROADMAP\n- [x] **F001** — done — `COMPLETE`\n- [ ] **F002** — mentions `COMPLETE` in text — `IN PROGRESS`\n' >"$R/.harness/ROADMAP.md"
  echo state >"$R/.harness/PROJECT_STATE.md"
  git -C "$R" init -q && git -C "$R" -c user.name=t -c user.email=t@t add -A && git -C "$R" -c user.name=t -c user.email=t@t commit -qm init
  "$R/scripts/sync-agent-commands.sh" --root "$R" 2>/dev/null
  git -C "$R" add -A && git -C "$R" -c user.name=t -c user.email=t@t commit -qm mirrors
}
teardown() { rm -rf "$T"; }
commit() { git -C "$R" add -A && git -C "$R" -c user.name=t -c user.email=t@t commit -qm "$1"; }

@test "roadmap gate: one IN PROGRESS ok (status = last backtick span); zero or two fail; all done ok" {
  run "$HC" --root "$R"; [ "$status" -eq 0 ]
  printf -- '- [ ] **F003** — x — `IN PROGRESS`\n' >>"$R/.harness/ROADMAP.md"
  run "$HC" --root "$R"; [ "$status" -eq 1 ]; [[ "$output" == *"found 2"* ]] || false
  printf '# ROADMAP\n- [x] **F001** — a — `COMPLETE`\n- [x] **F002** — b — `DEPRECATED`\n' >"$R/.harness/ROADMAP.md"
  run "$HC" --root "$R"; [ "$status" -eq 0 ]
  printf '# ROADMAP\n- [ ] **F001** — a — `NOT STARTED`\n' >"$R/.harness/ROADMAP.md"
  run "$HC" --root "$R"; [ "$status" -eq 1 ]
}

@test "state rule --staged: code change needs PROJECT_STATE staged; harness-only change is fine" {
  echo x >"$R/app.txt"; git -C "$R" add app.txt
  run "$HC" --root "$R" --staged; [ "$status" -eq 1 ]; [[ "$output" == *"  - app.txt"* ]] || false
  echo more >>"$R/.harness/PROJECT_STATE.md"; git -C "$R" add .harness/PROJECT_STATE.md
  run "$HC" --root "$R" --staged; [ "$status" -eq 0 ]
  git -C "$R" reset -q; echo note >>"$R/.harness/DECISIONS.md"; git -C "$R" add .harness/DECISIONS.md
  run "$HC" --root "$R" --staged; [ "$status" -eq 0 ]
}

@test "state rule --range (CI): judged over the whole PR diff" {
  base=$(git -C "$R" rev-parse HEAD)
  echo x >"$R/app.txt"; commit code
  run "$HC" --root "$R" --range "$base...HEAD"; [ "$status" -eq 1 ]
  echo more >>"$R/.harness/PROJECT_STATE.md"; commit state
  run "$HC" --root "$R" --range "$base...HEAD"; [ "$status" -eq 0 ]
  run "$HC" --root "$R" --range "nope...HEAD"; [ "$status" -eq 2 ]
}

@test "mirrors: editing a command source without re-sync fails; re-sync fixes; other prompt files untouched" {
  echo 'extra line' >>"$R/.harness/commands/start-session.md"
  run "$HC" --root "$R"; [ "$status" -eq 1 ]; [[ "$output" == *"out of sync"* ]] || false
  mkdir -p "$R/.github/prompts"; echo mine >"$R/.github/prompts/team.prompt.md"
  "$R/scripts/sync-agent-commands.sh" --root "$R" 2>/dev/null
  run "$HC" --root "$R"; [ "$status" -eq 0 ]
  [ "$(cat "$R/.github/prompts/team.prompt.md")" = mine ]
}

@test "mirrors: Claude commands only when .claude/ exists; --check never creates it" {
  run "$HC" --root "$R"; [ "$status" -eq 0 ]
  [ ! -e "$R/.claude" ]
  mkdir "$R/.claude"
  run "$HC" --root "$R"; [ "$status" -eq 1 ]; [[ "$output" == *".claude/commands missing"* ]] || false
  "$R/scripts/sync-agent-commands.sh" --root "$R" 2>/dev/null
  [ -f "$R/.claude/commands/harness-start-session.md" ]
  run "$HC" --root "$R"; [ "$status" -eq 0 ]
}

@test "generated prompts: valid front matter (quoted description), Copilot agent mode, banner, same body" {
  for n in start-session start-feature finish-session; do
    c="$ROOT/.claude/commands/harness-$n.md" g="$ROOT/.github/prompts/harness-$n.prompt.md"
    [ "$(sed -n '2,/^---$/p' "$g" | sed '$d' | yq -r .mode)" = agent ]
    [ "$(sed -n '2,/^---$/p' "$c" | sed '$d' | yq -r .description)" = "$(head -1 "$ROOT/.harness/commands/$n.md" | sed 's/^# //')" ]
    grep -q "GENERATED from .harness/commands/$n.md" "$g"
    # body after the banner == the source minus its title line, for both agents
    diff <(tail -n +2 "$ROOT/.harness/commands/$n.md") <(awk 'f;/GENERATED from/{f=1}' "$g")
    diff <(tail -n +2 "$ROOT/.harness/commands/$n.md") <(awk 'f;/GENERATED from/{f=1}' "$c")
  done
}

@test "this repo passes its own gate; pre-commit hook delegates to harness-check --staged" {
  run "$HC"; [ "$status" -eq 0 ]
  grep -q 'scripts/harness-check.sh" --staged' "$ROOT/.githooks/pre-commit"
  [ -x "$ROOT/.githooks/pre-commit" ]
}

@test "entry files: AGENTS.md canonical; CLAUDE.md imports it; Copilot instructions point to it" {
  head -1 "$ROOT/AGENTS.md" | grep -qx '# AGENTS.md'
  grep -qx '@AGENTS.md' "$ROOT/CLAUDE.md"
  grep -qF '[`AGENTS.md`](../AGENTS.md)' "$ROOT/.github/copilot-instructions.md"
  grep -q 'harness-check' "$ROOT/AGENTS.md"
}

@test "CI: harness-check runs on PRs + main, read-only token, full history, range from the event" {
  W="$ROOT/.github/workflows/harness-check.yml"
  [ "$(yq -r '.permissions | to_entries | map(.key + ":" + .value) | join(",")' "$W")" = 'contents:read' ]
  [ "$(yq -r '.on | keys | sort | join(",")' "$W")" = 'pull_request,push' ]
  [ "$(yq -r '.jobs.harness-check.steps[0].with.fetch-depth' "$W")" = 0 ]
  [ "$(yq -r '.jobs.harness-check.steps[1].run' "$W")" = './scripts/harness-check.sh --range "$BASE_SHA...$HEAD_SHA"' ]
}

@test "Copier template: generic files identical to this repo's (no drift)" {
  run "$ROOT/scripts/build-harness-template.sh" --check
  [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "Copier template renders a repo whose own gate passes (with and without Claude hooks)" {
  command -v copier >/dev/null || skip "copier not installed"
  for hooks in true false; do
    out="$T/new-$hooks"
    copier copy --defaults --quiet --vcs-ref HEAD --data project_name=Acme --data "claude_hooks=$hooks" \
      "$ROOT/templates/harness" "$out"
    [ -f "$out/AGENTS.md" ] && grep -q 'Acme' "$out/AGENTS.md"
    grep -q 'F001' "$out/.harness/ROADMAP.md"
    ( cd "$out" && git init -q && ./scripts/harness-check.sh )
    if [ "$hooks" = true ]; then [ -f "$out/.claude/settings.json" ] && [ -f "$out/CLAUDE.md" ]
    else [ ! -e "$out/.claude" ] && [ ! -e "$out/CLAUDE.md" ]; fi
    [ -f "$out/.github/prompts/harness-start-session.prompt.md" ]
  done
}
