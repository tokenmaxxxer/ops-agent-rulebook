---
subject: issue-33
role: release-engineering
kind: phase-2-record
status: delivered
---

# Phase 2 delivery — release-engineering enforcement mechanism (issue #33)

Approved by `APPROVE issue-33/release-engineering` (single-account mode,
exact-string issue comment, per contract v3 s19), on top of the approver's
plugin-set feedback captured in `docs/issue-33/proposals/
release-engineering-gate-machine.md` (upstream basis for everything below).

loop_state: landed

## What was done, and why

What was done: the approved plugin-set proposal was implemented in full —
five self-contained plugins split out of the single `ops` plugin, the
phase-1/phase-2 composition wired through `ops/hooks/directive.sh`, three
new gates written and tested, two gates relocated unchanged, and
`.claude-plugin/marketplace.json` updated to register all six plugins. Why:
issue #33 asked for the adopted methodologies to be enforced mechanically
rather than living as directive prose alone, and the approver's feedback
(on PR #34) specified the plugin-set shape as the required structure rather
than a single elaborated directive/gate pair — this record captures that
the delivered structure matches the approved design, not a paraphrase of
it.

## Open findings

None open. All 16 allow/deny fixture cases pass; `tests/parse-check.sh`
passes against every plugin's `hooks/` directory; the composed `HAND_OFF`
was verified to include all four phase-2 fragments in order. One defect
was found and fixed during delivery itself (a backtick-quoted plugin name
inside a double-quoted bash string in `ops/hooks/directive.sh` was
executed as command substitution rather than rendered as prose) — see
"Verification run this session" below; it does not recur in the delivered
file.

## What was built

The single `ops` plugin's two facets (RFC-shaped phase-1 proposal norm;
readiness/rollout/error-budget/postmortem phase-2 norms) are split into
**five independent, self-contained plugins**, each one methodology, each
registered as its own `.claude-plugin/marketplace.json` entry — mirroring
how `tokenmaxxxer-core` structures `core`, `terse`, `freelunch`, `scout`,
`warrant` as separate entries rather than one growing plugin.

| Plugin | Directory | Gate | Directive fragment | Tests |
|---|---|---|---|---|
| `proposal-norm` | `proposal-norm/` | `hooks/proposal-fields-gate.sh` (relocated unchanged via `git mv` from `ops/hooks/`) | `hooks/directive-fragment.txt` | `hooks/tests/allow-deny-check.sh` (4 cases) |
| `readiness-checklist` | `readiness-checklist/` | `hooks/readiness-fields-gate.sh` (new) | `hooks/directive-fragment.txt` | `hooks/tests/allow-deny-check.sh` (4 cases) |
| `rollout-plan` | `rollout-plan/` | `hooks/rollout-plan-fields-gate.sh` (relocated unchanged via `git mv` from `ops/hooks/`) | `hooks/directive-fragment.txt` | `hooks/tests/allow-deny-check.sh` (3 cases) |
| `error-budget-policy` | `error-budget-policy/` | `hooks/error-budget-gate.sh` (new) | `hooks/directive-fragment.txt` | `hooks/tests/allow-deny-check.sh` (3 cases) |
| `postmortem` | `postmortem/` | `hooks/postmortem-review-gate.sh` (new) | `hooks/directive-fragment.txt` | `hooks/tests/allow-deny-check.sh` (2 cases) |

Each plugin also carries its own `.claude-plugin/plugin.json`, `hooks/
hooks.json`, and (for the four skill-backed methodologies) its own `skills/
<name>/SKILL.md`, relocated via `git mv` from `ops/skills/`. Every new/
relocated gate is fail-closed (an internal error denies, never allows),
carries a same-shape kill switch (`<GATE>_OFF=1`), and reads only its own
methodology's write surface — no cross-plugin coupling beyond the shared
`ops/state.md` field convention documented in each skill.

