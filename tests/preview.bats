#!/usr/bin/env bats
# F002: scripts/lib/preview.sh (pure core). Runs under strict mode like its callers.

setup() {
  set -euo pipefail
  # shellcheck source=../scripts/lib/preview.sh
  . "$BATS_TEST_DIRNAME/../scripts/lib/preview.sh"
}

# The spec's inline sanitizer, verbatim (preview-deploy.yml / preview-destroy.yml).
spec_id() {
  echo "$1" | tr '[:upper:]' '[:lower:]' \
    | sed -E 's#[^a-z0-9]+#-#g; s#^-+##; s#-+$##' | cut -c1-40 | sed -E 's#-+$##'
}

long41="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-bcdef"   # char 40 is "-"

# --- preview_id ---
@test "preview_id matches spec pipeline over corpus" {
  for b in main Feature/JIRA-123_login UPPER release/v1.2.3 a--b a__b 'a/-/b' '--lead' 'trail--' \
           'feat/x' "$long41" "$(printf 'a%.0s' {1..40})" "$(printf 'b%.0s' {1..60})" 'x y  z'; do
    [ "$(preview_id "$b")" = "$(spec_id "$b")" ] || { echo "mismatch for '$b'"; return 1; }
  done
}

@test "preview_id examples" {
  [ "$(preview_id 'Feature/JIRA-123_login')" = feature-jira-123-login ]
  [ "$(preview_id '__a__')" = a ]
  [ "$(preview_id 'a/-/b')" = a-b ]
}

@test "preview_id: exactly 40 chars kept" {
  id=$(preview_id "$(printf 'a%.0s' {1..40})"); [ "${#id}" -eq 40 ]
}

@test "preview_id: >40 with '-' at the cut is trimmed" {
  [ "$(preview_id "$long41")" = "$(printf 'a%.0s' {1..39})" ]
}

@test "preview_id: unicode collapses deterministically" {
  [ "$(preview_id 'fëature/日本語-🚀x')" = f-ature-x ]
}

@test "preview_id: -n and -e are sanitized, not swallowed (spec echo bug)" {
  [ "$(preview_id -n)" = n ]
  [ "$(preview_id -e)" = e ]
}

@test "preview_id: empty, whitespace-only, all-symbol fail" {
  for b in '' '   ' '///' '-_-' '🚀'; do
    run preview_id "$b"; [ "$status" -eq 1 ] || { echo "expected fail for '$b'"; return 1; }
    [[ "$output" == *"empty preview id"* ]] || false
  done
}

@test "namespace and host" {
  [ "$(preview_namespace feat-x)" = preview-feat-x ]
  [ "$(preview_host feat-x preview.example.com)" = feat-x.preview.example.com ]
}

# --- durations ---
@test "to_seconds units" {
  [ "$(to_seconds 15m)" = 900 ]
  [ "$(to_seconds 1h)" = 3600 ]
  [ "$(to_seconds 48h)" = 172800 ]
  [ "$(to_seconds 7d)" = 604800 ]
}

@test "to_seconds: leading zero is decimal, not octal" {
  [ "$(to_seconds 08h)" = 28800 ]
}

@test "to_seconds rejects malformed" {
  for v in '' 12 h 1w 1.5h -1h 1hm ' 1h' 1H; do
    run to_seconds "$v"; [ "$status" -eq 1 ] || { echo "expected fail for '$v'"; return 1; }
  done
}

@test "idle_seconds: never and passthrough" {
  [ "$(idle_seconds never)" = 31536000 ]
  [ "$(idle_seconds 30m)" = 1800 ]
  run idle_seconds forever; [ "$status" -eq 1 ]
}

@test "resolve_lifetime" {
  [ "$(resolve_lifetime 48h '')" = 48h ]
  [ "$(resolve_lifetime custom 3d)" = 3d ]
  run resolve_lifetime custom ''; [ "$status" -eq 1 ]; [[ "$output" == *"lifetime_custom is empty"* ]] || false
}

@test "expires_at with fixed now" {
  [ "$(expires_at 24h 1000)" = 87400 ]
  [ "$(expires_at 7d 0)" = 604800 ]
}

@test "expires_at defaults now to current time" {
  before=$(date -u +%s); got=$(expires_at 1h); after=$(date -u +%s)
  [ "$got" -ge $((before + 3600)) ]; [ "$got" -le $((after + 3600)) ]
}

@test "expires_at rejects zero lifetime, bad lifetime, bad now" {
  run expires_at 0h 1000; [ "$status" -eq 1 ]
  run expires_at 1w 1000; [ "$status" -eq 1 ]
  run expires_at 1h abc;  [ "$status" -eq 1 ]
}

