---
kind: report
issue: 21
loop_state: landed
---

# Coding record — issue 21

## What was done

Implemented the approved proposal (docs/issue-21/proposals/proposal.md,
merged via PR #22): replaced the "YOUR RECORD IS THE BOARD" block in
`ops/hooks/directive.sh` (lines 50-58) with a "RECORD REQUIREMENTS"
block stating only the record path, the phase-2-first-act rule, the
loop_state-per-transition rule, and the commit-on-branch rule. Removed
all routing-device vocabulary (wake, woken, the board, WAKES-ON,
machine wake-up, pointer to docs/specs/wake-routing.md).

## Why

Rationale: issue #21 flagged that rulebook text leaked routing-side
vocabulary and mechanism knowledge that belongs to on-the-record's canon
(docs/specs/wake-routing.md, a different repo), not to a subject role's
rulebook. Restating the same obligations as pure record-format
requirements removes that leak without dropping any actual obligation.

## Upstream basis

docs/issue-21/proposals/proposal.md (phase-1 proposal, approved and
merged via PR #22) and docs/issue-21/reports/coding/survey.md
(current-state survey identifying `ops/hooks/directive.sh` lines 50-58
as the only in-repo file carrying the flagged vocabulary).

## loop_state

landed — phase 2 complete, single-file mechanical edit matches proposal
scope exactly, verification check passed.

## closed_checks

- check: `grep -rniE 'WAKES-ON|wake-routing|board-as-routing|downstream role|\bwake|\bwoken|the board' ops/hooks/directive.sh` returns no matches
  code_sha: pending commit (this change)
  result: pass — no matches, while record path/phase-2-first-act/loop_state-per-transition/commit-on-branch rules remain stated

## What did not work

(none — mechanical single-file edit, matched proposal scope exactly)

## Warrant hunt

Skipped: single-file text substitution with no logic, no new code
paths, no external interface change — nothing for a hunter to probe
beyond the grep check already closed above.

## Open findings

None.
