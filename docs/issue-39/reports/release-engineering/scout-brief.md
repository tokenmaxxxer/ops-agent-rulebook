---
name: issue-39-scout-skip-record
subject: issue-39
role: release-engineering
status: skip-record
---

# Scout skip record — issue #39

Scouting skipped. Condition: "the spec literally leaves no design
decision open." Every residual defect in the issue is a conformance gap
against an already-landed, fully-prescriptive upstream canon (core #75's
guarded source line, `gate-lib.py` parity, and the 7-case mandatory test
list; core's `compliance-check.sh` detection rules) — see
`docs/issue-39/reports/release-engineering/survey.md`. The fix shape for
each item is dictated by that canon (exact source line, exact function
names, exact test-case list, exact compliance-detector rule), not a field
this role is choosing an approach for. The one item with any real
discretion — the `ops` → `release-engineering` rename's exact edit
list — is a mechanical text-consistency fix against this repo's own
established convention (repo name, commit-message role tag, board-gate's
enforced branch name), not a product-shaped direction call a field sweep
would inform.
