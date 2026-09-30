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
  [ "$(preview_namespace todo feat-x)" = preview-todo-feat-x ]
  [ "$(preview_host feat-x preview.example.com)" = feat-x.preview.example.com ]
}

# --- F015: app, repo label, repo-scoped namespace ---
@test "preview_app: var wins, else repo name; sanitized, <= 20 chars" {
  [ "$(preview_app todo nimat-dev/ephemeral-environments)" = todo ]
  [ "$(preview_app '' nimat-dev/Shop_API.v2)" = shop-api-v2 ]
  [ "$(preview_app '' nimat-dev/ephemeral-environments)" = ephemeral-environmen ]
  [ "$(preview_app 'My App!!' o/r)" = my-app ]
  [ "$(preview_app 'aaaaaaaaaaaaaaaaaaa-b' o/r)" = aaaaaaaaaaaaaaaaaaa ]   # cut at 20 lands on '-', trimmed
  [ "$(preview_app '///' o/fallback)" = fallback ]                      # symbol-only var -> repo name
}

@test "preview_app: no usable app or repo -> error" {
  run preview_app '' ''; [ "$status" -eq 1 ]
  run preview_app '' 'owner/'; [ "$status" -eq 1 ]
  run preview_app '///' 'o/***'; [ "$status" -eq 1 ]
}

@test "preview_repo_label: owner/repo slug, <= 63, label-safe" {
  [ "$(preview_repo_label nimat-dev/ephemeral-environments)" = nimat-dev-ephemeral-environments ]
  [ "$(preview_repo_label Org.Name/Repo_X)" = org-name-repo-x ]
  l=$(preview_repo_label "$(printf 'o%.0s' {1..40})/$(printf 'r%.0s' {1..40})")
  [ "${#l}" -le 63 ]; [[ "$l" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || false
  run preview_repo_label ''; [ "$status" -eq 1 ]
  run preview_repo_label 'noslash'; [ "$status" -eq 1 ]
}

@test "preview_namespace: > 63 chars -> 54-char prefix + 8-hex hash, stable and distinct" {
  app=aaaaaaaaaaaaaaaaaaaa                                        # 20
  id1=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1                     # 40
  id2=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb2                     # same 54-char prefix
  n1=$(preview_namespace "$app" "$id1"); n2=$(preview_namespace "$app" "$id2")
  [ "${#n1}" -le 63 ]; [ "${#n2}" -le 63 ]
  [[ "$n1" =~ ^preview-[a-z0-9-]+-[0-9a-f]{8}$ ]] || false
  [ "$n1" != "$n2" ]
  [ "$n1" = "$(preview_namespace "$app" "$id1")" ]
  [ "$(preview_namespace todo "$id1")" = "preview-todo-$id1" ]    # 53 chars: no hash
}

@test "preview_namespace: hashed name never ends the prefix with '-'" {
  n=$(preview_namespace aaaaaaaaaaaaaaaaaaaa "$(printf 'b%.0s' {1..24})-cccccccccccccccc")
  [[ "$n" != *--* ]] || false
  [ "${#n}" -le 63 ]
}

@test "preview_owns: managed + same repo, or legacy without repo label" {
  own() { printf '{"metadata":{"name":"preview-x","labels":{%s}}}' "$1" | preview_owns o-r; }
  own '"managed-by":"preview-bot","preview.repo":"o-r"'
  own '"managed-by":"preview-bot"'
  ! own '"managed-by":"preview-bot","preview.repo":"other-repo"'
  ! own '"managed-by":"preview-bot","preview.repo":""'
  ! own '"preview.repo":"o-r"'
  ! own ''
  echo '{"metadata":{"name":"preview-x"}}' | { ! preview_owns o-r; }            # no labels object: not ours, no jq error
  [ -z "$(echo '{"items":[{"metadata":{"name":"preview-x"}}]}' | expired_namespaces 500 o-r)" ]
  run preview_owns '' </dev/null; [ "$status" -ne 0 ]
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
 {"metadata":{"name":"default","labels":{"managed-by":"preview-bot","preview.expires-at":"1"}}},
 {"metadata":{"name":"nolabels"}}
]}
JSON
}

