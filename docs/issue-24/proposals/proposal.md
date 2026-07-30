---
kind: proposal
issue: 24
---

# Proposal — issue 24

files: `ops/hooks/directive.sh`

## Request (paraphrased intent, secrets stripped)

The `ops` role directive's RECORD REQUIREMENTS block lacks the strong-form
enforcement clause already present in feasibility/verify/reflect/ux-design's
equivalent blocks. Add the enforcement sentence and its measured-evidence
citation, referencing the `ux-design-rulebook` wording style (post issue-12
state), without changing any existing record-format field.

## Constraints

- Keep every existing record-format obligation unchanged: record path
  (`docs/issue-<n>/reports/ops.md`), "research files, surveys, and proposals
  do not satisfy this," write-as-first-act-of-phase-2, and
  loop_state-update-per-transition.
- Add the enforcement clause: "Ending phase 2 without your record committed
  on the branch means the record was never written."
- Add its measured-evidence citation: "(Measured: a phase-1-only issue left
  the record empty.)"
- This is a wording-strength alignment only — no format change, no new
  record field.
- Phase 1 only — this proposal is the full scope; no approval self-granted.

## What will be done

In `ops/hooks/directive.sh`'s RECORD REQUIREMENTS block (current lines
50–54), replace the closing sentence "It must be committed on the branch
before phase 2 ends." with the strong-form enforcement sentence and its
measured-evidence citation, keeping the rest of the block's wording as-is:

```
RECORD REQUIREMENTS (do not skip this): your record lives at
docs/issue-<n>/reports/ops.md — research files, surveys, and proposals
do not satisfy this. Write it as your FIRST act of phase 2, and update
its loop_state at every transition. Ending phase 2 without your record
committed on the branch means the record was never written. (Measured:
a phase-1-only issue left the record empty.)
```

## Out of scope

- Any change to the other role-specific fields of the `ops` directive
  (RESEARCH, CURRENT-STATE SURVEY, PROPOSAL, EXECUTION JUDGMENT sections).
- The `ux-design-rulebook` repository itself (not present in this git tree).
- Any other rulebook repo's `coding`/other-role directive (not present in
  this git tree — confirmed by issue-21's prior survey).
- Approving this proposal or starting phase 2 — that requires a human
  Approve per the role-handoff contract.

## How you'll know it worked

`grep -n "means the record was never written\|Measured: a phase-1-only issue left the record empty" ops/hooks/directive.sh`
returns both lines, while `docs/issue-<n>/reports/ops.md`, "do not satisfy
this," "FIRST act of phase 2," and "loop_state at every transition" remain
present unchanged in the same block.
