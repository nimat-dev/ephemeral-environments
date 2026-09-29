# PR review — #15 feat/F011 (ACR purge), 2026-09-29

Round 1 (`/code-review medium 15`):

| # | Where | Finding | Outcome |
|---|---|---|---|
| 1 | preview-ci.sh purge (high) | `az acr repository delete --image` deletes the manifest + every tag on it; buildx cache can give two commits one digest → purging stale Y deletes live X's image | fixed: `purge_tags` skips a candidate whose digest any protected tag (in-use, keep-newest, locked, non-sha, recent) shares; one delete per digest; bats `digest shared with a protected tag…`, `…KEEP-newest tag…` |
| 2 | lib in-use (medium) | in-use only from ns `preview.commit` label, relabeled before a non-atomic helm upgrade → failed upgrade leaves old RS running an unprotected tag | fixed: in-use = labels ∪ images of Deployment templates + pods in `preview-*` (`image_tags_in_use`); unreadable/malformed workload list → delete nothing; bats `image still run by a pod…`, `image_tags_in_use:` |
| — | (self-found while fixing) | malformed workload JSON swallowed inside nested `$(…)` → empty in-use | fixed: separate step, fails closed (bats) |
| — | (low, not raised) | identical re-push may not bump `lastUpdateTime` | covered by keep-newest 3 + digest protection |

Live dry-run after fixes (`evidence/F011/local-dry-run.txt`): unchanged selection (real digests unique). `./scripts/init.sh` BASELINE GREEN 182/182.