`ops/` itself now owns no methodology gate. `ops/hooks/directive.sh`
composes the phase-2 norm at `SessionStart`: it concatenates whichever of
`readiness-checklist`, `rollout-plan`, `error-budget-policy`, `postmortem`
are actually checked out as sibling directories (each plugin resolved via a
`CLAUDE_PLUGIN_ROOT_<NAME>` env var, falling back to a relative sibling
path — the same convention `CLAUDE_PLUGIN_ROOT_CORE` already established),
in a fixed order, into `HAND_OFF`. A plugin not installed for this role is
skipped, not an error; if none of the four are found, a fallback string
says so explicitly rather than silently shipping an empty `HAND_OFF`. This
resolves the prior proposal's open composition question (format/ordering/
missing-plugin handling). `PRODUCES` still states `proposal-norm`'s
phase-1 shape inline (phase 1 = `proposal-norm` alone; it does not
participate in the `HAND_OFF` concatenation).

`.claude-plugin/marketplace.json` registers all six plugins (`ops` plus
the five methodology plugins). `ops/hooks/hooks.json` now carries only the
`SessionStart` directive hook; the two `PreToolUse` gate registrations
moved to their new plugins' own `hooks.json` files.

## Composition, confirmed as designed

- **Phase 1 (기획서) norm = `proposal-norm` alone** — unchanged from the
  approved design; no other plugin participates.
- **Phase 2 (산출물) norm = `readiness-checklist` + `rollout-plan` +
  `error-budget-policy` + `postmortem`, composed** — verified by running
  `ops/hooks/directive.sh` locally with the four sibling plugin
  directories present: all four fragments appear in the composed
  `HAND_OFF`, in the declared order.

## New gates' design (not in the original proposal — resolved during
delivery, reading the actual skill files rather than inventing ahead of
them, per the proposal's own "Out of scope")

The four phase-2 skills (`readiness-checklist/skills/readiness-checklist/
SKILL.md`, etc.) already described a shared `ops/state.md` state file with
a `status:` field and, for `steady`, an `error_budget:` field, and a
`postmortem:` field used when closing an incident. The three new gates
target exactly this shared file, each on the one transition its own
methodology governs:

- `readiness-fields-gate.sh` — refuses a write setting `status: rollout`
  unless every `## Checklist` item resolves `yes`/`no` and every `yes` has
  a non-empty `artifact:` pointer.
- `error-budget-gate.sh` — refuses a write setting `status: readiness`
  when the *current* record's `error_budget:` reads `exhausted`.
- `postmortem-review-gate.sh` — refuses a write setting `status: steady`
  (from a current `status: incident`) unless the write's `postmortem:`
  field names an existing file whose own `Reviewed by:` field is
  non-empty.

All three gates fire only on writes to `ops/state.md` and only on the one
transition each governs; any other write to that file (or to any other
path) passes through untouched. This is stateless, single-document
field-presence checking — the same shape as the two relocated gates and
the scout brief's ruled-out finding of no genuine cross-file ordering gap.

## Verification run this session

- Each plugin's `hooks/tests/allow-deny-check.sh` run standalone: 16
  allow/deny cases total, all passing, covering the relocated and new
  gates' documented deny/allow behavior (missing section, missing
  threshold, empty artifact, no checklist items, exhausted budget,
  unreviewed postmortem, and their allow counterparts).
- `tests/parse-check.sh` run against each of the six plugins' `hooks/`
  directories (`ops`, `proposal-norm`, `rollout-plan`, `readiness-checklist`,
  `error-budget-policy`, `postmortem`) — all files parse under bash 3.2.
- `ops/hooks/directive.sh` run standalone with the four phase-2 plugin
  directories present as siblings — confirmed all four fragments compose
  into `HAND_OFF` in order, and `PRODUCES` states `proposal-norm`'s
  phase-1 shape without executing any of its own backtick-quoted text (a
  bug caught and fixed during this session: a backtick-quoted plugin name
  inside a double-quoted bash string is command substitution, not
  markdown — replaced with plain prose).

## Canon-reference discipline

No file under `core/hooks/` or `core/hooks/tests/` is copied into any of
these plugins; `role-directive.sh` continues to be sourced by path against
the core plugin's own install root, unchanged from the pre-existing
convention. `docs/handbooks/canon-scripts.md`'s clause is satisfied by
inheritance — this delivery adds no new canon-script copy.

## Out of scope (unchanged from the approved proposal)

Re-deriving the four phase-2 skills' methodology content; a full
cross-file state-machine beyond the three single-transition field checks
above; any cross-role finding-lifecycle machinery.
