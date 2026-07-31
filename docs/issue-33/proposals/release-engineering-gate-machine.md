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

Issue #27 adopted a methodology (RFC-shaped phase-1 proposals; confirmed
PRR/canary/postmortem phase-2 shapes) that landed as directive prose (a
one-line `PRODUCES` summary) plus two PreToolUse field gates
(`proposal-fields-gate.sh`, `rollout-plan-fields-gate.sh`). Issue #33 asks
that this be brought up to implementation-rulebook's hook-machine bar:
(1) elaborate `ops/hooks/directive.sh` into per-phase, per-facet,
multi-paragraph stage/judgment/prohibition text instead of one-line
summaries; (2) confirm/extend the methodology gates so every approved
"produces" element from issue-27 is machine-checked, adding state tracking
only where a genuine ordering constraint exists; (3) add gate-specific
tests at repo-root `tests/`; (4) add an agent/checklist only if a genuinely
repeated procedure is found (scout found none beyond what already exists).
This is a phase-1 design document only — no file under `ops/hooks/` or
`tests/` is modified by this PR.

## Risk

Named failure modes if this proposal's design is wrong:

- **Directive elaboration ships as padding, not instruction** — if the
  `$'...'` blocks restate skill-file prose instead of adding
  trigger-condition/prohibition specificity, phase 2 produces a longer
  directive with the same enforcement gap issue #33 was raised to close.
  Mitigated by the per-facet spec below being written as concrete
  triggers ("when X, before Y, refuse Z"), mirroring coding's directive
  shape exactly rather than summarizing it.
- **Inventing an ordering/state requirement that doesn't exist** — scout
  found no genuine cross-file ordering gap in the two existing gates (each
  polices one document's own completeness). Building a coding-style
  cross-file state machine here anyway would add machinery this role's
  actual "produces" set does not need, and could silently start refusing
  legitimate single-document writes it was never designed to judge.
  Mitigated by explicitly scoping state tracking OUT for the two existing
  gates (see below) and IN, narrowly, only for the one place scout found a
  real candidate: postmortem human-review-before-close.
- **Gate tests copy a nonexistent exemplar** — implementation-rulebook
  itself has no per-gate fixture file (confirmed by scout: `coding/hooks/
  tests/` does not exist). A proposal that assumed one and pointed phase 2
  at it would send phase 2 hunting for a file that isn't there. Mitigated
  by pointing at the actual working precedent: this repo's own
  `tests/deny-only-check.sh`, which already embeds a substance probe.

## Rollback / back-out path

This PR adds only new files under `docs/issue-33/`. If the design is
rejected: do not merge; comment on the PR with the objection; a revised
proposal supersedes this one. If merged and phase 2 later proves the
design wrong: `git revert` the phase-2 delivery PR — the two existing
issue-27 gates and directive remain unaffected since phase 2 will edit them
additively (extending `PRODUCES`'s string content and adding sibling gate
files), not replacing the mechanism issue-27 already shipped. No data
migration, no external state, is introduced.

## Evidence format

Every methodology/precedent claim below cites the file read this session.

## Directive elaboration design (phase 2 target for `ops/hooks/directive.sh`)

Following coding's `directive.sh` shape (each of the four
`core_role_directive` arguments becomes a `$'...'` multi-line block; the
function signature is unchanged — `core_role_directive "$YOU_DECIDE"
"$USE_WHEN" "$PRODUCES" "$HAND_OFF"`, confirmed against
`core/hooks/lib/role-directive.sh`, which only echoes its four string
args and adds no parsing constraint):

