# Current-state survey — issue-19

Scope check (skip condition applies): this is a scoped textual edit with
no design decision left open — the issue names the exact target text
(WAKES-ON/wake mentions) and the exact disposition (keep own record
state/format, strip or repoint routing). Scouting skipped per
scout-directive's "spec literally leaves no design decision open".

## Search

`grep -rliE "wakes-on|wake-on|WAKES ON"` and `grep -n -iE "wake"` over
all tracked files, excluding docs/issue-*/ (per-issue trees are exempt
by the issue text) and docs/proposals/ historical write-ups (not live
rulebook content).

## Write set

- `ops/hooks/directive.sh` (lines 50–57): the ops role directive's
  "YOUR RECORD IS THE BOARD" paragraph. Currently says "WAKES-ON reads
  docs/issue-<n>/reports/ops.md ONLY" and "no downstream role can ever
  be woken by it" — both name that another role is summoned by this
  role's record, which is routing, not this role's own record
  state/format.

No other live rulebook file mentions wakes/WAKES-ON:
- `ops/hooks/handbook-trigger-gate.sh`, `record-fields-gate.sh`,
  `trailer-gate.sh`, `hooks.json`, `plugin.json` — none.
- `ops/skills/*/SKILL.md` — none.
- `docs/specs/approvers.md`, `docs/README.md` — none.
- `docs/proposals/2026-07-26-contract-v2-conformance.md` mentions
  WAKES-ON extensively but is a dated historical proposal record, not
  live rule text — out of scope (the issue targets "this rulebook",
  i.e. the enforced directive/gate files, not its own history).

## What will change

Rewrite the one paragraph in `ops/hooks/directive.sh` to keep: where
the record lives, that it must be written first in phase 2, that it
must be updated at loop_state transitions, and why (unwritten record =
board never saw the work). Drop: "WAKES-ON", "no downstream role can
ever be woken by it" (naming that a role is summoned). Repoint the
removed routing claim to on-the-record `docs/specs/wake-routing.md`
(external repo, per issue: "canon now at on-the-record
docs/specs/wake-routing.md").
