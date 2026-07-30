---
kind: report
issue: 24
role: coding
loop_state: landed
---

# Coding record — issue 24

## code_under_review
`ops/hooks/directive.sh` RECORD REQUIREMENTS block (lines 50-54).

## What was done
Replaced the closing sentence "It must be committed on the branch before
phase 2 ends." with the strong-form enforcement clause "Ending phase 2
without your record committed on the branch means the record was never
written." plus its measured-evidence citation "(Measured: a phase-1-only
issue left the record empty.)" — matching the wording already used in
feasibility/verify/reflect/ux-design's RECORD FORMAT blocks. All other
lines in the block (record path, "do not satisfy this," "FIRST act of
phase 2," "loop_state at every transition") were left unchanged.

## why
Issue #24, approved via `APPROVE issue-24/coding` on the issue thread
(role-handoff contract v3 single-account-mode approval), per the
phase-1 proposal at docs/issue-24/proposals/proposal.md.

## closed_checks
- proposal-match (code_sha: current HEAD after edit): grep for the new
  enforcement sentence and its citation both present; all four
  proposal-specified unchanged strings ("reports/ops.md", "do not
  satisfy this", "FIRST act of phase 2", "loop_state at every
  transition") still present in the block. Verified via direct grep of
  `ops/hooks/directive.sh`, output matched expectation exactly.

## What did not work
(none — single targeted edit, applied and verified in one pass)

## open_findings
(none)
