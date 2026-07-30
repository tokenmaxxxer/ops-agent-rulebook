---
kind: survey
issue: 24
---

# Current-state survey — issue 24

Scope per issue: raise the `ops` role directive's RECORD REQUIREMENTS block
to the strong form already used by feasibility/verify/reflect/ux-design —
add the enforcement clause and its measured-evidence citation, without
changing any existing record-format field.

## Scout skip record

Skipped scouting: the spec leaves no design decision open (skip condition 2
of scout-directive). The issue names the exact two clauses to add verbatim
("Ending phase 2 without your record committed on the branch means the
record was never written." and "(Measured: a phase-1-only issue left the
record empty.)") and names the reference file
(`ux-design-rulebook/ux-design/hooks/directive.sh`, post issue-12 state).
This is a wording-strength alignment, not a build with an open field to
survey.

## Write set

Only one file in this repo carries a RECORD REQUIREMENTS block: this repo
ships only the `ops` role's hooks (confirmed by issue-21's prior survey —
no separate `coding` directive file exists in this git tree).

- `ops/hooks/directive.sh` (lines 50–54) — current text:

  ```
  RECORD REQUIREMENTS (do not skip this): your record lives at
  docs/issue-<n>/reports/ops.md — research files, surveys, and proposals
  do not satisfy this. Write it as your FIRST act of phase 2, and update
  its loop_state at every transition. It must be committed on the branch
  before phase 2 ends.
  ```

  This already states the record path, the phase-2-first-act rule, and the
  loop_state-per-transition rule (kept unchanged per the issue). It lacks
  the strong-form enforcement clause ("...means the record was never
  written.") and its measured-evidence citation that the issue asks to add,
  in contrast with the `ux-design-rulebook` reference wording cited in the
  issue.

## Reference file access

`ux-design-rulebook` is a separate repository not present in this git tree
or working directory; its exact current wording could not be fetched in
this session. The issue itself supplies the two clauses verbatim, so the
proposal uses that quoted wording directly rather than the unreachable
reference file.

## What stays

All four existing record-format fields (record path
`docs/issue-<n>/reports/ops.md`, "research files, surveys, and proposals do
not satisfy this," "write it as your FIRST act of phase 2," "update its
loop_state at every transition") are kept verbatim — only the closing
sentence is strengthened and cited.
