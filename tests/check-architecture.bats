#!/usr/bin/env bats
# F001: scripts/check-architecture.sh against generated fixture trees.

CHECK="$BATS_TEST_DIRNAME/../scripts/check-architecture.sh"

setup() { R="$(mktemp -d)"; }
teardown() { rm -rf "$R"; }

# --- compliant fixture builders ---
lib_ok() {
  mkdir -p "$R/scripts/lib"
  cat >"$R/scripts/lib/preview.sh" <<'SH'
# pure: never call kubectl or helm here
preview_id() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
helmfile_name="x"   # near-miss identifier
SH
}
wf_ok() {
  mkdir -p "$R/.github/workflows"
  cat >"$R/.github/workflows/preview-deploy.yml" <<'YML'
name: Deploy Preview
on:
  workflow_dispatch: {}
permissions:
  id-token: write
  contents: read
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: azure/login@v3.1.0
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
      - run: |
          . scripts/lib/preview.sh
          echo "${{ vars.PREVIEW_DOMAIN }} ${{ secrets.GITHUB_TOKEN }}"
YML
}
chart_ok() {
  mkdir -p "$R/deploy/preview/templates"
  cat >"$R/deploy/preview/templates/deployment.yaml" <<'YML'
apiVersion: apps/v1
kind: Deployment
spec:
  # No replicas field: KEDA owns the replica count.
  selector: {}
YML
  cat >"$R/deploy/preview/templates/ingress.yaml" <<'YML'
kind: Ingress
spec:
  tls:
    - hosts: ["x"]
      # secretName omitted on purpose: nginx serves its default wildcard cert.
YML
}
all_ok() { lib_ok; wf_ok; chart_ok; }

run_check() { run "$CHECK" --root "$R"; }

# --- happy paths / empty ---
@test "empty tree is clean" {
  run_check
  [ "$status" -eq 0 ]
  [[ "$output" == *clean* ]] || false
}

@test "compliant tree is clean (comments and near-misses ignored)" {
  all_ok
  run_check
  [ "$status" -eq 0 ]
}

# --- one violation per rule ---
@test "rule 1: adapter call in scripts/lib" {
  all_ok; echo 'ns() { kubectl get ns; }' >>"$R/scripts/lib/preview.sh"
  run_check; [ "$status" -eq 1 ]; [[ "$output" == *"rule 1"* ]] || false
}

@test "rule 1: adapter call inside command substitution" {
  all_ok; echo 'x=$(curl -s http://a)' >>"$R/scripts/lib/preview.sh"
  run_check; [ "$status" -eq 1 ]; [[ "$output" == *"rule 1"* ]] || false
}

@test "rule 2: inline sanitizer in workflow" {
  all_ok
  echo "      - run: echo x | sed -E 's#[^a-z0-9]+#-#g'" >>"$R/.github/workflows/preview-deploy.yml"
  run_check; [ "$status" -eq 1 ]; [[ "$output" == *"rule 2"* ]] || false
}

@test "rule 3: client-secret in workflow" {
  all_ok; sed -i.bak 's/client-id:/client-secret:/' "$R/.github/workflows/preview-deploy.yml"
  run_check; [ "$status" -eq 1 ]; [[ "$output" == *"rule 3"* ]] || false
}

@test "rule 3: non-GITHUB_TOKEN secret in workflow" {
  all_ok; echo '      - run: echo ${{ secrets.AZURE_PASSWORD }}' >>"$R/.github/workflows/preview-deploy.yml"
  run_check; [ "$status" -eq 1 ]; [[ "$output" == *"rule 3"* ]] || false
}

@test "rule 3: secret whose name starts with GITHUB_TOKEN" {
  all_ok; echo '      - run: echo ${{ secrets.GITHUB_TOKEN_ADMIN }}' >>"$R/.github/workflows/preview-deploy.yml"
  run_check; [ "$status" -eq 1 ]; [[ "$output" == *"rule 3"* ]] || false
}

@test "rule 3: bracket-notation secret" {
  all_ok; echo "      - run: echo \${{ secrets['AZURE_PASSWORD'] }}" >>"$R/.github/workflows/preview-deploy.yml"
  run_check; [ "$status" -eq 1 ]; [[ "$output" == *"rule 3"* ]] || false
}

@test "rule 3: GITHUB_TOKEN next to another expression stays clean" {
  all_ok; echo '      - run: echo ${{ secrets.GITHUB_TOKEN }}-${{ github.sha }}' >>"$R/.github/workflows/preview-deploy.yml"
  run_check; [ "$status" -eq 0 ]
}

