## Summary
- a5: also federate repo's immutable OIDC subject (`repo:<owner>@<id>/<repo>@<id>:environment:preview`) when GitHub issues one — fixes AADSTS700213 (DEC-030). Bats test + fake `gh` added.
- Harness: F007 COMPLETE via real dispatch (run 36568750009: ns deleted, URL 200→404); first scheduled reap proven (36558226159). Phase 02 COMPLETE, F009 next.

## Verification
- `./scripts/init.sh` → BASELINE GREEN
- evidence: `.harness/evidence/F006/a5-immutable-subject.txt`, `.harness/evidence/F007/dispatch-destroy-e2e.txt`, `.harness/evidence/F007/scheduled-reap.txt`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
