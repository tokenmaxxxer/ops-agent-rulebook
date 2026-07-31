---
kind: current-state-survey
issue: 27
role: release-engineering
---

# Current-state survey — issue 27

## Write surfaces in this plugin (`ops/`)

- `ops/hooks/directive.sh` — sources core's `role-directive.sh`
  (`core_role_directive`), passing four strings: YOU_DECIDE, USE_WHEN,
  PRODUCES, HAND_OFF. `RECORD_FIELDS_TERMINAL_STATES="steady idle"`.
  This is prose only — nothing in this repo checks that a phase-1 proposal
  or a phase-2 rollout plan actually contains the elements the directive
  names.
- `ops/hooks/hooks.json` — registers `directive.sh` (SessionStart) plus,
  per issue-28's already-merged switch, defers `trailer-gate.sh`,
  `record-fields-gate.sh`, `handbook-trigger-gate.sh` to core's own global
  hooks (this repo's local copies of those three were deleted in #29/#30 —
  confirmed by `78314ea`/`cd0c1fc` in recent log).
- `ops/skills/` — four skills the directive references: `error-budget-policy`,
  `postmortem`, `readiness-checklist`, `rollout-plan`. These are the actual
  methodology content today (read below).
- `docs/specs/approvers.md` — unrelated to methodology, contract plumbing.

## What the four skills currently contain

- **`error-budget-policy`** — per-SLI measurement method / SLO target /
  window / consequence table, written to `ops/error-budget-policy.md`.
  Matches Google's error-budget-policy shape (scout brief).
- **`readiness-checklist`** — the seven-dimension PRR (Service Levels,
  Architecture Design Review, Performance, Documentation, Observability,
  Testing, Deployment Strategy), each item `yes`/`no` + `artifact:`,
  written to `ops/state.md`. "we have monitoring" with no pointer fails.
  Matches the PRR must-be the scout brief found (yes/no + pointable
  artifact).
- **`rollout-plan`** — traffic curve, bake time, metric queries, and
  pre-declared pass/fail/inconclusive thresholds per step, written to
  `ops/rollout-plan.md`. Matches the canary/error-budget must-be (numeric,
  pre-declared, never invented mid-rollout).
- **`postmortem`** — Google's trigger criteria, four required sections
  (impact, actions taken, root cause, prevention/follow-up), and
  incident.io's three-field action-item check (named owner, external
  tracking location, closing condition), written from
  `ops/skills/postmortem/templates/postmortem-template.md`, human-reviewed
  before `incident -> steady`. Matches the postmortem must-be.

**Finding: this repo's phase-2 methodology already matches the field's
converged practice closely** (see scout brief's gap line) — the skills
predate this survey and were themselves built from prior domain research
(`docs/reports/research/2026-07-27-role-practice/ops.md`, cited throughout).
This proposal's phase-2 recommendation is therefore mostly *confirm and
name*, not *invent*.

## What is stale or missing

- The skills reference `ops/state.md`, `state-gate.sh`, `docs/specs/
  state-machine.md`, and `transition-rules.md` as the enforcement layer for
  the idle/readiness/rollout/steady/incident state machine — **none of
  these files exist in this repo.** `ops/hooks/` holds only `directive.sh`
  and `hooks.json`; no `state-gate.sh`. This is pre-contract-v3 design
  language (an internal operational state machine) that was never wired up
  as a gate here, or was retired when this repo adopted role-handoff
  contract v3's simpler phase-1/phase-2 model (visible in `directive.sh`'s
  `RECORD_FIELDS_TERMINAL_STATES="steady idle"`, the one surviving trace).
  Reconciling or removing this dangling reference is out of this issue's
  scope (issue #27 is about phase-1 proposal / phase-2 deliverable norms,
  not the ops-cycle internal state machine) — noted here so phase 2 does
  not accidentally try to enforce a state machine that isn't there.
- **No proposal-document norm exists at all.** Contract v3 s19 requires a
  proposal to exist before phase 2 opens, but nothing in this plugin (or
  core, per `docs/issue-28` survey) states what a *release-engineering*
  proposal must contain beyond the generic contract fields. This is the
  gap issue #27 (a) asks to close.
- **No gate gates the phase-2 skills' outputs.** `readiness-checklist`'s
  `state-gate.sh` reference is dead (see above); nothing in this repo's
  live hooks (`ops/hooks/hooks.json`) checks that a rollout plan has
  pre-declared thresholds, that a postmortem has a human `Reviewed by`, or
  that an error-budget consequence table exists before release proceeds.
  Only `record-fields-gate.sh` (core, global) checks the role's own
  `docs/issue-<n>/reports/release-engineering.md` §20 fields — it says
  nothing about `ops/rollout-plan.md`, `ops/postmortem-*.md`, or
  `ops/error-budget-policy.md` content. This is the gap issue #27 (d) asks
  to close.

