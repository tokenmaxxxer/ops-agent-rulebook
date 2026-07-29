# Proposal — issue-19

files: `ops/hooks/directive.sh`

## Request (paraphrased intent)

Wake-routing ownership moved to the on-the-record repo
(`docs/specs/wake-routing.md`). This rulebook (ops role directive) must
stop stating which role a state/record summons — it may only describe
its own record's states/format.

## Constraints

- Keep: where the record lives (`docs/issue-<n>/reports/ops.md`), that
  it's written first in phase 2, updated at loop_state transitions, and
  the consequence of skipping it (board never sees the work).
- Remove: any language naming which role wakes / is summoned
  ("WAKES-ON", "downstream role ... woken").
- Repoint the removed routing claim to on-the-record
  `docs/specs/wake-routing.md` rather than deleting the concept outright.

## What will be done

Edit the "YOUR RECORD IS THE BOARD" paragraph in `ops/hooks/directive.sh`
(lines 50–57) to drop WAKES-ON/downstream-wake phrasing while preserving
the record-state guidance, and add a pointer to
`docs/specs/wake-routing.md` for routing questions.

## Out of scope

- `docs/proposals/2026-07-26-contract-v2-conformance.md` (historical
  proposal, not live rule text).
- Any change to `docs/specs/wake-routing.md` itself (owned by on-the-record).

## How it'll be verified

`grep -n -iE "wakes|wake" ops/hooks/directive.sh` after the edit shows
no "WAKES-ON" / "downstream role ... woken" phrasing, and the record's
own-state guidance (location, first-write-in-phase-2, loop_state update)
is still present.