@test "expired_namespaces: only own repo (+ legacy unlabeled); other repos never listed" {
  out=$(jq -n '{items:[
    {metadata:{name:"preview-a-x",labels:{"managed-by":"preview-bot","preview.repo":"o-r","preview.expires-at":"1"}}},
    {metadata:{name:"preview-b-x",labels:{"managed-by":"preview-bot","preview.repo":"o-other","preview.expires-at":"1"}}},
    {metadata:{name:"preview-legacy",labels:{"managed-by":"preview-bot","preview.expires-at":"1"}}}]}' | expired_namespaces 500 o-r)
  [ "$out" = "$(printf 'preview-a-x\npreview-legacy')" ]
}

@test "expired_namespaces: < now, missing/garbage label expired, foreign ns ignored" {
  run bash -c ". '$BATS_TEST_DIRNAME/../scripts/lib/preview.sh'; expired_namespaces 500 o-r" < <(ns_json)
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'preview-old\npreview-nolabel\npreview-garbage')" ]
}

@test "expired_namespaces: expires-at == now is not expired" {
  out=$(ns_json | expired_namespaces 500 o-r)
  [[ "$out" != *preview-edge* ]] || false
  out=$(ns_json | expired_namespaces 501 o-r)
  [[ "$out" == *preview-edge* ]] || false
}

@test "expired_namespaces: empty list -> no output" {
  [ -z "$(echo '{"items":[]}' | expired_namespaces 500 o-r)" ]
}

@test "expired_namespaces: malformed JSON and bad now fail" {
  run bash -c ". '$BATS_TEST_DIRNAME/../scripts/lib/preview.sh'; echo '{bad' | expired_namespaces 500 o-r"
  [ "$status" -ne 0 ]
  run expired_namespaces abc o-r; [ "$status" -eq 1 ]
  run expired_namespaces 500 '' </dev/null; [ "$status" -eq 1 ]
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
  out=$(preview_plan todo 'Feature/JIRA-1' 48h '' 30m 3 preview.example.com abc1234 1000)
  [ "$out" = "$(printf '%s\n' app=todo preview_id=feature-jira-1 namespace=preview-todo-feature-jira-1 \
    host=feature-jira-1.preview.example.com short_sha=abc1234 idle=1800 max_replicas=3 \
    lifetime=48h expires_at=173800)" ]
}

@test "preview_plan: custom lifetime and never idle" {
  out=$(preview_plan todo main custom 12h never 1 d.example abc1234 0)
  [[ "$out" == *"lifetime=12h"* ]] || false
  [[ "$out" == *"expires_at=43200"* ]] || false
  [[ "$out" == *"idle=31536000"* ]] || false
}

@test "preview_plan: every invalid input fails and prints nothing on stdout" {
  bad() { run bash -c ". '$BATS_TEST_DIRNAME/../scripts/lib/preview.sh'; preview_plan todo \"\$@\" 2>/dev/null" _ "$@"
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
  run bash -c ". '$BATS_TEST_DIRNAME/../scripts/lib/preview.sh'; preview_plan '' main 48h '' 30m 3 d.example abc1234 0 2>/dev/null"
  [ "$status" -eq 1 ] && [ -z "$output" ]                  # no app
}

# --- namespace_manifest ---
@test "namespace_manifest: label contract + raw branch escaped into annotation" {
  br='Feat/"quoted" $(x) `y`'
  m=$(namespace_manifest preview-todo-feat-quoted feat-quoted abc1234 1700000000 "$br" todo Nimat-Dev/Repo_X)
  [ "$(jq -r .kind <<<"$m")" = Namespace ]
  [ "$(jq -r .metadata.name <<<"$m")" = preview-todo-feat-quoted ]
  [ "$(jq -c .metadata.labels <<<"$m")" = '{"managed-by":"preview-bot","preview.branch":"feat-quoted","preview.commit":"abc1234","preview.expires-at":"1700000000","preview.app":"todo","preview.repo":"nimat-dev-repo-x"}' ]
  [ "$(jq -r '.metadata.annotations["preview.repo-original"]' <<<"$m")" = Nimat-Dev/Repo_X ]
  run namespace_manifest ns id abc1234 1 br todo ''; [ "$status" -ne 0 ]
  [ "$(jq -r '.metadata.annotations["preview.branch-original"]' <<<"$m")" = "$br" ]
}

# --- preview_commits / purge_tags (F011) ---
# now = 2026-09-30T00:00:00Z = 1790726400; day = 86400
tags_json() {
  cat <<'JSON'
[
 {"name":"aaaaaaa","lastUpdateTime":"2026-09-01T00:00:00.1234567Z","changeableAttributes":{"deleteEnabled":true}},
 {"name":"bbbbbbb","lastUpdateTime":"2026-09-02T00:00:00Z","changeableAttributes":{"deleteEnabled":true}},
 {"name":"ccccccc","lastUpdateTime":"2026-09-03T00:00:00Z","changeableAttributes":{"deleteEnabled":false}},
 {"name":"ddddddd","lastUpdateTime":"2026-09-04T00:00:00Z","changeableAttributes":{"deleteEnabled":true}},
 {"name":"latest","lastUpdateTime":"2026-09-01T00:00:00Z","changeableAttributes":{"deleteEnabled":true}},
 {"name":"eeeeeee","lastUpdateTime":"2026-09-28T00:00:00Z","changeableAttributes":{"deleteEnabled":true}},
 {"name":"fffffff","lastUpdateTime":"2026-09-29T00:00:00Z","changeableAttributes":{"deleteEnabled":true}}
]
JSON
}
purge() { bash -c ". '$BATS_TEST_DIRNAME/../scripts/lib/preview.sh'; purge_tags \"\$@\"" _ "$@" < <(tags_json); }

@test "purge_tags: old sha tags only; skips in-use, locked, non-sha, newest KEEP, recent" {
  run purge 1790726400 604800 1 bbbbbbb
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '%s\n' ddddddd aaaaaaa)" ]
}

