---
name: issue-27-rulebook-maturation
subject: issue-27
role: release-engineering
status: proposed
---

# Proposal — release-engineering rulebook maturation (phase 1)

Scout brief: `docs/issue-27/reports/release-engineering/2026-07-31-scout-brief.md`.
Current-state survey: `docs/issue-27/reports/release-engineering/2026-07-31-current-state-survey.md`.

## Summary

The survey's headline finding: this repo's existing phase-2 skills
(`error-budget-policy`, `readiness-checklist`, `rollout-plan`, `postmortem`)
already match the field's converged practice closely (Google SRE release
engineering / canarying / postmortem-culture chapters; PRR industry
consensus) — confirmed, not invented, by the scout brief. What is genuinely
missing is (a) a named, citable methodology for the *phase-1 proposal
document itself*, which has no norm today beyond contract v3's generic
shape, and (d) mechanical enforcement that phase-2 outputs actually contain
the elements the skills already describe in prose. This proposal adopts (a)
and (d), and confirms (b)/(c) rather than replacing them.

## (a) Phase-1 proposal norm — methodology, required sections, evidence format

**Adopted methodology: RFC-shaped change proposal** (ITIL Request-for-Change
core fields, minus ITIL's own governance apparatus — see rationale).

Every release-engineering proposal (`docs/issue-<n>/proposals/*.md`) must
contain these sections, in addition to whatever the scout/survey protocol
already requires of phase 1 generally:

1. **Scope / change description** — what is changing, in one paragraph.
2. **Risk** — what could go wrong if this proposal is wrong, stated
   concretely (not "risks exist" — name the failure mode).
3. **Rollback / back-out path** — how a wrong decision here gets undone,
   even at proposal-review time (e.g. "revert this PR" is a valid answer,
   but it must be stated, not assumed).
4. **Evidence format**: every adopted methodology claim cites its source
   inline (URL or repo path) — no unsourced "best practice" assertions.
   This mirrors the scout-directive's own `Sources:` rule, applied
   permanently to this role's proposals, not just to the one-time scout
   pass that produced this document.

Rationale for RFC-shaped minus governance: the scout brief's adopt/skip
call — ITIL's requester/scope/risk/timeline/back-out shape is the one
piece of the RFC norm with no equivalent already in contract v3, so it adds
signal; ITIL's change-ID numbering and CAB approval-board apparatus
duplicates machinery contract v3 already supplies (issue-numbered
identity, the two-path human Approve gate) and would fight it rather than
strengthen it if imported wholesale.

## (b) Phase-2 deliverable norm — methodology, required components

**Adopted methodology: confirmed as-is.** The four existing skills already
encode the field's converged practice:

- `error-budget-policy`: per-SLI measurement method, SLO target, window,
  consequence table (Google SRE error-budget-policy shape).
- `readiness-checklist`: seven-dimension PRR, yes/no + pointable artifact
  per item (industry-convergent PRR shape).
- `rollout-plan`: traffic curve, bake time, metric queries, pre-declared
  per-step pass/fail/inconclusive thresholds (canary/progressive-delivery
  convergent shape — Kayenta/Flagger/Argo Rollouts pattern).
- `postmortem`: Google's trigger criteria, four required sections, named
  human review before incident close.

No content change to these four skills. What phase 2 adds is enforcement
(see (d)) — the methodology itself does not need to change because the
scout sweep found no source describing a materially different or stronger
shape for any of these four artifacts.

## (c) Rationale for each adoption

| Adopted element | Why it must fit this role's value, not just "a" methodology |
|---|---|
| RFC-shaped proposal sections | The role's own `YOU_DECIDE` (directive.sh) is "whether a change may ship" gated by "measurable reliability rather than discretionary sign-off" — a proposal that omits risk/rollback is asking for discretionary sign-off on exactly the axis the role exists to remove. |
| Sourced-evidence-only claims | The role explicitly "does not invent what healthy means" (directive.sh) — an unsourced methodology claim in its own proposal would be the role inventing its own practice the same way it is forbidden from inventing SLO targets. |
| Confirm existing PRR/canary/postmortem shapes | The role's HAND_OFF already states the "we have monitoring with nothing to link is a FAIL" bar and "postmortem satisfied only by human-reviewed" — these are word-for-word the PRR/postmortem-culture must-bes the scout brief found; changing them would contradict the role's own stated quality bar rather than raise it. |
| Mechanical enforcement over prose-only | `record-fields-gate.sh` already proves the pattern works for the record file (§20 fields checked, not just described); the same class of skipped-field failure ("we have monitoring" with an empty artifact field) is exactly what a gate catches that a directive's prose cannot. |

## (d) Plugin reflection plan — directive / record fields / gates

Phase 2 (after Approve) will:

1. **`ops/hooks/directive.sh`** — extend the `PRODUCES` string (phase 1)
   to name the RFC-shaped proposal sections from (a) explicitly, so the
   directive itself states the requirement rather than only this proposal
   document. No change to `YOU_DECIDE`/`USE_WHEN`/`HAND_OFF` — those
   already state the phase-2 bar correctly per (c) above.
2. **New gate: `ops/hooks/proposal-fields-gate.sh`** (PreToolUse, same
   shape/fail-closed discipline as core's `record-fields-gate.sh`) — on a
   write to this role's own `docs/issue-<n>/proposals/*.md`, require the
   four (a) sections (Scope, Risk, Rollback, and at least one inline
   source citation) present, deny otherwise. Registered in
   `ops/hooks/hooks.json` alongside `directive.sh`.
3. **New gate: `ops/hooks/rollout-plan-fields-gate.sh`** (PreToolUse) — on
   a write to `ops/rollout-plan.md`, require every step block to carry a
   non-empty `threshold:` field per metric before it can be written with
   `result: pass` or `result: fail` — a step must not be marked resolved
   with an unset threshold, closing the "invent a threshold mid-rollout"
   failure mode the scout brief flagged as the field's core discipline.
4. **Postmortem review field**: no new gate needed — `postmortem-template.md`
   already has the `Reviewed by` / `Reviewer satisfied` fields; the
   existing `incident -> steady` human-turn requirement (readiness-checklist
   SKILL.md) already covers this. Confirmed, not changed.
5. **Record file** (`docs/issue-<n>/reports/release-engineering.md`): no
   new required field beyond core's existing §20 set — issue #27 does not
   ask for a record-format change, and the survey found no gap there.
6. **Dangling state-machine references** (survey finding): `state-gate.sh`,
   `docs/specs/state-machine.md`, `transition-rules.md` referenced by the
   skills but absent from this repo. Out of scope for issue #27 — flagged
   here so phase 2 does not attempt to build gates against files this issue
   never asked for; a future issue should either restore or retire those
   references.

## Out of scope

- Any change to the four skills' existing methodology content (confirmed
  correct, not touched).
- Building or wiring the two new gates, or the directive edit — phase 2
  only, after human Approve.
- Reconciling the dangling state-machine references — separate issue.
- warrant-hunter / core-canon copying — this repo has no warrant-hunter
  copy (confirmed by issue-28's survey); nothing here duplicates canon.

Phase 1 stops here: proposal only, no APPROVE, no execution work.
