---
name: issue-33-release-engineering-gate-machine
subject: issue-33
role: release-engineering
status: proposed
---

# Proposal — release-engineering enforcement mechanism (phase 1)

Current-state survey: `docs/issue-33/reports/release-engineering/survey.md`.
Scout brief: `docs/issue-33/reports/release-engineering/scout-brief.md`.

## Scope / change description

This revision responds to the approver's plugin-set feedback on issue #33 /
PR #34 and **supersedes** this document's prior design (a single elaborated
`ops/hooks/directive.sh` plus two extended gates). The feedback: this role's
enforcement mechanism must not be one directive/gate pair grown larger — it
must be a **set of independent, self-contained plugins**, one per adopted
methodology, each freelunch/scout-level complete (own `.claude-plugin/
plugin.json`, own hooks, own tests), the way `/home/jwjung/tokenmaxxxer/
tokenmaxxxer-core/` already structures `core`, `terse`, `freelunch`,
`scout`, `warrant` as separate marketplace entries rather than one plugin
with growing internals.

Issue #27 adopted a methodology (RFC-shaped phase-1 proposals; PRR/canary/
postmortem/error-budget phase-2 shapes — `docs/issue-27/proposals/
2026-07-31-rulebook-maturation.md`) that today lives as one `ops` plugin: a
one-line-facet `ops/hooks/directive.sh`, two PreToolUse gates
(`proposal-fields-gate.sh`, `rollout-plan-fields-gate.sh`), and four skills
(`error-budget-policy`, `postmortem`, `readiness-checklist`,
`rollout-plan`). This proposal's design: split that single plugin into
**five** independent plugins, each owning exactly one methodology, and
define phase-1 and phase-2 norms as **compositions** of those plugins
rather than facets of one directive. This is still a phase-1 design
document only — no file under `ops/hooks/`, `ops/skills/`,
`.claude-plugin/marketplace.json`, or `tests/` is modified by this PR.

## Plugin list

Five independent, single-methodology plugins. Each is intended to live as
its own top-level directory in phase 2 (`<name>/.claude-plugin/
plugin.json`, `<name>/hooks/`, `<name>/hooks/tests/`), registered as a
separate entry in this repo's `.claude-plugin/marketplace.json` — mirroring
how `tokenmaxxxer-core/scout/` and `tokenmaxxxer-core/freelunch/` each carry
their own `hooks/hooks.json`, `hooks/*.sh`, and `hooks/tests/parse-check.sh`
rather than sharing one directive file.