@test "purge_tags: KEEP larger than the tag count -> nothing" {
  run purge 1790726400 0 99
  [ "$status" -eq 0 ]; [ -z "$output" ]
}

@test "purge_tags: KEEP 0, age 0 -> every deletable sha tag (none locked/non-sha)" {
  run purge 1790726400 0 0
  [ "$status" -eq 0 ]
  [ "$(sort <<<"$output" | tr '\n' ' ')" = "aaaaaaa bbbbbbb ddddddd eeeeeee fffffff " ]
}

@test "purge_tags: empty tag list -> nothing; malformed json -> non-zero" {
  run bash -c ". '$BATS_TEST_DIRNAME/../scripts/lib/preview.sh'; purge_tags 1 0 0 <<<'[]'"
  [ "$status" -eq 0 ]; [ -z "$output" ]
  run bash -c ". '$BATS_TEST_DIRNAME/../scripts/lib/preview.sh'; purge_tags 1 0 0 <<<'[{bad'"
  [ "$status" -ne 0 ]
}

@test "purge_tags: invalid now / age / keep -> non-zero" {
  run purge x 1 1; [ "$status" -ne 0 ]
  run purge 1 -5 1; [ "$status" -ne 0 ]
  run purge 1 1 ''; [ "$status" -ne 0 ]
}

@test "preview_commits: labels of preview-bot preview-* namespaces only" {
  run bash -c ". '$BATS_TEST_DIRNAME/../scripts/lib/preview.sh'; preview_commits" <<'JSON'
{"items":[
 {"metadata":{"name":"preview-a","labels":{"managed-by":"preview-bot","preview.commit":"aaaaaaa"}}},
 {"metadata":{"name":"preview-b","labels":{"managed-by":"preview-bot"}}},
 {"metadata":{"name":"default","labels":{"managed-by":"preview-bot","preview.commit":"bbbbbbb"}}},
 {"metadata":{"name":"preview-c","labels":{"preview.commit":"ccccccc"}}}
]}
JSON
  [ "$status" -eq 0 ]; [ "$output" = aaaaaaa ]
}

@test "purge_tags: digest shared with a protected tag (in-use / latest) is never deleted; shared victims once" {
  run bash -c ". '$BATS_TEST_DIRNAME/../scripts/lib/preview.sh'; purge_tags 1790726400 0 0 1111111" <<'JSON'
[
 {"name":"1111111","digest":"sha256:x","lastUpdateTime":"2026-09-01T00:00:00Z"},
 {"name":"2222222","digest":"sha256:x","lastUpdateTime":"2026-09-02T00:00:00Z"},
 {"name":"latest","digest":"sha256:y","lastUpdateTime":"2026-09-01T00:00:00Z"},
 {"name":"3333333","digest":"sha256:y","lastUpdateTime":"2026-09-03T00:00:00Z"},
 {"name":"4444444","digest":"sha256:z","lastUpdateTime":"2026-09-04T00:00:00Z"},
 {"name":"5555555","digest":"sha256:z","lastUpdateTime":"2026-09-05T00:00:00Z"},
 {"name":"6666666","digest":"sha256:w","lastUpdateTime":"2026-09-06T00:00:00Z"}
]
JSON
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '%s\n' 6666666 5555555)" ]   # x: in-use shares; y: latest shares; z: once
}

