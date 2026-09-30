# DATA MODEL

No database. The "model" is the **preview identity** and the **namespace label contract**
that deploy, destroy, and reap agree on. Defined in `scripts/lib/preview.sh` (pure core).

## Preview
| Field | Derivation | Example |
|---|---|---|
| `branch` | dispatch input (raw) | `Feature/JIRA-123_login` |
| `preview_id` | lowercase; non-`[a-z0-9]` runs → `-`; trim `-`; cut 40; trim trailing `-` | `feature-jira-123-login` |
| `app` | repo var `PREVIEW_APP` (else repo name), same slug rules, cut 20 (F015) | `todo` |
| `repo` | `preview.repo` label: slug of `owner/repo`, cut 63 (F015) | `nimat-dev-ephemeral-environments` |
| `namespace` | `preview-<app>-<preview_id>`; > 63 → first 54 chars + `-` + 8-hex cksum (F015) | `preview-todo-feature-jira-123-login` |
| `host` | `<preview_id>.<PREVIEW_DOMAIN>` | `feature-jira-123-login.preview.nimat.dev` |
| `short_sha` | `git rev-parse --short HEAD` of branch | `a1b2c3d` |
| `image` | `<ACR_LOGIN_SERVER>/<APP_IMAGE_NAME>:<short_sha>` | |
| `idle_seconds` | `15m/30m/1h/6h` → seconds; `never` → 31536000 | `1800` |
| `expires_at` | now (UTC epoch) + lifetime seconds (`24h/48h/7d/custom Nh|Nd|Nm`) | `1759190400` |

## Namespace label contract (read by the reaper)
```
labels:
  managed-by: preview-bot
  preview.branch: <preview_id>
  preview.commit: <short_sha>
  preview.expires-at: "<epoch seconds>"
  preview.app: <app>                 # F015
  preview.repo: <repo slug>          # F015 — ownership
annotations:
  preview.branch-original: "<raw branch>"
  preview.repo-original: "<owner/repo>"
```

## Invariants (enforced in the pure core, tested)
1. `preview_id` is a valid RFC 1123 label, non-empty, ≤ 40 chars; empty → hard fail.
2. Same branch → same `preview_id` in deploy and destroy (single implementation).
3. `lifetime=custom` with empty `lifetime_custom` → hard fail.
4. `expires_at` is an integer epoch > now.
5. Reaper deletes only `preview-*` namespaces with `managed-by=preview-bot` AND `expires-at < now`;
   missing label → treated as `0` (expired) — per spec. It reaps only namespaces it owns (7).
7. Ownership (F015): `managed-by=preview-bot` AND (`preview.repo` == own repo OR no `preview.repo` = legacy
   pre-F015). Namespace apply, destroy and reap act only on owned namespaces; another repo's is refused.
6. One preview per branch (redeploy rolls the same Deployment).

## Id prefixes
- Features `F001…`, decisions `DEC-001…`, ADRs `ADR-0001…`, blockers `BLK-001…`.
- Runtime: namespaces `preview-<app>-<preview_id>` (legacy pre-F015: `preview-<preview_id>`); Helm release = `preview_id`.