| Plugin | Methodology owned | Components | New / relocated |
|---|---|---|---|
| `proposal-norm` | RFC-shaped phase-1 proposal (scope, risk, rollback, sourced-evidence — issue-27's adopted shape) | directive fragment (proposal-stage prohibitions, stated as rules, not summary); `proposal-fields-gate.sh`; allow/deny tests | Gate relocated unchanged from `ops/hooks/proposal-fields-gate.sh`; directive fragment new |
| `readiness-checklist` | PRR (production readiness review): all seven dimensions (monitoring, alerting, rollback, capacity, runbooks, dependencies, on-call) must resolve yes/no with a pointable artifact | directive fragment (judgment criterion + "no link is a FAIL, not a pass with a caveat" prohibition); new gate `readiness-fields-gate.sh`; allow/deny tests | Gate wholly new — no PRR field gate exists today |
| `rollout-plan` | canary rollout: pre-declared thresholds before result | directive fragment (existing "no step may be marked pass/fail with a threshold decided after the fact" prohibition); `rollout-plan-fields-gate.sh`; allow/deny tests (missing-threshold+pass -> deny; pending -> allow; thresholded+pass -> allow) | Gate relocated unchanged from `ops/hooks/rollout-plan-fields-gate.sh`; directive fragment new |
| `error-budget-policy` | error-budget hard stop: exhausted budget refuses release steps regardless of readiness, non-discretionary | directive fragment (hard-stop assertion, not an on-call-overridable judgment call); new gate `error-budget-gate.sh` blocking a rollout-plan step advance when the record's budget field reads exhausted; allow/deny tests | Gate wholly new — today error-budget-policy is skill-prose only, no mechanical check |
| `postmortem` | human-reviewed postmortem before loop closes | directive fragment ("satisfied only by a postmortem a HUMAN has reviewed... `Reviewed by` field must be non-empty before `loop_state` may read `steady`"); `postmortem-review-gate.sh` (PreToolUse on postmortem file writes / `loop_state` transitions); allow/deny tests | Gate wholly new; exact `Reviewed by` field name confirmed against `postmortem-template.md` in phase 2, not invented here |

## Composition design

The core of this design, per the feedback, is not the plugin list itself
but how plugins **compose** into the two norms this role enforces:

- **Phase-1 (기획서) norm = `proposal-norm` alone.** No other plugin
  participates in phase-1 enforcement — a release proposal document is a
  single self-contained artifact, and `proposal-fields-gate.sh` already
  polices it as one document with no cross-plugin dependency (unchanged
  from the current design's risk analysis on this point).
- **Phase-2 (산출물) norm = `readiness-checklist` + `rollout-plan` +
  `error-budget-policy` + `postmortem`, composed.** A release's phase-2
  deliverable is complete only when all four plugins fire and pass — no
  single plugin alone constitutes the phase-2 norm. This mirrors issue-27's
  four adopted phase-2 skill shapes exactly (PRR readiness, canary rollout,
  error-budget hard-stop, human-reviewed postmortem), now each backed by
  its own gate instead of one shared directive facet.
- **The current `ops` plugin's role directive stops being the single
  owner of all four `HAND_OFF` facets.** Today `ops/hooks/directive.sh`
  hand-writes one `HAND_OFF` string covering readiness, error budget,
  rollout, and postmortem together. Under this design, each of the four
  phase-2 plugins owns its own directive fragment for its methodology, and
  `ops/hooks/directive.sh` (or its phase-2 successor) **composes** them at
  role-enable time by sourcing/concatenating the enabled plugins' fragments
  before making the same `core_role_directive "$YOU_DECIDE" "$USE_WHEN"
  "$PRODUCES" "$HAND_OFF"` call — the 4-arg signature is unchanged (still
  matches `core/hooks/lib/role-directive.sh`, which only echoes its four
  string args and adds no parsing constraint), but each arg's content is
  now assembled from N plugin fragments rather than hand-written once.
  **This composition point is an open phase-2 design question, not
  resolved here.** A candidate shape, given as a starting point for phase
  2 to confirm or replace:

  ```sh
  # ops/hooks/directive.sh (phase-2 sketch, not implemented in this PR)
  HAND_OFF=""
  for frag in readiness-checklist rollout-plan error-budget-policy postmortem; do
    frag_file="${CLAUDE_PLUGIN_ROOT_RELEASE_ENG:-.}/${frag}/hooks/directive-fragment.txt"
    [ -f "$frag_file" ] && HAND_OFF="${HAND_OFF}$(cat "$frag_file")"$'\n\n'
  done
  core_role_directive "$YOU_DECIDE" "$USE_WHEN" "$PRODUCES" "$HAND_OFF"
  ```

  Open questions phase 2 must resolve, not this proposal: fragment file
  format/location convention, ordering guarantee across concatenated
  fragments, and what happens when a plugin is registered in
  `marketplace.json` but not enabled for this role.
- **State-tracking scope stays as previously scouted**, now attributed
  per-plugin: none needed for `proposal-norm` or `rollout-plan`
  (single-document, stateless, per scout-brief.md item 2 and the risk
  analysis below); `error-budget-policy` performs a single read of the
  record file's budget field, no cross-file ordering; `postmortem` is the
  one plugin with a genuine field-presence gate (not full cross-file state
  machinery — scout already ruled that out; cite scout-brief.md item 2).

## Risk

Named failure modes if this proposal's design is wrong:

- **Five independent plugins drift out of sync with no shared directive
  owner.** With one hand-written `ops/hooks/directive.sh` today, all four
  `HAND_OFF` facets are guaranteed present because one file asserts them.
  Splitting into five plugins risks a plugin being registered in
  `marketplace.json` but its directive fragment silently missing from the
  composed `HAND_OFF` (e.g., disabled, renamed, fragment file moved) —
  producing a directive that no longer states a rule its gate still
  enforces, or a gate with no directive-text backing. Mitigated in phase 2
  by a lint/gate step that asserts every enabled plugin's directive
  fragment is present (non-empty) in the composed directive before
  `directive.sh` returns — analogous in spirit to `tests/parse-check.sh`'s
  role as a structural precondition check, but scoped to fragment presence
  rather than bash parseability.
- **Directive elaboration ships as padding, not instruction** (carried
  forward, now per-fragment): if a plugin's directive fragment restates
  its own skill-file prose instead of adding trigger-condition/prohibition
  specificity, the composed directive grows without closing the
  enforcement gap issue #33 was raised over. Mitigated by writing each
  fragment as concrete triggers ("when X, before Y, refuse Z"), per the
  plugin list above, not summary prose.
- **Inventing an ordering/state requirement that doesn't exist** (carried
  forward): scout found no genuine cross-file ordering gap beyond the
  postmortem human-review case. Mitigated by the state-tracking scope
  stated explicitly above, per plugin, rather than assumed uniformly.
- **Gate tests copy a nonexistent exemplar** (carried forward):
  implementation-rulebook's own cited rigor-bar gate has no dedicated
  per-gate fixture file (scout finding). Mitigated by pointing every new
  plugin's `hooks/tests/` at the actual working precedent — this repo's
  own `tests/deny-only-check.sh`, which already embeds a substance probe
  (temp dir + synthetic PreToolUse JSON on stdin + assert deny).

## Rollback / back-out path

This PR adds only new files under `docs/issue-33/`. If the design is
rejected: do not merge; comment on the PR with the objection; a revised
proposal supersedes this one. If merged and phase 2 later proves the
plugin-set design wrong: `git revert` the phase-2 delivery PR(s) — issue-27's
two existing gates and directive remain functionally unaffected during
migration since phase 2 relocates them via `git mv` (see Migration note),
not rewrite, so a revert restores the pre-migration `ops/hooks/` layout
intact. No data migration, no external state, is introduced.

## Gate tests

Per plugin, same specificity as the prior single-plugin design, now
attributed to each plugin's own `hooks/tests/`, following the substance-probe
pattern already established by `tests/deny-only-check.sh`:

- **`proposal-norm/hooks/tests/`**: (a) a proposal document missing each of
  the four sections (scope/risk/rollback/citation) in turn -> expect deny
  with the specific missing-section name in stderr; (b) a complete proposal
  with all four sections -> expect exit 0.
- **`readiness-checklist/hooks/tests/`**: (a) a readiness document missing
  one of the seven PRR dimensions -> deny; (b) a dimension present but with
  no link/pointer -> deny (this is the "FAIL, not pass with a caveat" rule);
  (c) all seven dimensions present, each with a pointer -> allow.
- **`rollout-plan/hooks/tests/`**: (a) a step marked `result: pass` with a
  metric missing `threshold:` -> deny; (b) same step with `result: pending`
  -> allow (thresholds not required until resolution); (c) same step fully
  thresholded and `result: pass` -> allow.
- **`error-budget-policy/hooks/tests/`**: (a) record's budget field reads
  `exhausted` and a rollout-plan step attempts to advance -> deny; (b)
  budget field reads non-exhausted -> allow.
- **`postmortem/hooks/tests/`**: (a) write with empty `Reviewed by:` field
  -> deny; (b) write with a populated reviewer field -> allow. Exact field
  name confirmed against `postmortem-template.md` in phase 2, not invented
  here.
- All new/edited gate `.sh` files must continue to pass
  `tests/parse-check.sh` (bash 3.2 parseability) unchanged.

## Migration note

Two gates already exist under `ops/hooks/` today:
`proposal-fields-gate.sh` and `rollout-plan-fields-gate.sh`. Phase 2
relocates each via `git mv` — not a rewrite — into `proposal-norm/hooks/`
and `rollout-plan/hooks/` respectively, then updates the corresponding
`hooks.json` registration and adds a `.claude-plugin/marketplace.json`
entry for each new plugin directory. Three gates are wholly new and have
no prior file to relocate: `readiness-fields-gate.sh` (under
`readiness-checklist/hooks/`), `error-budget-gate.sh` (under
`error-budget-policy/hooks/`), and `postmortem-review-gate.sh` (under
`postmortem/hooks/`).

## Out of scope

- Editing `ops/hooks/*`, `ops/skills/*`, `.claude-plugin/marketplace.json`,
  or any `tests/*.sh` file — phase 2 only, after human Approve.
- Re-deriving or changing the four phase-2 skills' methodology content
  (confirmed correct by issue-27, untouched here).
- Building any of the three new gates, or confirming
  `postmortem-template.md`'s literal field names — phase 2 reads the
  actual skill file before writing the regex.
- Resolving the directive-fragment composition mechanism's open questions
  (format, ordering, enable/registration mismatch handling) — flagged
  above as an open phase-2 design question, not settled by this proposal.
- Any cross-role (coding/verify-style) finding-lifecycle machinery — scout
  found no such dependency for this role's current artifact set.

## Phase gate

**PHASE 1 ONLY.** This PR proposes a design; it implements nothing under
`ops/hooks/`, `ops/skills/`, `.claude-plugin/marketplace.json`, or
`tests/`. Phase 2 opens only on an `approvers.md` PR Approve, or the
exact-string `APPROVE issue-33/release-engineering` issue comment, per
contract v3 s19.
