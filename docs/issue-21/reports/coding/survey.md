---
kind: survey
issue: 21
---

# Current-state survey — issue 21

Scope per issue: strip routing-side vocabulary (wake, board-as-routing-device,
WAKES-ON, downstream roles, pointers to wake-routing.md) from rulebook text,
restating record obligations as pure record-format requirements. Historical
docs untouched. Sweep directive.sh, specs, skills, gate comments, plugin
descriptions.

## Scout skip record

Skipped scouting: the spec leaves no design decision open (skip condition 2
of scout-directive). The issue names the exact vocabulary to remove and the
exact vocabulary to keep (path, kind, loop_state, required fields, phase-2
write-first, loop_state-per-transition, commit-on-branch); this is a
mechanical rewrite, not a build with an open field to survey.

## Write set (searched with grep across all tracked, non-historical files)

Searched for `WAKES-ON`, `wake-routing`, `board-as-routing`, `downstream
role`, `\bwake`, `\bwoken`, `the board`, `routes to next` across:
`ops/hooks/*.sh`, `ops/skills/*/SKILL.md`, `.claude-plugin/marketplace.json`,
`ops/.claude-plugin/plugin.json`, `docs/specs/*.md`, `README.md`,
`docs/README.md`.

Only one file in this repo carries the flagged vocabulary:

- `ops/hooks/directive.sh` (lines 50–58) — the "YOUR RECORD IS THE BOARD"
  block of the `ops` role directive. It says the record's absence leaves
  "the board" unseeing, invokes "machine wake-up," and points to
  `docs/specs/wake-routing.md` as the canon for who the record "routes to
  next."

No other tracked file (skills, other gate scripts, plugin descriptions,
specs/approvers.md, READMEs) mentions this vocabulary. `docs/specs/` in this
repo holds only `approvers.md` — no `wake-routing.md` lives here (it is
on-the-record's canon, in a different repo, out of scope per the issue).

There is no separate `coding` role directive file in this repository (this
repo, `ops-agent-rulebook`, only ships the `ops` role's hooks); the `coding`
directive text visible in this session's system reminders is supplied by a
different rulebook plugin outside this git tree, so it is out of scope for
edits here.

## What stays

The record-format obligations already present in the flagged block — write
`docs/issue-<n>/reports/ops.md` as phase 2's first act, update `loop_state`
at every transition, the record must be committed on the branch — are
record-format requirements, not routing vocabulary, and are kept, restated
without the board/wake framing.
