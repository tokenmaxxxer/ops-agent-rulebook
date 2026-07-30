---
kind: proposal
issue: 21
---

# Proposal — issue 21

files: `ops/hooks/directive.sh`

## Request (paraphrased intent, secrets stripped)

The `ops` role directive's record-obligation block currently leaks
routing-device framing (wake, "the board," "machine wake-up," a pointer to
`docs/specs/wake-routing.md`) into the role rulebook. That framing is
on-the-record's canon, not something a subject role needs to know. Restate
the same obligations purely as record-format requirements.

## Constraints

- Keep every existing record-format obligation: path
  (`docs/issue-<n>/reports/ops.md`), write it as phase 2's first act, update
  `loop_state` at every transition, commit on branch.
- Remove: "wake," "waking," "woken," "the board" (as a routing device),
  "WAKES-ON," "downstream role(s)," and the pointer to
  `docs/specs/wake-routing.md`.
- No mention of who reads the record or what happens next as a result of it
  existing.
- Leave historical docs (`docs/issue-19/`, `docs/proposals/`,
  `docs/reports/`) untouched.
- Phase 1 only — this proposal is the full scope; no approval self-granted.

## What will be done

Replace the "YOUR RECORD IS THE BOARD" heading and body in
`ops/hooks/directive.sh` (lines 50–58) with a heading and body that state
only: where the record lives, when to write it (first act of phase 2), what
to update on every transition (`loop_state`), and that it must be committed
on the branch before phase 2 ends. No routing rationale, no mention of a
reader or a wake mechanism.

## Out of scope

- `docs/specs/wake-routing.md` itself (does not exist in this repo; it is
  on-the-record's canon in a different repo).
- Any other rulebook repo's `coding` directive (not present in this git
  tree).
- Historical/dated docs under `docs/issue-19/`, `docs/proposals/`,
  `docs/reports/`.
- Approving this proposal or starting phase 2 — that requires a human
  Approve per the role-handoff contract.

## How you'll know it worked

`grep -rniE 'WAKES-ON|wake-routing|board-as-routing|downstream role|\bwake|\bwoken|the board' ops/hooks/directive.sh`
returns no matches, while the file still specifies the record path, the
write-first-in-phase-2 rule, the loop_state-update-per-transition rule, and
the commit-on-branch rule.