- **`YOU_DECIDE`** (unchanged in substance, kept as today): the role's
  authority statement — no phase split needed here, it is already a
  judgment-criteria statement ("gated by measurable reliability rather
  than discretionary sign-off").
- **`USE_WHEN`** (phase 1, elaborated per facet):
  - RESEARCH (scout stage): what "exemplar" means for a release
    (comparable systems' rollout curves/bake times, failure modes that
    reached production in similar systems, postmortem patterns worth
    checking against this change) — already present; keep, unchanged.
  - CURRENT-STATE SURVEY stage: explicit judgment criterion — every one of
    the seven PRR dimensions (monitoring, alerting, rollback, capacity,
    runbooks, dependencies, on-call) must resolve to yes/no with a
    pointable artifact at survey time, not only at gate time — this moves
    the readiness-checklist's phase-2 bar earlier, into the phase-1
    stage's judgment criteria, so a survey that says "we have monitoring"
    with nothing to link is flagged as incomplete before proposal, not
    only refused at gate time.
  - PROPOSAL stage (new explicit sub-block): the four RFC-shaped sections
    from issue-27, stated as **prohibitions**, not summary — "no proposal
    may state a risk as 'risks exist'; name the failure mode. No proposal
    may omit rollback on the claim it is obvious. No adopted-methodology
    claim may go uncited." This turns proposal-fields-gate's checked
    strings into directive-stated rules the directive itself asserts,
    closing the "gate as the only source of truth" gap.
- **`PRODUCES`** (phase 1, split by facet instead of one run-on sentence):
  one paragraph for the rollout plan (skill: rollout-plan) stating the
  per-step threshold-before-result rule as a prohibition ("no step may be
  marked pass/fail with a threshold decided after the fact"); one separate
  paragraph for the RFC-shaped proposal norm citing issue-27's four
  sections explicitly by name.
- **`HAND_OFF`** (phase 2, elaborated per facet, each an explicit
  judgment criterion + prohibition pair, following coding's pattern of
  named sub-rules rather than one sentence):
  - Readiness: "yes/no + pointable artifact per PRR item; an item with no
    link is a FAIL, not a pass with a caveat."
  - Error budget: "exhausted refuses release steps regardless of
    readiness — this is a hard stop, not a discretionary judgment call
    the on-call engineer may override in the directive's own text."
  - Rollout: "steps advance only on pre-declared thresholds; inconclusive
    holds — holding is not a failure state requiring escalation, it is
    the designed outcome of an inconclusive read."
  - Postmortem: "satisfied only by a postmortem a HUMAN has reviewed; a
    model-only postmortem does not close the loop — state where the
    `Reviewed by` field must be non-empty before `loop_state` may read
    `steady`."

## Methodology gate design (phase 2 target — described, not implemented here)

Two existing gates are already machine-verifying their respective single
documents; this proposal's phase 2 does not replace them, only extends
coverage:

1. **`proposal-fields-gate.sh`** — no structural change; confirm during
   phase 2 that the directive elaboration above (proposal-stage
   prohibitions) is textually consistent with what the gate already
   checks (scope/risk/rollback/citation) so directive and gate assert the
   same rule in two forms (prose + mechanical), never a diverging pair.
2. **`rollout-plan-fields-gate.sh`** — no structural change; same
   consistency check against the elaborated `PRODUCES` rollout-plan
   paragraph.
3. **New, narrowly-scoped gate candidate: postmortem-review-gate.sh** — on
   a write to a postmortem file under
   `docs/issue-<n>/reports/postmortems/<slug>.md` (or the record file's
   `loop_state` transition to `steady`/`idle`), require a non-empty
   `Reviewed by:` field (and `Reviewer satisfied: yes`, or equivalent, if
   the postmortem-template skill's exact field names differ — phase 2
   confirms the literal field names against `postmortem-template.md`
   before writing the regex) before the write is allowed. This is the one
   place scout identified an actual gap between what the skill's prose
   requires (human review before close) and what today is
   mechanically enforced (nothing) — everywhere else, no new state
   tracking is warranted (see Risk above and scout-brief item 2).
   Fail-closed shape, kill switch, `hooks.json` registration: identical
   discipline to the two existing gates.
4. **State tracking**: explicitly NOT added for the two existing gates
   (no cross-file ordering constraint found). If phase 2's confirmation of
   postmortem-template field names finds the human-review step already
   spans multiple files (e.g., a separate reviewer sign-off record), a
   single boolean marker (not a coding-style multi-role finding lifecycle)
   is sufficient — phase 2 decides the minimal shape once the literal
   fields are read, not invented here.

## Gate tests (phase 2 target — described, not implemented here)

Per scout finding 3: implementation-rulebook's own cited rigor-bar gate
(`coding-progress-gate.sh`) has no dedicated per-gate fixture file
anywhere in that rulebook; the actually-working local precedent is this
repo's `tests/deny-only-check.sh`, which already embeds a "substance
probe" (temp dir, synthetic PreToolUse JSON on stdin, assert a deny).
Phase 2 should:

- Add allow/deny cases for `proposal-fields-gate.sh`: (a) a proposal
  document missing each of the four sections in turn -> expect deny with
  the specific missing-section name in stderr; (b) a complete proposal
  with all four sections -> expect exit 0.
- Add allow/deny cases for `rollout-plan-fields-gate.sh`: (a) a step
  marked `result: pass` with a metric missing `threshold:` -> deny; (b)
  same step with `result: pending` -> allow (thresholds not required
  until resolution); (c) same step fully thresholded and `result: pass`
  -> allow.
- If the postmortem-review gate above is built, add: (a) write with empty
  `Reviewed by:` -> deny; (b) write with a populated reviewer field ->
  allow.
- Location: extend `tests/deny-only-check.sh` with role-specific probes
  (matching its existing internal pattern), or add a sibling
  `tests/release-engineering-gates-check.sh` if the existing file's
  single-responsibility (deny-only + one generic substance probe) should
  not grow further — phase 2 decides based on how large the addition gets.
- All new/edited gate `.sh` files must continue to pass
  `tests/parse-check.sh` (bash 3.2 parseability) unchanged.

## Agents / checklists

Scout found no repeated procedural step in release-engineering's artifact
set analogous to coding's hunt cadence. The four phase-2 skills
(`error-budget-policy`, `readiness-checklist`, `rollout-plan`,
`postmortem`) already function as the checklists. No new agent or
checklist file is proposed beyond the postmortem-review gate above.

## Canon reference discipline

This proposal references `core/hooks/lib/role-directive.sh` and
implementation-rulebook's hook files by path, for comparison and as the
call-signature contract phase 2 must preserve. No content from either is
copied into this repo; `docs/handbooks/canon-scripts.md`'s reference-only
rule is unaffected — phase 2 continues sourcing `role-directive.sh` via
`${CLAUDE_PLUGIN_ROOT_CORE:-...}` exactly as `ops/hooks/directive.sh`
already does today.

## Out of scope

- Editing `ops/hooks/directive.sh`, `proposal-fields-gate.sh`,
  `rollout-plan-fields-gate.sh`, `hooks.json`, or any `tests/*.sh` file —
  phase 2 only, after human Approve.
- Re-deriving or changing the four phase-2 skills' methodology content
  (confirmed correct by issue-27, untouched here).
- Building the postmortem-review gate itself, or confirming
  `postmortem-template.md`'s literal field names — phase 2 reads the
  actual skill file before writing the regex.
- Any cross-role (coding/verify-style) finding-lifecycle machinery — scout
  found no such dependency for this role's current artifact set.

## Phase gate

**PHASE 1 ONLY.** This PR proposes a design; it implements nothing under
`ops/hooks/` or `tests/`. Phase 2 opens only on an `approvers.md` PR
Approve, or the exact-string `APPROVE issue-33/release-engineering` issue
comment, per contract v3 s19.