@test "rule 4: Namespace in chart" {
  all_ok; printf 'apiVersion: v1\nkind: Namespace\n' >"$R/deploy/preview/templates/ns.yaml"
  run_check; [ "$status" -eq 1 ]; [[ "$output" == *"rule 4"* ]] || false
}

@test "rule 5: replicas in Deployment" {
  all_ok; echo '  replicas: 1' >>"$R/deploy/preview/templates/deployment.yaml"
  run_check; [ "$status" -eq 1 ]; [[ "$output" == *"rule 5"* ]] || false
}

@test "rule 6: hard-coded domain in workflow (pattern from .harness/rules/architecture.conf)" {
  all_ok; mkdir -p "$R/.harness/rules"; cp "$BATS_TEST_DIRNAME/../.harness/rules/architecture.conf" "$R/.harness/rules/"
  echo '      - run: curl https://x.preview.alleghenycounty.us' >>"$R/.github/workflows/preview-deploy.yml"
  run_check; [ "$status" -eq 1 ]; [[ "$output" == *"rule 6"* ]] || false
}

@test "rule 6: another project's domain comes from its own config; generic default still catches ACR/cluster DNS (config extends, never replaces)" {
  all_ok; echo '      - run: curl https://x.shop.example.org' >>"$R/.github/workflows/preview-deploy.yml"
  run_check; [ "$status" -eq 0 ]
  mkdir -p "$R/.harness/rules"; printf "HARDCODED_ENV_RE='shop\\.example\\.org'\n" >"$R/.harness/rules/architecture.conf"
  run_check; [ "$status" -eq 1 ]; [[ "$output" == *"rule 6"* ]] || false
  # the project pattern extends the generic one: ACR still caught while the config is present
  sed -i.bak '/shop\.example\.org/d' "$R/.github/workflows/preview-deploy.yml"; run_check; [ "$status" -eq 0 ]
  echo '      - run: echo acr1.azurecr.io' >>"$R/.github/workflows/preview-deploy.yml"
  run_check; [ "$status" -eq 1 ]; [[ "$output" == *"rule 6"* ]] || false
  rm "$R/.harness/rules/architecture.conf"; run_check; [ "$status" -eq 1 ]
}

@test "rule 7: missing top-level permissions" {
  all_ok; sed -i.bak '/^permissions:/,/contents: read/d' "$R/.github/workflows/preview-deploy.yml"
  run_check; [ "$status" -eq 1 ]; [[ "$output" == *"rule 7"* ]] || false
}

@test "rule 7: extra permission" {
  all_ok
  printf 'permissions:\n  id-token: write\n  contents: read\n  packages: write\njobs: {}\n' >"$R/.github/workflows/extra.yml"
  run_check; [ "$status" -eq 1 ]; [[ "$output" == *"extra.yml"*"rule 7"* ]] || false
}

@test "rule 7: job-level permissions override" {
  all_ok; printf 'permissions:\n  id-token: write\n  contents: read\njobs:\n  a:\n    permissions:\n      contents: write\n' >"$R/.github/workflows/job.yml"
  run_check; [ "$status" -eq 1 ]; [[ "$output" == *"job-level"* ]] || false
}

@test "rule 8: workflow references bootstrap/" {
  all_ok; echo '      - run: ./bootstrap/a1.sh' >>"$R/.github/workflows/preview-deploy.yml"
  run_check; [ "$status" -eq 1 ]; [[ "$output" == *"rule 8"* ]] || false
}

@test "rule 9: secretName in Ingress" {
  all_ok; echo '      secretName: my-tls' >>"$R/deploy/preview/templates/ingress.yaml"
  run_check; [ "$status" -eq 1 ]; [[ "$output" == *"rule 9"* ]] || false
}

# --- multiple / args ---
@test "multiple violations are all reported" {
  all_ok
  echo 'ns() { kubectl get ns; }' >>"$R/scripts/lib/preview.sh"
  echo '  replicas: 1' >>"$R/deploy/preview/templates/deployment.yaml"
  run_check; [ "$status" -eq 1 ]
  [[ "$output" == *"rule 1"* ]] || false; [[ "$output" == *"rule 5"* ]] || false
}

@test "--root on missing dir exits 2" {
  run "$CHECK" --root "$R/nope"
  [ "$status" -eq 2 ]; [[ "$output" == *"not a directory"* ]] || false
}

@test "unknown argument exits 2" {
  run "$CHECK" --bogus
  [ "$status" -eq 2 ]
}
