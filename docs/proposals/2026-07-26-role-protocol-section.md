---
status: landed
files:
  - README.md
  - ops-cycle/hooks/state-gate.sh
---

# Role protocol section for ops

## Intent

An ops session today has to read the full shared
`docs/specs/role-handoff-contract.md` to find its two accepted input kinds
and two output kinds among six roles' worth of rows. This proposal adds a
"Handoff protocol" section to `README.md` carrying only ops's rows, so the
session reads one page scoped to its own role.

## Constraints that change what gets built

- Excerpt only, from `docs/specs/role-handoff-contract.md` at
  `2affe5db7dfb285abaa2860d3004edb3f97c9aec` (root `tokenmaxxxer` repo) —
  ops's rows from sections 2, 3, and 7, plus its reading of sections 1, 4,
  and 6 (the note flagging `ops-state` as a living document inside a
  reports bucket meant for closed, dated artifacts).
- The section header pins that SHA; `ops-cycle/hooks/state-gate.sh`, which
  already gates ops-cycle state transitions, gains a check that refuses to
  proceed when the pinned SHA no longer matches the contract's current SHA.
- Per-role path ownership (section 7) is enforced by this same gate, since
  warrant's write-set gate deliberately does not constrain writes under
  `docs/` and section 7 assigns that enforcement to each rulebook.

## What will be done

Add "Handoff protocol" to `README.md` with four parts:

1. **ACCEPTS** — `build-proposal` (what merged) and `hypothesis` or
   `feasibility-record` (the measurement design); refuses `qa-state` and
   `review-record` (ops acts on review's finished verdict via the merge
   itself, not by reading review's per-finding record).
2. **WHERE UPSTREAM LIVES** — `docs/proposals/<date>-build-<slug>.md` for
   `build-proposal`; `docs/proposals/<date>-<slug>.md` for `hypothesis`;
   `docs/reports/records/<subject>/feasibility.md` for
   `feasibility-record`.
3. **PRODUCES** — `ops-state` at `docs/reports/records/<subject>/ops.md`,
   required fields: role status (`idle,readiness,rollout,steady,incident`),
   `error_budget: ok|exhausted`, `postmortem: <pointer>`, a `## Checklist`
   section (`- item: <desc> | status: yes|no | artifact: <url/path/config
   key>`), plus the common header including `handoff_status`; and
   `postmortem` at
   `docs/reports/records/<subject>/postmortems/<incident-slug>.md`,
   required fields: Impact, Actions taken during response, Root cause(s),
   Prevention follow-up (owner+tracking+closing-condition), Review (named
   human reviewer).
4. **STOPS** — upstream stale at role entry (recorded `sha` for whichever
   of `build-proposal`/`hypothesis`/`feasibility-record` was read, against
   its current `sha`); an existing record already at a path ops does not
   own under `docs/reports/records/` (refuse, report, never overwrite);
   input carrying `handoff_status: provisional` when ops is not permitted
   to treat it as final baseline for a readiness or rollout decision.

Also add the SHA-pin check to `ops-cycle/hooks/state-gate.sh`.

## What did not work

- First pass had the SHA-pin check `deny_rules_unloaded` whenever the root
  `tokenmaxxxer` repo (holding `docs/specs/role-handoff-contract.md`) could
  not be located from this checkout. That would deny every transition on
  every standalone install of this self-contained repo, making the pin a
  de facto kill switch — reversed to treat "contract unreachable" as
  unverifiable-but-not-denied, only denying on an actual SHA mismatch.

## Out of scope

Changing `docs/specs/role-handoff-contract.md`. Changing warrant's
`scope-gate.sh` (not present in this repo). The other five rulebook repos.
Starting any ops-cycle build work.

## How you will know it worked

An ops session can answer, from `README.md` alone, both accepted kinds and
where to find them, both produced kinds and where they land, and its three
stop conditions. `state-gate.sh` refuses to proceed when the pinned SHA no
longer matches the contract's current SHA, and refuses a write to a
`docs/reports/records/` path ops does not own.