@test "purge_tags: digest shared with a KEEP-newest tag is protected" {
  run bash -c ". '$BATS_TEST_DIRNAME/../scripts/lib/preview.sh'; purge_tags 1790726400 0 1" <<'JSON'
[
 {"name":"aaaaaaa","digest":"sha256:x","lastUpdateTime":"2026-09-01T00:00:00Z"},
 {"name":"bbbbbbb","digest":"sha256:x","lastUpdateTime":"2026-09-29T00:00:00Z"},
 {"name":"ccccccc","digest":"sha256:c","lastUpdateTime":"2026-09-02T00:00:00Z"}
]
JSON
  [ "$status" -eq 0 ]; [ "$output" = ccccccc ]
}

@test "image_tags_in_use: deployment templates + pods in preview-* only, this image only" {
  run bash -c ". '$BATS_TEST_DIRNAME/../scripts/lib/preview.sh'; image_tags_in_use todo" <<'JSON'
{"items":[
 {"kind":"Deployment","metadata":{"namespace":"preview-a"},"spec":{"template":{"spec":{"containers":[{"image":"acr.io/todo:aaaaaaa"}]}}}},
 {"kind":"Pod","metadata":{"namespace":"preview-a"},"spec":{"containers":[{"image":"acr.io/todo:0ld0ld0"}]}},
 {"kind":"Pod","metadata":{"namespace":"preview-a"},"spec":{"initContainers":[{"image":"acr.io/todo:1111111"}],"containers":[{"image":"busybox:1.36"}]}},
 {"kind":"Pod","metadata":{"namespace":"kube-system"},"spec":{"containers":[{"image":"acr.io/todo:bbbbbbb"}]}},
 {"kind":"Pod","metadata":{"namespace":"preview-b"},"spec":{"containers":[{"image":"acr.io/nottodo:ccccccc"}]}},
 {"kind":"Pod","metadata":{"namespace":"preview-c"},"spec":{"containers":[{"image":"acr.io/todo:ddddddd@sha256:0123abcd"}]}},
 {"kind":"Pod","metadata":{"namespace":"preview-c"},"spec":{"containers":[{"image":"acr.io/todo@sha256:0123abcd"}]}}
]}
JSON
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '%s\n' 0ld0ld0 1111111 aaaaaaa ddddddd)" ]
}

@test "iso_epoch: fractional seconds dropped; garbage -> non-zero" {
  run iso_epoch 2026-09-30T00:00:00.9876543Z; [ "$status" -eq 0 ]; [ "$output" = 1790726400 ]
  run iso_epoch nope; [ "$status" -ne 0 ]
}

# --- F016: .preview.yaml (as JSON) -> normalized config; helm values ---
cfg() { printf '%s' "$1" | preview_config; }
cfg_fails() {  # cfg_fails JSON EXPECTED_MSG_SUBSTRING
  run bash -c ". '$BATS_TEST_DIRNAME/../scripts/lib/preview.sh'; printf '%s' \"\$1\" | preview_config" _ "$1"
  [ "$status" -ne 0 ] && [[ "$output" == *"$2"* ]] || { echo "want fail '$2' for $1, got $status: $output"; return 1; }
}

@test "preview_config: minimal component gets defaults" {
  out=$(cfg '{"components":[{"name":"web"}]}')
  [ "$out" = '{"components":[{"name":"web","context":".","dockerfile":"Dockerfile","port":8080,"probePath":"/","route":"/"}],"addons":[]}' ]
}

@test "preview_config: full two-component config kept; trailing '/' on route normalized; resources kept" {
  out=$(cfg '{"components":[{"name":"web","context":"todo","route":"/"},
    {"name":"api","context":"svc/api","dockerfile":"build/Dockerfile","port":3000,"probePath":"/api/health","route":"/api/",
     "resources":{"requests":{"cpu":"250m","memory":"256Mi"},"limits":{"cpu":1}}}],"addons":[]}')
  [ "$(jq -c '.components[1]' <<<"$out")" = '{"name":"api","context":"svc/api","dockerfile":"build/Dockerfile","port":3000,"probePath":"/api/health","route":"/api","resources":{"requests":{"cpu":"250m","memory":"256Mi"},"limits":{"cpu":1}}}' ]
  [ "$(jq -r '.components[0].context' <<<"$out")" = todo ]
}

