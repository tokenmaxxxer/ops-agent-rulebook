# coding record — issue-19

loop_state: landed

## Upstream basis

docs/issue-19/proposals/proposal.md, approved via `APPROVE issue-19/coding`
comment by JiwonJung94 (listed in docs/specs/approvers.md, single-account
mode per contract v3 s19), issue #19, PR #20, comment id
IC_kwDOTjGUTM8AAAABMWqMcQ, 2026-07-29T22:31:00Z.

## Why

Wake-routing ownership moved to on-the-record (`docs/specs/wake-routing.md`,
operator decision 2026-07-30; core contract s3 table removed via
tokenmaxxxer-core#36). Issue #19 requires this rulebook to state nothing
about which role a state/record summons.

## What was done

Executed the proposal exactly:
- Edited the "YOUR RECORD IS THE BOARD" paragraph in
  `ops/hooks/directive.sh` (previously lines 50-57): removed "WAKES-ON"
  and "no downstream role can ever be woken by it" (routing language),
  kept the record's own state/format guidance (location, write-first-in-
  phase-2, loop_state updates, consequence of an unwritten record), and
  added a repoint to on-the-record `docs/specs/wake-routing.md` for
  routing questions.
- No other file touched (survey found no other live rulebook file with
  wake/WAKES-ON mentions; historical proposal doc correctly out of scope).

## Verification run

`grep -n -iE "wakes|wake" ops/hooks/directive.sh` after the edit: no
"WAKES-ON" / "downstream role ... woken" phrasing remains (only
"wake-up" in the unrelated consequence clause and the
"wake-routing.md" filename repoint). Record-state guidance
(location/first-write/loop_state) intact — matches proposal's stated
verification method.

## What did not work

(none — single scoped edit, applied as proposed on first attempt)

## Hunt cadence

Scouting/hunt not applicable: issue #19 is a scoped textual strip with
no design decision open (per survey's skip record) and no code path to
probe — warrant-hunter dispatch skipped, no runnable behavior changed.

## closed_checks

- check: grep verification of routing-language removal
  code_sha: ops/hooks/directive.sh (this commit)
  result: pass — no WAKES-ON / downstream-wake phrasing found

## Open findings

None outstanding. No blocking finding addressed to coding is open for
issue-19.
