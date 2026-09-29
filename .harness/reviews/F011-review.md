# PR review — #15 feat/F011 (ACR purge), 2026-09-29

Round 1 (`/code-review medium 15`):

| # | Where | Finding | Outcome |
|---|---|---|---|
| 1 | preview-ci.sh purge (high) | `az acr repository delete --image` deletes the manifest + every tag on it; buildx cache can give two commits one digest → purging stale Y deletes live X's image | fixed: `purge_tags` skips a candidate whose digest any protected tag (in-use, keep-newest, locked, non-sha, recent) shares; one delete per digest; bats `digest shared with a protected tag…`, `…KEEP-newest tag…` |
| 2 | lib in-use (medium) | in-use only from ns `preview.commit` label, relabeled before a non-atomic helm upgrade → failed upgrade leaves old RS running an unprotected tag | fixed: in-use = labels ∪ images of Deployment templates + pods in `preview-*` (`image_tags_in_use`); unreadable/malformed workload list → delete nothing; bats `image still run by a pod…`, `image_tags_in_use:` |
| — | (self-found while fixing) | malformed workload JSON swallowed inside nested `$(…)` → empty in-use | fixed: separate step, fails closed (bats) |
| — | (low, not raised) | identical re-push may not bump `lastUpdateTime` | covered by keep-newest 3 + digest protection |

Round 2 (`/code-review medium 15` on 47f5c81):

| # | Where | Finding | Outcome |
|---|---|---|---|
| 1 | purge vs deploy race (medium) | separate concurrency groups; a redeploy of a stale tag could be deleted between purge listing and delete | fixed: deploy always re-pushes (`push: true`), and ACR refreshes `lastUpdateTime` on re-push (live: `425ccb8` created 04:33, updated 12:31 = its redeploy); purge re-reads each tag right before delete and skips if refreshed; re-read failure → skip + run fails; bats ×2 |
| 2 | image ref parse (low) | `repo:tag@sha256:…` yielded the digest hex | fixed: strip `@sha256:` first; bats case added |

Live dry-run after fixes (`evidence/F011/local-dry-run.txt`): unchanged selection (real digests unique). `./scripts/init.sh` BASELINE GREEN 185/185 after round 2; real `az acr repository show --query lastUpdateTime` + `iso_epoch` checked.

Round 3 (`/code-review medium 15` on c4ccf35): no findings. Clean. (Noted, not raised: identical-digest race is unlikely — buildx provenance makes each build digest unique.)