@test "preview_config: shape errors" {
  cfg_fails 'null' 'must be a mapping'
  cfg_fails '[]' 'must be a mapping'
  cfg_fails '{}' 'components must be a non-empty list'
  cfg_fails '{"components":[]}' 'components must be a non-empty list'
  cfg_fails '{"components":{"name":"web"}}' 'components must be a non-empty list'
  cfg_fails '{"components":[{"name":"a"},{"name":"b"},{"name":"c"},{"name":"d"},{"name":"e"}]}' 'at most 4'
  cfg_fails '{"component":[{"name":"web"}]}' 'unknown key(s): component'
  cfg_fails '{"components":[{"name":"web","prot":80}]}' 'unknown key(s): prot'
  cfg_fails '{"components":["web"]}' 'must be a mapping'
}

@test "preview_config: field validation" {
  for n in '"Web"' '"1web"' '"web-"' '"a-very-long-name-x"' '""' '5' 'null'; do
    cfg_fails "{\"components\":[{\"name\":$n}]}" 'name' || return 1
  done
  cfg_fails '{"components":[{"name":"web"},{"name":"web","route":"/x"}]}' 'duplicate component name'
  cfg_fails '{"components":[{"name":"a"},{"name":"b"}]}' 'duplicate route'
  cfg_fails '{"components":[{"name":"a","route":"/x/"},{"name":"b","route":"/x"}]}' 'duplicate route'
  for p in 0 65536 '"80"' 8.5; do cfg_fails "{\"components\":[{\"name\":\"a\",\"port\":$p}]}" 'port' || return 1; done
  for c in '"/abs"' '"../up"' '"a/../../b"' '"a b"' '""'; do
    cfg_fails "{\"components\":[{\"name\":\"a\",\"context\":$c}]}" 'context' || return 1
    cfg_fails "{\"components\":[{\"name\":\"a\",\"dockerfile\":$c}]}" 'dockerfile' || return 1
  done
  for r in '"api"' '"/a b"' '"/$(x)"' '""'; do
    cfg_fails "{\"components\":[{\"name\":\"a\",\"route\":$r}]}" 'route' || return 1
    cfg_fails "{\"components\":[{\"name\":\"a\",\"probePath\":$r}]}" 'probePath' || return 1
  done
}

@test "preview_config: resources and addons validation" {
  cfg_fails '{"components":[{"name":"a","resources":{"requests":{"cpu":"lots"}}}]}' 'resources'
  cfg_fails '{"components":[{"name":"a","resources":{"requests":{"gpu":"1"}}}]}' 'resources'
  cfg_fails '{"components":[{"name":"a","resources":{"burst":{}}}]}' 'resources'
  cfg_fails '{"components":[{"name":"a","resources":"big"}]}' 'resources'
  cfg_fails '{"components":[{"name":"a"}],"addons":["postgres"]}' 'unsupported addon(s): postgres'
  cfg_fails '{"components":[{"name":"a"}],"addons":"postgres"}' 'addons must be a list'
  cfg '{"components":[{"name":"a","resources":{"limits":{"memory":"1Gi","cpu":"0.5"}}}]}' >/dev/null
}

@test "preview_values: config -> helm components with per-component image; bad args fail" {
  out=$(cfg '{"components":[{"name":"web"},{"name":"api","route":"/api","port":3000}]}' | preview_values acr.io/todo abc1234)
  [ "$(jq -c '.components[1]' <<<"$out")" = '{"name":"api","image":{"repository":"acr.io/todo/api","tag":"abc1234"},"port":3000,"probePath":"/","route":"/api"}' ]
  [ "$(jq -r '.components[0].image.repository' <<<"$out")" = acr.io/todo/web ]
  run preview_values '' abc1234 </dev/null; [ "$status" -ne 0 ]
  run preview_values acr.io/todo '' </dev/null; [ "$status" -ne 0 ]
}

@test "preview_default_config is a valid config" {
  [ "$(printf '%s' "$PREVIEW_DEFAULT_CONFIG" | preview_config | jq -c '[.components[].name, .components[].context]')" = '["web","."]' ]
}

@test "preview_verify_paths: probe under own route, else route" {
  out=$(cfg '{"components":[{"name":"web"},{"name":"api","route":"/api","probePath":"/api/health"},
    {"name":"adm","route":"/admin","probePath":"/healthz"},{"name":"x","route":"/api2","probePath":"/api2"}]}' | preview_verify_paths)
  [ "$out" = '/ /api/health /admin /api2' ]
  [ "$(cfg '{"components":[{"name":"a","route":"/ap","probePath":"/apx"}]}' | preview_verify_paths)" = /ap ]
}
