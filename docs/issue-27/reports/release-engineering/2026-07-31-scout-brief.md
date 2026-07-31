---
kind: scout-brief
issue: 27
role: release-engineering
---

# Scout brief — issue 27

Mode: parallel WebSearch fan-out, 4 angles, one round; 1 deepening round (2 stages
total, well under the 5-stage/3min budget — saturation reached: a 3rd round would
not change the adopted set below).

## Angles run

1. Release-plan / release-engineering practice (Google SRE Release Engineering
   chapter).
2. Production readiness review (PRR) checklist norms.
3. Canary rollout + error-budget-policy standard components.
4. Change-management proposal norms (ITIL RFC vs. DevOps change enablement).
5. (deepening) Blameless postmortem required fields (Google SRE postmortem
   culture + example postmortem).

## Must-bes (category, convergent across sources)

- **Numeric, pre-declared success criteria** — not "monitoring exists" but a
  named metric + threshold, checked before rollout starts, not invented
  mid-rollout (canary/error-budget sources).
- **Explicit rollback / back-out path** stated in the plan itself (ITIL RFC;
  canary automated-rollback pattern).
- **Readiness resolves to yes/no per dimension with a pointable artifact**
  (PRR sources) — a checklist item with no linkable evidence is a fail, not a
  "yes with caveats."
- **Error budget gates release cadence** — a released feature past its error
  budget halts further release regardless of readiness (Google SRE canary +
  error-budget sources).
- **Blameless postmortem with a fixed section set** — what happened, impact,
  root cause, and action items with owners — reviewed by a human, not just
  filed (Google SRE postmortem-culture).
- **RFC-shaped change record**: requester, scope/impact, risk, timeline,
  back-out strategy (ITIL RFC template) — this is the *proposal*-side
  discipline, distinct from the *rollout*-side canary discipline.

## Performance axes strong sources compete on

1. **Threshold pre-commitment vs. live judgment** — Google SRE canary
   explicitly forbids inventing thresholds mid-rollout; weaker (ITIL-only)
   sources leave pass/fail to reviewer discretion at each gate.
2. **Automation of rollback vs. manual sign-off** — SRE sources favor
   automatic reversal on SLO breach; ITIL sources assume a human executes the
   back-out plan. For an AI role bound by a directive (not live ops access),
   the adoptable form is "pre-declared automatic thresholds the role must
   obey," not "the role has automated rollback hardware."
3. **Root-cause depth in postmortems** — SRE sources treat postmortems as
   trend-analysis input (systemic root-cause classification), not just
   incident narrative.

## Adopt / skip

- **Adopt**: numeric pre-declared per-step thresholds (pass/fail/inconclusive)
  for the phase-2 rollout plan; PRR-style yes/no-with-artifact readiness
  checklist for the phase-1 current-state survey; error-budget gate on
  release proceeding; human-reviewed blameless postmortem for incidents.
- **Skip**: full ITIL RFC apparatus (change-ID numbering, CAB approval
  board, formal change-priority taxonomy) — this repo's role-handoff
  contract already supplies the approval mechanism (human Approve / APPROVE
  string) and issue-numbered identity; re-importing ITIL's own governance
  layer on top would duplicate contract v3's approval gate, not strengthen
  it.
- **Skip**: PPAP-style manufacturing certification apparatus (surfaced by
  the PRR search as an analogy, not a software-release norm) — no software
  source treated it as applicable.

## Gap line (current state vs. field must-bes)

This repo's existing `ops/hooks/directive.sh` (docs/issue-27/reports/release-engineering/2026-07-31-current-state-survey.md
has the full read) already names: numeric error-budget gating, PRR-shaped
seven-dimension readiness, pre-declared per-step thresholds, and a
human-reviewed postmortem requirement — i.e. the *methodology* the field
converges on is already present in prose form in `USE_WHEN`/`PRODUCES`/
`HAND_OFF`. What is **missing** is (a) a named, citable methodology label for
phase 1's own proposal document (the proposal itself has no required-section
or evidence-format norm — contrast the RFC's requester/scope/risk/timeline/
back-out shape), and (b) enforcement: none of the above readiness/threshold/
error-budget/postmortem requirements are gated by a script the way
`record-fields-gate.sh` gates the record's own §20 fields — they exist only
as directive prose the role can read but nothing checks it followed. The
proposal below closes both gaps.

## Sources

- https://sre.google/sre-book/release-engineering/
- https://sre.google/workbook/canarying-releases/
- https://www.cortex.io/post/how-to-create-a-great-production-readiness-checklist
- https://getdx.com/blog/production-readiness-checklist/
- https://fastercapital.com/content/Error-Budget--Error-Budget--Calculating-Risk-in-Canary-Testing.html
- https://www.givainc.com/blog/what-is-request-for-change-example-of-rfc-form-template/
- https://wiki.en.it-processmaps.com/index.php/Change_Management
- https://sre.google/sre-book/postmortem-culture/
- https://sre.google/sre-book/example-postmortem/