# --- expired_namespaces ---
ns_json() {
  cat <<'JSON'
{"items":[
 {"metadata":{"name":"preview-old","labels":{"managed-by":"preview-bot","preview.expires-at":"100"}}},
 {"metadata":{"name":"preview-edge","labels":{"managed-by":"preview-bot","preview.expires-at":"500"}}},
 {"metadata":{"name":"preview-new","labels":{"managed-by":"preview-bot","preview.expires-at":"900"}}},
 {"metadata":{"name":"preview-nolabel","labels":{"managed-by":"preview-bot"}}},
 {"metadata":{"name":"preview-garbage","labels":{"managed-by":"preview-bot","preview.expires-at":"soon"}}},
 {"metadata":{"name":"kube-system","labels":{"preview.expires-at":"1"}}},
 {"metadata":{"name":"nolabels"}}
]}
JSON
}

@test "expired_namespaces: < now, missing/garbage label expired, foreign ns ignored" {
  run bash -c ". '$BATS_TEST_DIRNAME/../scripts/lib/preview.sh'; expired_namespaces 500" < <(ns_json)
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'preview-old\npreview-nolabel\npreview-garbage')" ]
}

@test "expired_namespaces: expires-at == now is not expired" {
  out=$(ns_json | expired_namespaces 500)
  [[ "$out" != *preview-edge* ]] || false
  out=$(ns_json | expired_namespaces 501)
  [[ "$out" == *preview-edge* ]] || false
}

@test "expired_namespaces: empty list -> no output" {
  [ -z "$(echo '{"items":[]}' | expired_namespaces 500)" ]
}

@test "expired_namespaces: malformed JSON and bad now fail" {
  run bash -c ". '$BATS_TEST_DIRNAME/../scripts/lib/preview.sh'; echo '{bad' | expired_namespaces 500"
  [ "$status" -ne 0 ]
  run expired_namespaces abc; [ "$status" -eq 1 ]
}

@test "sourcing does not change caller shell options" {
  run bash -c 'set +euo pipefail; before=$(set +o); . "'"$BATS_TEST_DIRNAME"'/../scripts/lib/preview.sh"; [ "$before" = "$(set +o)" ]'
  [ "$status" -eq 0 ]
}

# --- max_replicas ---
@test "max_replicas: 1..6 accepted, leading zero decimal" {
  [ "$(max_replicas 1)" = 1 ]
  [ "$(max_replicas 6)" = 6 ]
  [ "$(max_replicas 03)" = 3 ]
}

@test "max_replicas: 0, over quota, negative, non-numeric, empty rejected" {
  for v in 0 7 100 -1 '' abc 2.5 ' 3' 99999999999999999999; do
    run max_replicas "$v"; [ "$status" -eq 1 ] || { echo "expected fail for '$v'"; return 1; }
  done
}

# --- preview_plan ---
@test "preview_plan: happy path emits the full identity" {
  out=$(preview_plan 'Feature/JIRA-1' 48h '' 30m 3 preview.example.com abc1234 1000)
  [ "$out" = "$(printf '%s\n' preview_id=feature-jira-1 namespace=preview-feature-jira-1 \
    host=feature-jira-1.preview.example.com short_sha=abc1234 idle=1800 max_replicas=3 \
    lifetime=48h expires_at=173800)" ]
}

@test "preview_plan: custom lifetime and never idle" {
  out=$(preview_plan main custom 12h never 1 d.example abc1234 0)
  [[ "$out" == *"lifetime=12h"* ]] || false
  [[ "$out" == *"expires_at=43200"* ]] || false
  [[ "$out" == *"idle=31536000"* ]] || false
}

@test "preview_plan: every invalid input fails and prints nothing on stdout" {
  bad() { run bash -c ". '$BATS_TEST_DIRNAME/../scripts/lib/preview.sh'; preview_plan \"\$@\" 2>/dev/null" _ "$@"
          [ "$status" -eq 1 ] && [ -z "$output" ] || { echo "expected fail: $*"; return 1; }; }
  bad '///' 48h '' 30m 3 d.example abc1234 0      # empty id
  bad main custom '' 30m 3 d.example abc1234 0    # custom without value
  bad main custom 1w 30m 3 d.example abc1234 0    # bad custom unit
  bad main custom 0h 30m 3 d.example abc1234 0    # zero lifetime
  bad main 48h '' forever 3 d.example abc1234 0   # bad idle
  bad main 48h '' 30m 0 d.example abc1234 0       # bad replicas
  bad main 48h '' 30m 3 '' abc1234 0              # no domain
  bad main 48h '' 30m 3 d.example '' 0            # no sha
  bad main 48h '' 30m 3 d.example 'ab;rm' 0       # non-hex sha
}

# --- namespace_manifest ---
@test "namespace_manifest: label contract + raw branch escaped into annotation" {
  br='Feat/"quoted" $(x) `y`'
  m=$(namespace_manifest preview-feat-quoted feat-quoted abc1234 1700000000 "$br")
  [ "$(jq -r .kind <<<"$m")" = Namespace ]
  [ "$(jq -r .metadata.name <<<"$m")" = preview-feat-quoted ]
  [ "$(jq -c .metadata.labels <<<"$m")" = '{"managed-by":"preview-bot","preview.branch":"feat-quoted","preview.commit":"abc1234","preview.expires-at":"1700000000"}' ]
  [ "$(jq -r '.metadata.annotations["preview.branch-original"]' <<<"$m")" = "$br" ]
}
