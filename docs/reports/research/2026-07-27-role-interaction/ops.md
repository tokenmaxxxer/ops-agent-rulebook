# When and how a release/operations practitioner brings in another human

This extends `docs/reports/research/2026-07-27-role-practice/ops.md` (PRR
checklists, SLOs, rollout mechanics, postmortem artifact shapes — not
restated here). This document is scoped to one question only: at which
recurring moment does the practitioner stop and hand something to another
human, what do they carry into that exchange, and what comes back — as
material for the `ops` role's human-in-the-loop transitions in
`idle/readiness/rollout/steady/incident`.

## Moments that call for a human

- **Go/no-go launch decision.** Trigger: a launch checklist (Google's
  Launch Coordination Checklist) is fully walked. Practitioner brings: the
  per-item pass/fail plus known risks. Who owns the call varies by source —
  Google's LCE role is described as a "nonpartisan advisor" and gatekeeper
  who signs off on launches judged "safe" and is obligated to flag corners
  cut for speed to business stakeholders, but the primary source itself does
  not spell out a single named decision authority or a formal meeting
  protocol beyond "Production Reviews" as consulting sessions
  (https://sre.google/sre-book/reliable-product-launches/). Leaves with:
  a recorded go/no-go and (if no-go) a list of blocking items.

- **PRR sign-off.** Trigger: PRR checklist compiled (see companion doc for
  its 7-dimension shape). Brings: the checklist with a verdict per item.
  Brought to: dev team leads plus the domain-expert reviewers who authored
  or consulted on the checklist (https://sre.google/sre-book/evolving-sre-engagement-model/).
  Leaves with: a recommendation folded into the launch go/no-go, not
  necessarily a separate authority.

- **Canary promotion to next stage.** Trigger: bake-time metrics compared
  to baseline at a rollout step. Who: this is the one moment in the whole
  set that is *not* reliably human — see "What proceeds without asking"
  below. Where a human is in the loop, they bring the metric comparison
  (error rate, p99 latency, a business metric) to whoever owns the release,
  and leave with a promote/hold/abort call
  (https://www.getunleash.io/blog/canary-release-vs-progressive-delivery).

- **Rollback decision — who may act without asking.** This is the most
  contested moment in the sources. PagerDuty's IC model gives the current
  Incident Commander final, unchallengeable authority over the decision
  (including rollback) while explicitly forbidding the IC from personally
  executing it — decision and execution are split roles
  (https://response.pagerduty.com/training/incident_commander/). Separately,
  operational-practice writing states organizations frequently discover
  their on-call engineers lack rollback permission and must escalate to a
  senior engineer, costing 15–20 minutes per incident, and argues on-call
  should be pre-authorized to roll back without asking; the same source
  notes deployment platforms with `requireApproval` gates still force an
  approval step even for emergency rollbacks unless explicitly configured
  otherwise (search synthesis, no single canonical URL — see Sources; this
  claim's home page could not be individually verified further and is
  flagged `[unsourced]` for the specific 15–20 minute figure's origin).

- **Declaring an incident and choosing severity.** Trigger: a symptom or
  alert. Who declares: at PostHog, literally anyone in the org, via a
  Slack command, with an explicit instruction to raise even when uncertain
  (https://posthog.com/handbook/engineering/operations/incidents). Severity:
  PagerDuty ties tiers to impact scope, with anything above SEV-3
  automatically a "major incident," and explicitly does not name a single
  severity-decider — instead prescribing a default rule for ambiguity (see
  next section) (https://response.pagerduty.com/before/severity_levels/).
  The declarer brings whatever symptom/alert triggered it and leaves with
  an open incident record and initial severity label, revisable as
  information arrives.

- **Appointing an Incident Commander.** Trigger: incident declared.
  PagerDuty: any trained person may self-appoint as IC by announcing on the
  call if no on-call IC is present yet; command transfers to the on-call IC
  at that IC's own discretion when they arrive
  (https://response.pagerduty.com/training/incident_commander/). No
  technical-seniority requirement — communication skill and incident
  experience matter more than rank (same source).

- **Deciding to page someone.** PagerDuty ties this to severity: SEV-2 and
  above are "major incidents" needing coordinated response, and the
  guidance explicitly extends paging/full incident process to lower-severity
  issues too if coordinated response is needed regardless of the numeric
  tier (https://response.pagerduty.com/before/severity_levels/). The
  practitioner brings the alert/symptom and severity judgment; the person
  paged brings back availability/ack.

- **Calling an incident resolved.** No source located that names a specific
  resolution-authority role distinct from the IC; by extension of the IC's
  described "final decisions" authority (https://response.pagerduty.com/training/incident_commander/)
  this is presumed IC-owned but is not stated as a separate explicit rule in
  any fetched source — `[unsourced]` as a standalone claim.

- **Postmortem review meeting and action-item sign-off.** Trigger: draft
  postmortem written. Brought to: "a group of senior engineers" who assess
  the draft for completeness against five stated criteria — was incident
  data captured, is impact assessment complete, was root cause dug deep
  enough, is the action plan/priority appropriate, and were stakeholders
  informed (https://sre.google/sre-book/postmortem-culture/). The source
  states the postmortem is finalized once "those involved are satisfied
  with the document and its action items" and recommends regular review
  sessions to close discussions out — but it does not name a single
  sign-off authority or required attendee role beyond "senior engineers,"
  which is itself a gap in the primary source, not an omission of this
  research. PagerDuty separately requires each action item to carry one
  named individual owner, since team-owned items are the most common
  silent failure mode (https://response.pagerduty.com/after/post_mortem_process/,
  restated from companion doc for this specific human-owner claim).

- **Error budget exhaustion — spend or freeze.** Trigger: trailing-window
  error budget hits zero. Google's workbook uses passive/policy language
  ("we will halt all changes") rather than naming a decision-maker for the
  freeze trigger itself, but *does* name an explicit escalation path for
  disagreement: disputes over the error-budget calculation or the actions
  it mandates go to the CTO to decide (https://sre.google/workbook/error-budget-policy/).
  Exceptions (infra-wide outage, another team's fault, out-of-scope users,
  miscategorization) and the P0/security-fix carve-out are pre-agreed in
  the policy document itself, so most cases need no live human call — only
  disputed edge cases escalate.

## The shape of the exchange

- **Go/no-go and PRR**: described as review/consulting sessions ("Production
  Reviews") rather than a single scripted meeting format; the primary
  source gives no duration or artifact-size norm
  (https://sre.google/sre-book/reliable-product-launches/). Asynchronous
  checklist walk-through appears to be the default mode, with a live
  meeting reserved for contested items — this is an inference from the
  "advisor/consulting" framing, not a directly stated norm, so treat the
  sync/async split here as `[unsourced]` beyond the checklist mechanism
  itself.

- **PRR sign-off**: a checklist document with verdicts, not a meeting per
  se — consultation with dev/domain teams happens during authoring, before
  the checklist is presented (https://sre.google/sre-book/evolving-sre-engagement-model/).
  Recorded as the checklist artifact itself.

- **Canary promotion**: where human, this is a per-step check against a
  dashboard/metric query, not a meeting — Kayenta's score bands (pass ≥ 90,
  marginal ≥ 75) and Flagger's threshold counters are designed to be read
  in seconds, feeding a promote/hold/abort call
  (https://argo-rollouts.readthedocs.io/en/stable/analysis/kayenta/,
  restated from companion doc). Fully asynchronous by default in tooling
  that automates it (see below).

- **Rollback decision**: happens on the live incident call, verbally, and
  is meant to be near-instant — the IC model's entire point is to avoid
  the 15–20 minute escalation-approval delay described in the on-call
  rollback-authority discussion (search synthesis above). This is a live,
  synchronous decision, not a document.

- **Incident declaration and paging**: a single Slack command or page
  trigger — effectively zero material required, deliberately, so that
  raising "when in doubt" carries no cost (https://posthog.com/handbook/engineering/operations/incidents,
  https://response.pagerduty.com/before/severity_levels/). Fully
  asynchronous to initiate; what follows (the incident call) is synchronous.

- **IC appointment**: a verbal self-announcement on the incident call, not
  a document or vote (https://response.pagerduty.com/training/incident_commander/).

- **Incident channel/call**: the live incident timeline is built in real
  time during the call/channel by responders, and is the factual record
  the postmortem draws from afterward (https://response.pagerduty.com/after/post_mortem_process/,
  restated from companion doc). This is the one artifact explicitly
  described as assembled live, synchronously, rather than after the fact.

- **Postmortem review**: an internal draft is shared, senior engineers
  review it against the five criteria above, and — per Google's practice —
  regular scheduled review sessions exist to close discussion and finalize
  it (https://sre.google/sre-book/postmortem-culture/). This is described
  as review-then-finalize, which reads as substantially asynchronous
  (draft circulated, comments collected) with a scheduled session to close
  out remaining disagreement, though the source does not state review
  duration or format explicitly enough to call this more than an inference.

- **Error budget freeze**: the freeze itself requires no live exchange —
  it is a policy-triggered, near-automatic halt. Only genuine disputes
  about the calculation or its consequences escalate to a live decision,
  and that escalation path is pre-named (the CTO)
  (https://sre.google/workbook/error-budget-policy/).

## When the answer is ambiguous

- **Severity unclear → round up, not stall.** Multiple independent sources
  converge on the same default: when unsure whether an incident is SEV-1 or
  SEV-2, treat it as the higher severity; it is cheaper to downgrade later
  than to under-react (Datadog and other practitioner guides, synthesized
  via search — https://www.datadoghq.com/blog/how-datadog-manages-incidents/
  cited among the converging sources; exact phrasing varies by org and
  several instances could not be individually re-fetched, so treat the
  specific wording as approximate, the *convergent pattern* as the sourced
  claim).

- **Unsure whether to raise an incident at all → raise it anyway.**
  PostHog's handbook states this as an explicit organizational norm:
  "Anyone can declare an incident and, when in doubt, you should always
  raise an incident" (https://posthog.com/handbook/engineering/operations/incidents).
  This directly answers the core design question for an agent: the
  practitioner is never expected to sit and evaluate whether something
  "really" qualifies — ambiguity resolves toward declaring, not toward
  waiting.

- **No on-call IC present → self-appointment, not stalling.** PagerDuty's
  model: any trained person may declare themselves IC by announcing it on
  the call if the on-call IC has not shown up; there is no described
  "wait until the right person arrives" state
  (https://response.pagerduty.com/training/incident_commander/).

- **Decider unreachable for rollback → pre-delegated authority is the fix,
  not escalation.** The practitioner literature frames on-call lacking
  rollback authority as a *defect* to remove, not a normal state to route
  around — the fix cited is pre-authorizing on-call to roll back without
  asking, precisely so an unreachable approver never blocks the decision
  (search synthesis on rollback authorization, no single stable URL
  captured — flagged `[unsourced]` for provenance, though the pattern
  recurs across the sources surveyed).

- **Executive tries to override the IC mid-incident.** PagerDuty's guidance
  handles this directly rather than treating it as ambiguous: the IC can
  challenge the override by asking "do you wish to take over command?" —
  if the executive declines, the IC's decision stands and can be enforced
  (https://response.pagerduty.com/training/incident_commander/). This is a
  named break-glass-adjacent rule for authority conflict, not a gap.

- **Error budget dispute** (is it really exhausted, does an exception
  apply): explicitly escalates to a single named role, the CTO, rather
  than sitting unresolved (https://sre.google/workbook/error-budget-policy/).

- **Genuine gaps found**: no source specified what happens when *no one*
  answers a page at all (paging escalation chains/timeouts exist in
  PagerDuty's product but were not confirmed in the fetched documentation
  pages — `[unsourced]`), nor a canonical rule for who calls an incident
  formally "resolved" as distinct from the IC's general authority
  (`[unsourced]`, noted above).

## What proceeds without asking

- **Automated canary rollback on metric breach.** Argo Rollouts: if a
  tracked AnalysisTemplate metric fails its threshold (example cited: below
  95% across 3 consecutive measurements), the controller aborts the
  rollout and resets canary weight to zero with no human in the loop for
  that specific decision (https://argo-rollouts.readthedocs.io/en/stable/analysis/kayenta/,
  restated from companion doc since it is the load-bearing automation
  claim for this document too). Flagger's default loop is built the same
  way: `threshold` failed checks trigger automatic rollback
  (https://www.getunleash.io/blog/canary-release-vs-progressive-delivery).
  This is squarely attributed to the deployment-controller tooling (Argo,
  Flagger, Spinnaker/Kayenta), not to a specific named organization's
  policy choice — practice varies by whether a team wires the controller's
  auto-abort on or leaves promotion manual.

- **Force-merge / break-glass without asking.** PostHog: any employee may
  force-merge a PR in exceptional circumstances, fully audited via Slack
  notification and a PR comment, with the postmortem expected to account
  for it afterward — no pre-approval step (https://posthog.com/handbook/engineering/operations/incidents).
  This is one organization's stated policy, not a general industry norm;
  it is presented here as evidence that break-glass authority is real
  practice at at least one company, not that it is universal.

- **Error budget freeze enforcement for ordinary cases.** Once policy is
  written (SLO, window, consequence table, exception list), the halt
  itself needs no per-incident human sign-off — only disputes escalate
  (https://sre.google/workbook/error-budget-policy/). This is closer to
  "pre-approved automatic consequence" than "unattended automation," since
  a human still authored the policy and watches the dashboard, but the
  in-the-moment gating decision is mechanical.

- **What is *not* found automated in any fetched source**: incident
  declaration itself, IC appointment, the rollback decision during an
  active incident (as opposed to canary auto-abort pre-incident), and
  postmortem sign-off. No source claimed any of these are or should be
  automated; PagerDuty's IC model is built explicitly around a human
  decision-maker who is barred from doing execution work personally
  (https://response.pagerduty.com/training/incident_commander/), which is
  the opposite of removing the human.

## Draft `user`-actor transitions

The following is this document's own synthesis for the `ops` role's
`idle/readiness/rollout/steady/incident` state machine — not a sourced
fact, and marked as such throughout. Format: `from | to | actor |
precondition`.

| from | to | actor | precondition |
|---|---|---|---|
| idle | readiness | agent | PRR checklist compiled by agent; readiness review can be assembled and iterated on without a human present, per the async "review/consulting" framing above |
| readiness | rollout | user | go/no-go launch decision — sources leave the exact authority unnamed at Google, but every source that touches this moment (LCE sign-off, PRR review) treats it as a human call, never a mechanical one; no source shows a launch auto-proceeding off a checklist |
| rollout | rollout (promote step) | agent | canary step promotion when the metric/threshold check is clean — Argo/Flagger/Kayenta auto-promote-or-abort loops are explicitly built for this and are real production practice, so this can be agent-owned *when thresholds are pre-defined and unambiguous* |
| rollout | incident | agent | canary metric breach past a hard pre-set threshold — sourced as automatic in mature tooling (Argo Rollouts, Flagger); agent may declare here mirroring "when in doubt, raise it anyway" from PostHog, since raising costs nothing and understating costs more |
| rollout | steady | agent | successful full rollout with all steps passed against pre-set thresholds — mechanical completion, no source treats this as a human gate distinct from the per-step checks already passed |
| steady | incident | agent | alert/symptom crosses a pre-set severity trigger — PostHog and PagerDuty both treat *raising* as costless and encourage anyone (or anything) to do it on ambiguity, so an agent declaring here is consistent with sourced practice, PROVIDED the severity is provisional and revisable, not a final human-equivalent judgment |
| incident | incident (IC/rollback decision) | user | rollback, IC appointment, severity escalation disputes, and incident-resolved calls are consistently the moments sources put a human in sole authority (PagerDuty's IC model, the CTO-escalation for error-budget disputes) — this is the one transition this document argues most strongly must stay `user`, not `agent`, specifically because sources describe deliberate decision/execution separation and unchallengeable human final say |
| incident | steady | user | declaring resolution — no direct source names this explicitly, but it inherits from the same IC final-authority framing; treated here as human by extension, flagged as the weakest-sourced entry in this table |
| incident | readiness | user | postmortem action-item sign-off gates any re-entry into a release cycle for the affected surface — Google's postmortem review requires senior-engineer satisfaction with the document and its action items before it is considered closed, which this table reads as a human gate on resuming readiness work |

On the repo's existing question of whether `ops`'s bootstrap entry into
`idle` should be stricter (`user`) than sibling roles' `agent` entry: the
sources gathered here say nothing about role bootstrap/entry at all — every
human-authority claim found is about in-flight decisions (launch, rollback,
severity, postmortem sign-off), not about starting the state machine. This
document cannot support tightening or loosening the `idle` bootstrap actor
either way from ops-specific evidence; the strictness argument for `ops`
lives entirely in the incident/rollback/error-budget-dispute transitions
above, not in bootstrap. No missing state was required beyond the five
given; the ambiguity in "resolved" and "no answer to a page" reflects gaps
in the sourced practitioner literature itself, not a missing state in this
model.

## Sources

- https://sre.google/sre-book/evolving-sre-engagement-model/
- https://sre.google/sre-book/reliable-product-launches/
- https://sre.google/sre-book/postmortem-culture/
- https://sre.google/workbook/error-budget-policy/
- https://response.pagerduty.com/training/incident_commander/
- https://response.pagerduty.com/before/severity_levels/
- https://response.pagerduty.com/after/post_mortem_process/
- https://posthog.com/handbook/engineering/operations/incidents
- https://www.getunleash.io/blog/canary-release-vs-progressive-delivery
- https://argo-rollouts.readthedocs.io/en/stable/analysis/kayenta/
- https://www.datadoghq.com/blog/how-datadog-manages-incidents/
