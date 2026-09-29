#!/usr/bin/env bats
# F001: scripts/init.sh ROADMAP gate.

INIT="$BATS_TEST_DIRNAME/../scripts/init.sh"

setup() { F="$(mktemp)"; }
teardown() { rm -f "$F"; }

header() {
  printf '%s\n' 'Statuses: `NOT STARTED` · `IN PROGRESS` · `COMPLETE`' '' >"$F"
}

@test "roadmap: exactly one IN PROGRESS passes (status legend line ignored)" {
  header
  printf '%s\n' '- [ ] **F001** — a — `IN PROGRESS`' '- [ ] **F002** — b — `NOT STARTED`' >>"$F"
  run "$INIT" --roadmap-only --roadmap "$F"
  [ "$status" -eq 0 ]
}

@test "roadmap: zero IN PROGRESS fails" {
  header
  printf '%s\n' '- [ ] **F001** — a — `NOT STARTED`' >>"$F"
  run "$INIT" --roadmap-only --roadmap "$F"
  [ "$status" -eq 1 ]; [[ "$output" == *"found 0"* ]] || false
}

@test "roadmap: all COMPLETE/DEPRECATED passes (roadmap finished)" {
  header
  printf '%s\n' '- [x] **F001** — a — `COMPLETE`' '- [x] **F002** — b — `DEPRECATED`' >>"$F"
  run "$INIT" --roadmap-only --roadmap "$F"
  [ "$status" -eq 0 ]; [[ "$output" == *"roadmap complete: all 2 features"* ]] || false
}

@test "roadmap: zero IN PROGRESS with one NOT STARTED left still fails" {
  header
  printf '%s\n' '- [x] **F001** — a — `COMPLETE`' '- [ ] **F002** — b — `NOT STARTED`' >>"$F"
  run "$INIT" --roadmap-only --roadmap "$F"
  [ "$status" -eq 1 ]; [[ "$output" == *"found 0"* ]] || false
}

@test "roadmap: two IN PROGRESS fails" {
  header
  printf '%s\n' '- [ ] **F001** — a — `IN PROGRESS`' '- [ ] **F002** — b — `IN PROGRESS`' >>"$F"
  run "$INIT" --roadmap-only --roadmap "$F"
  [ "$status" -eq 1 ]; [[ "$output" == *"found 2"* ]] || false
}

@test "roadmap: empty file fails" {
  : >"$F"
  run "$INIT" --roadmap-only --roadmap "$F"
  [ "$status" -eq 1 ]
}

@test "roadmap: missing file fails" {
  run "$INIT" --roadmap-only --roadmap "$F.missing"
  [ "$status" -eq 1 ]; [[ "$output" == *"not found"* ]] || false
}

@test "real ROADMAP passes the gate" {
  run "$INIT" --roadmap-only
  [ "$status" -eq 0 ]
}

@test "unknown argument exits 2" {
  run "$INIT" --bogus
  [ "$status" -eq 2 ]
}
