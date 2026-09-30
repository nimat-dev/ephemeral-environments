#!/usr/bin/env bats
# F014: every workflow action is pinned to a full release tag (vX.Y[.Z]) — not a
# floating major (`@v4`, runs stale Node 20 majors silently) and not a commit SHA.

ROOT="$BATS_TEST_DIRNAME/.."
FULL_TAG='^[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@v[0-9]+\.[0-9]+(\.[0-9]+)?$'

# Local refs (./kit composite, ./.github/workflows/kit-*.yml reusable workflows, F021) are this repo at the same commit.
refs() {
  grep -hE '^[[:space:]]*(-[[:space:]]+)?uses:' "$ROOT"/.github/workflows/*.yml "$ROOT"/examples/consumer/.github/workflows/*.yml |
    sed -E 's/^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*//; s/[[:space:]]*(#.*)?$//' | grep -v '^\./'
}

@test "workflows reference at least one action" {
  [ "$(refs | wc -l)" -gt 0 ]
}

@test "every action ref is a full release tag" {
  bad="$(refs | grep -vE "$FULL_TAG" || true)"
  [ -z "$bad" ] || { echo "not a full tag: $bad"; false; }
}

@test "no floating major-only tag" {
  bad="$(refs | grep -E '@v[0-9]+$' || true)"
  [ -z "$bad" ] || { echo "major-only: $bad"; false; }
}

@test "no commit-SHA pin" {
  bad="$(refs | grep -E '@[0-9a-f]{40}$' || true)"
  [ -z "$bad" ] || { echo "sha pin: $bad"; false; }
}
