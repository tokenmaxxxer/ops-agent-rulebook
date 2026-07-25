# What release/operations work actually looks like, at work-product granularity

This extends `docs/reports/research/2026-07-25-swpd-roles/release-ops-sre.md`
(role boundaries, gates, DORA figures — not restated) down to the concrete
artifacts and field lists the `ops` role's skills and state file would need to
produce, per `docs/specs/agent-roles.md`'s `idle/readiness/rollout/steady/incident`
state machine.

## What the work actually is

- **Production readiness review (PRR).** A structured assessment, run before
  a service takes production traffic (or before a major launch), that a
  service is architecturally and operationally sound. Google's process:
  authors are selected, they consult dev teams and domain-expert teams,
  compile findings into a service-specific checklist, then iterate on it —
  there is no single fixed Google template published externally; each PRR
  checklist is assembled per-service from a Production Guide plus domain
  expertise (https://sre.google/sre-book/evolving-sre-engagement-model/,
  https://landing.google.com/sre/sre-book/chapters/part4/). An independently
  published open-source checklist converges on seven review dimensions:
  Service Levels, Architecture Design Review, Performance, Documentation,
  Observability, Testing, and Deployment Strategy
  (https://getdx.com/blog/production-readiness-checklist/). Google's practice
  moved over time from a late "Simple PRR" (done only once a service is
  already near launch) toward an "Early Engagement Model" that pulls SRE
  review earlier in design, because retrofitting reliability late is more
  expensive than designing for it
  (https://sre.google/sre-book/evolving-sre-engagement-model/). Produces: a
  checklist with a verdict per item and an overall go/no-go recommendation to
  the launch decision-maker (LCE at Google). Cadence: once per
  service-before-GA, not periodic — though the "Continuous Production
  Readiness Review" pattern argues for re-running it periodically against a
  live service rather than treating it as a one-time gate
  (https://josvisser.substack.com/p/the-continuous-production-readiness).

- **Launch checklist.** Google's original Launch Coordination Checklist
  (circa 2005) is the artifact an LCE and the launching team walk together;
  narrower than a full PRR, oriented at "is this specific launch event safe"
  (capacity, monitoring, rollback, dependencies) rather than "is this service
  well-architected" (https://sre.google/sre-book/launch-checklist/). Produces:
  a per-item pass/fail plus the go/no-go call. LCEs hold real authority to
  slow or block a launch and are obligated to tell business stakeholders when
  corners are cut for speed (https://sre.google/sre-book/reliable-product-launches/).

- **Progressive rollout (canary / staged deploy).** The mechanical practice:
  route a small percentage of traffic to the new version, hold it for a bake
  time, compare metrics against the stable baseline, then step up traffic or
  abort. Flagger's default canary loop: an `interval` (default 60s) between
  steps, a `stepWeight` traffic increment per step, a `maxWeight` ceiling, and
  a `threshold` — the number of failed metric checks tolerated before an
  automatic rollback (https://www.getunleash.io/blog/canary-release-vs-progressive-delivery,
  Argo Rollouts docs at https://argo-rollouts.readthedocs.io/en/stable/features/canary/).
  Argo Rollouts' AnalysisTemplate mechanism: if a tracked metric query fails
  its threshold (example cited: metric below 95% across three consecutive
  measurements → Failed), the rollout controller aborts automatically and
  resets canary weight to zero, with no human in the loop for that decision
  (https://argo-rollouts.readthedocs.io/en/stable/analysis/kayenta/). Kayenta
  (Spinnaker's canary analysis engine) config uses `pass`/`marginal` score
  thresholds (example cited: pass ≥ 90, marginal ≥ 75) computed by comparing
  canary vs. control cohorts, not by comparing to a fixed absolute number
  (https://argo-rollouts.readthedocs.io/en/stable/analysis/kayenta/). Produces:
  a rollout plan naming the traffic curve and the metrics/thresholds that
  gate each step, and, per step, a promote/hold/abort decision.

- **SLO definition and SLI selection.** Deriving a small set of
  Service Level Indicators (request latency, error rate, availability, etc.)
  and setting a target (an SLO, e.g. 99.9% over a rolling window) against
  them. Owned nominally by product/business setting the target, operationalized
  by SRE (https://sre.google/workbook/implementing-slos/). Produces: an SLO
  document naming each SLI's measurement method, the target percentage, and
  the measurement window.

- **Error budget accounting.** The complement of the SLO — `1 - SLO` over the
  same trailing window is the error budget, spent by failures. Google's
  stated policy shape: within budget, releases proceed at normal velocity;
  once the trailing-window budget is exhausted, only P0/security-fix releases
  are allowed until the service is back within budget
  (https://sre.google/workbook/error-budget-policy/). This is described as
  the actual handoff contract between release and on-call/steady-state
  operation — not committee-mediated, metric-triggered instead
  (release-ops-sre.md).

- **On-call handoff.** Structural practice widely followed (rotation
  schedules, a handoff note listing open incidents, recent alerts, and known
  flaky signals) but no canonical published content template was located —
  marked `[unsourced]` for field-level shape; PagerDuty's operational
  documentation describes the on-call engineer's function (triage, mitigate,
  escalate to IC) without publishing a handoff-note schema
  (https://www.pagerduty.com/resources/digital-operations/learn/incident-response-lifecycle-for-devops/).

- **Incident command.** Once an incident is declared, an Incident Commander
  (IC) is either the on-call engineer or someone who takes over, and makes
  decisions (including whether to roll back) without personally executing
  remediation — decision and execution are deliberately split
  (https://response.pagerduty.com/training/incident_commander/). Produces:
  a live incident timeline (see Artifacts) plus the eventual decision to
  resolve.

- **Blameless postmortem.** Written after an incident meeting Google's
  stated trigger criteria (below). Produces: a document assuming good faith
  of all participants, covering impact, actions taken during response, root
  cause(s), and prevention action items
  (https://sre.google/sre-book/postmortem-culture/,
  https://response.pagerduty.com/after/post_mortem_process/). Cadence: no
  fixed cadence — triggered per qualifying incident, not periodic; Google
  notes only that "a large number" are produced per month across the org
  without prescribing a rate (https://sre.google/sre-book/postmortem-culture/).

## Artifacts and their shapes

- **PRR checklist** — no single Google-published field list; the converged
  independent 7-dimension shape (source above) gives a usable canonical
  structure: Service Levels (SLO/SLI defined?), Architecture Design Review,
  Performance (load-tested?), Documentation (runbook exists?), Observability
  (dashboards/alerts exist?), Testing (failure-injection done?), Deployment
  Strategy (rollback path defined?). `launch-readiness`'s own rule — used
  already in this workspace's `ops` spec — is the operative field
  discipline: every item resolves yes/no, and every yes names a pointable
  artifact (a dashboard URL, a config key, a runbook path), never bare prose
  (agent-roles.md, citing the `launch-readiness` skill).

- **Runbook** — documented remediation steps for a known failure mode,
  written for someone acting under time pressure; the maturing practice is
  to encode these as executable workflows rather than static prose so they
  cannot silently drift from the system they describe
  (https://how2.sh/posts/how-to-set-up-incident-containment-runbooks-for-engineering-teams/).
  Minimal shape implied by that source: trigger condition (what alert/symptom
  invokes this runbook), diagnostic steps, remediation steps, escalation
  point if remediation fails.

- **SLO/SLI definition doc** — per Google's workbook: for each SLI, the
  measurement method (what raw signal, e.g. proportion of requests under a
  latency threshold), the SLO target value, and the measurement window
  (e.g. trailing 28 days) (https://sre.google/workbook/implementing-slos/).

- **Error budget policy doc** — per Google's workbook: the SLO/window it
  is computed from, and an explicit consequence table: within-budget →
  releases proceed normally; budget exhausted → all releases except
  P0/security-fix are halted until back within budget
  (https://sre.google/workbook/error-budget-policy/).

- **Rollout plan** — per-step traffic percentage, wait/bake time per step,
  the metric queries evaluated at each step, and the pass/fail/inconclusive
  threshold for each (Kayenta's `pass`/`marginal` score fields; Flagger's
  `interval`/`stepWeight`/`maxWeight`/`threshold` fields — both cited above).

- **Incident timeline** — a timestamped reconstruction built live by the
  IC/responders during response, the factual backbone the postmortem is
  written from afterward (https://response.pagerduty.com/after/post_mortem_process/).
  Minimal fields implied: timestamp, event/observation, actor, and (for
  decision points) what was decided and by whom.

- **Postmortem document** — Google's stated required-trigger criteria,
  fixed *before* an incident so there is no post-hoc argument about whether
  one is owed: user-visible downtime/degradation beyond a threshold, any
  data loss, on-call engineer intervention (rollback, traffic reroute, etc.),
  resolution time above a threshold, or a monitoring failure that meant the
  incident was discovered manually
  (https://sre.google/sre-book/postmortem-culture/). Required sections per
  the SRE-lineage template: impact (what broke, for whom, how long), actions
  taken during response, root cause(s), and prevention/follow-up action
  items with owners (https://sre.google/sre-book/postmortem-culture/,
  https://response.pagerduty.com/after/post_mortem_process/). PagerDuty's
  operational rule for the follow-up section specifically: each action item
  needs one named individual owner, not a team — an item owned by a team is
  reported as the single most common silent failure of the handoff
  (https://response.pagerduty.com/after/post_mortem_process/). Google's own
  practice note: "an unreviewed postmortem might as well never have
  existed" — a review step is part of the artifact's actual definition, not
  an optional polish pass (https://sre.google/sre-book/postmortem-culture/).

- **On-call handoff notes** — `[unsourced]`: widely practiced, no canonical
  published field list found. Reasonable inferred shape from adjacent
  sourced practice (open incidents, recent/flaky alerts, pending action
  items) is not itself sourced and should be flagged as such if encoded.

- **Change record** — the artifact an ITIL Change Advisory Board (CAB)
  historically reviewed before a production change; increasingly replaced
  by policy-as-code checks (automated test-coverage/security-scan gates)
  rather than a manual document in DevOps-native orgs
  (https://www.harness.io/blog/change-advisory-board-really-needed) — already
  covered in release-ops-sre.md, referenced here only because it is the
  artifact `ops`'s `readiness` state most directly supersedes.

## Decision criteria and gates

- **Ship / hold at readiness**: every PRR/launch-checklist item resolves
  yes/no with a pointable artifact on every "yes"
  (https://getdx.com/blog/production-readiness-checklist/, launch-readiness
  discipline cited above). Google's LCE holds explicit stop/slow authority
  over the launch as a whole (https://sre.google/sre-book/reliable-product-launches/).

- **Canary promote / abort during rollout**: metric-driven relative to the
  stable baseline, not an absolute number — request error rate, p99 latency,
  and at least one business metric are the commonly tracked triad
  (https://www.getunleash.io/blog/canary-release-vs-progressive-delivery).
  Concrete cited thresholds: Argo Rollouts example — 3 consecutive
  measurements below 95% on a tracked metric → automatic abort and traffic
  reset to zero (https://argo-rollouts.readthedocs.io/en/stable/analysis/kayenta/);
  Kayenta score bands — pass ≥ 90, marginal ≥ 75 (same source); a commonly
  cited informal rule elsewhere in industry discussion: roll back if the
  canary is roughly 50% worse than stable on any tracked metric
  (release-ops-sre.md, same claim carried forward here since it recurs in
  canary literature broadly).

- **Roll back during an incident**: decision authority sits with the IC, who
  decides but does not personally execute the remediation — a deliberate
  separation of decision from action (https://response.pagerduty.com/training/incident_commander/).

- **Declare an incident**: no single numeric trigger found universally;
  practice is severity-ladder-driven (below) plus Google's postmortem
  trigger list doubling as an implicit incident-declaration bar, since three
  of its five criteria (downtime beyond threshold, data loss, on-call
  intervention) are incident-defining events themselves
  (https://sre.google/sre-book/postmortem-culture/).

- **Severity ladder (SEV1–SEV5, most common shape)**: SEV1/Critical — core
  service down for all or most customers, on-call plus backup plus
  engineering lead paged, acknowledge target ~5 minutes, stakeholder updates
  every ~15 minutes; SEV2/Major — significant degradation but a workaround
  exists, on-call paged, acknowledge target ~15 minutes, updates every ~30
  minutes; SEV3/Minor — limited impact, handled via chat/email, response
  within the next business hour
  (https://runframe.io/blog/incident-severity-levels,
  https://firehydrant.com/blog/getting-started-with-severity-levels/). Some
  organizations extend to SEV0 (above SEV1, existential) and SEV4/SEV5 (cosmetic,
  no user impact) (https://www.xurrent.com/blog/incident-severity-levels).
  Stated best practice: "when in doubt, round up" — the cost of downgrading a
  SEV2 that turns out to be SEV3 is cheaper than discovering a "SEV3" was
  actually costing revenue for an hour (https://runframe.io/blog/incident-severity-levels).

- **Close an incident**: not resolved via a single numeric criterion across
  sources; practice converges on "service restored to declared SLO/normal
  behavior" plus, per this workspace's own `ops` spec, a filed postmortem as
  the gate on returning from `incident` to `steady` (agent-roles.md, itself
  grounded in release-ops-sre.md's error-budget framing) — treat the
  postmortem-required-before-close rule as this workspace's synthesis, not
  an independently sourced universal practice; Google's source only
  establishes when a postmortem is *owed*, not that closing waits on it.

- **Release gate on error budget**: automatic and metric-triggered — within
  budget, ship normally; budget spent over the trailing window, halt all
  releases except P0/security fixes
  (https://sre.google/workbook/error-budget-policy/). Contrasted directly
  against CAB-style human gates: multi-year data cited shows CAB/external
  approval correlates with worse lead time, deployment frequency, and MTTR
  with no measurable safety benefit, which is the empirical argument for
  preferring the automatic error-budget gate over a committee
  (https://www.harness.io/blog/change-advisory-board-really-needed — already
  in release-ops-sre.md, restated here because it is the direct contrast
  case for the gate this section is about).

## Failure modes

- **Alert fatigue.** Too many notifications, many false-positive or
  low-severity, desensitize responders; real incidents get delayed or
  ignored, response quality drops, burnout accelerates
  (https://runframe.io/blog/how-to-reduce-alert-fatigue). Countermeasure
  implied by the source: alert only on symptoms that matter (user-facing
  SLO burn) rather than every underlying cause signal.

- **Runbook rot.** If the same alert recurs weekly because nobody converted
  the root cause into either an automated fix or an updated runbook, the
  team burns cycles on an already-solved problem every time
  (https://medium.com/@michal.bojko.gdansk/failure-fatigue-is-killing-your-on-call-team-fight-back-with-runbook-as-code-04d8e72d5287).
  Countermeasure: "runbook as code" — encode remediation as executable
  workflows so drift from the live system is visible/testable rather than
  silent prose rot (same source, and
  https://how2.sh/posts/how-to-set-up-incident-containment-runbooks-for-engineering-teams/).

- **Postmortems with no follow-through.** The action-item list is where
  reliability improvement either compounds or doesn't; incident.io's stated
  finding: action items fail quietly, not loudly — the document gets read
  once in the postmortem meeting and never opened again
  (https://incident.io/blog/why-do-post-mortem-action-items-fail-how-to-make-incident-follow-ups-actually-get-done).
  Four specific failure patterns cited by that source: no individual owner
  ("the team should look into X" is not an assignment); wrong location (an
  item living only inside the postmortem doc is invisible to sprint
  planning); no verification criterion ("improve monitoring" isn't
  closeable because "improved" was never defined); and vague action items
  with no finish line that stay open forever (same source). Google's own
  parallel claim: "an unreviewed postmortem might as well never have
  existed" (https://sre.google/sre-book/postmortem-culture/).

- **Rollback that cannot actually roll back.** Not directly sourced with a
  named incident in this pass — flagged `[unsourced]` for a concrete
  citation — but implied structurally by the split between automated canary
  abort (works because the mechanism resets traffic weight programmatically,
  https://argo-rollouts.readthedocs.io/en/stable/analysis/kayenta/) and
  manual incident rollback authority sitting with a human IC
  (https://response.pagerduty.com/training/incident_commander/): a rollback
  path that exists only as a documented manual procedure, never exercised,
  is a plausible failure mode by the same rot logic as runbooks generally,
  but no source here directly names "rollback path bit-rotted and failed
  when needed" as a documented incident class.

- **SLOs nobody enforces.** Google's own framing of the error-budget policy
  as *the* enforcement mechanism implies the failure mode by contrast: an
  SLO with no attached budget-exhaustion consequence is a number nobody acts
  on (https://sre.google/workbook/error-budget-policy/) — this is an
  inference from the source's framing, not a directly stated failure case,
  flagged as such.

- **Hero culture / change freezes as a substitute for reliability.**
  Not independently sourced in this pass beyond the CAB-vs-automated-gate
  finding already in release-ops-sre.md (committee gates slow delivery with
  no safety benefit) — treating a manual freeze/committee as a reliability
  measure is the same failure mode that finding argues against, but no new
  primary source on "hero culture" specifically was located here.
  `[unsourced]` for a dedicated citation on hero culture as a named failure
  mode.

## Tooling and automation

- **Genuinely automated in mature practice**: canary metric evaluation and
  abort — Argo Rollouts/Flagger/Kayenta all execute the promote/hold/abort
  decision programmatically against pre-declared thresholds with no human
  in the loop for a *bad* result (abort is automatic); a *good* result
  still requires the declared step sequence to run to completion
  (https://argo-rollouts.readthedocs.io/en/stable/analysis/kayenta/,
  https://www.getunleash.io/blog/canary-release-vs-progressive-delivery).
  Error-budget-based release freezing is likewise designed as an automatic,
  metric-triggered gate rather than a discretionary one
  (https://sre.google/workbook/error-budget-policy/). Policy-as-code change
  validation (automated test-coverage/security-scan checks) is displacing
  manual CAB review for low-risk changes under ITIL 4's decentralized
  Change Authority model (https://www.harness.io/blog/change-advisory-board-really-needed,
  https://itsm.tools/change-enablement/ — both already in release-ops-sre.md).

- **Stays human**: declaring an incident in the first place (no source
  found describing a fully automatic incident-declaration trigger — alerts
  page a human who declares); the promotion from `rollout` to full/`steady`
  traffic at the end of a canary sequence, which in this workspace's own
  `ops` spec is explicitly gated on the user's own-turn approval
  (agent-roles.md); the IC's decision authority during an active incident,
  which PagerDuty's model keeps deliberately separate from whoever executes
  the fix (https://response.pagerduty.com/training/incident_commander/);
  closing an incident and filing/reviewing the postmortem (Google: "an
  unreviewed postmortem might as well never have existed" implies a human
  review step is part of closing, not just writing,
  https://sre.google/sre-book/postmortem-culture/).

## Candidates for rulebook encoding

*(Synthesis — this section is the author's own judgment, not sourced claims.)*

- **The five-state cycle (`idle/readiness/rollout/steady/incident`) covers
  the shape found here, with one gap.** Everything sourced above maps onto
  it: `readiness` = PRR/launch checklist, `rollout` = canary/progressive
  delivery loop, `steady` = SLO/error-budget accounting, `incident` =
  IC/timeline/postmortem. The gap: nothing in the five states names the
  *SLO/error-budget definition* step itself as a distinct activity — the
  current spec has `ops` "consume" the measurement design from `feasibility`
  rather than define it. That is a deliberate design choice already made in
  `agent-roles.md` (ops does not invent what "healthy" means), so it is not
  a defect to fix, just worth flagging as the reason error-budget policy
  content lives inside `steady`'s refusal rule rather than its own state.

- **What the `readiness` gate must actually check, concretely, if built as
  a skill**: the 7-dimension shape (Service Levels/SLO, Architecture,
  Performance, Documentation, Observability, Testing, Deployment Strategy)
  is a reasonable checklist skeleton to hard-code as the skill's item list,
  each item requiring a yes/no plus a pointer field, per the
  `launch-readiness` discipline already cited in the spec. This is directly
  buildable from sourced material with no further research needed.

- **Rollout-step gates are the strongest candidate for an *agent* decision
  rather than a human one.** The abort side of canary promotion (metric
  below threshold → abort) is, in mature tooling, already fully
  programmatic with no human step — an `ops`-agent implementation could
  legitimately make this call itself by evaluating the declared threshold
  against a fetched metric, rather than escalating to the user. The
  *promote-to-`steady`* side is different: the spec already requires a
  user's own-turn approval there, matching sourced practice that traffic
  cutover to 100%/production is a human call even when the tooling that
  gets it *to* the last canary step is automatic.

- **Incident declaration and incident close are the two transitions that
  most clearly want to stay human**, per the Tooling section above: no
  sourced practice auto-declares an incident, and Google's "unreviewed
  postmortem might as well never have existed" implies close requires a
  human review step, not just a filled-in template — a candidate directive
  for an `ops-agent-rulebook` gate: `incident -> steady` should require not
  just "a postmortem file exists" (mechanically checkable) but a
  human-asserted "reviewed" marker, mirroring `qa-cycle`'s single-use
  verdict-token pattern already used elsewhere in this org's rulebooks.

- **Postmortem action-item ownership is a mechanically checkable skill
  output.** incident.io's four named failure patterns (no owner, wrong
  location, no verification criterion, no finish line) translate directly
  into a field-level check a postmortem-writing skill could enforce before
  allowing the record to be marked complete: every action item requires a
  named individual (not a team), a tracking location outside the postmortem
  doc itself, and a stated closing condition. This is the single most
  actionable, already-fully-sourced candidate for a hard gate rather than a
  soft directive.

- **Runbook rot and on-call handoff notes are weak candidates for gate
  encoding right now** — the sourced material argues for "runbook as code"
  and periodic freshness checks conceptually, but no canonical field
  contract was found for either artifact, so encoding either as a rigid
  checked schema would be inventing structure the practitioner sources
  don't actually specify. Better treated as a prose directive than a
  mechanical gate until a canonical shape is found.

## Sources

- Google SRE Book — Evolving SRE Engagement Model: https://sre.google/sre-book/evolving-sre-engagement-model/
- Google SRE Book — Launch Checklist: https://sre.google/sre-book/launch-checklist/
- Google SRE Book — Reliable Product Launches: https://sre.google/sre-book/reliable-product-launches/
- Google SRE Book — Postmortem Culture: https://sre.google/sre-book/postmortem-culture/
- Google SRE Workbook — Implementing SLOs: https://sre.google/workbook/implementing-slos/
- Google SRE Workbook — Error Budget Policy: https://sre.google/workbook/error-budget-policy/
- Google SRE — SRE Responsibilities and Management Frameworks (Part IV landing page): https://landing.google.com/sre/sre-book/chapters/part4/
- getDX — Production readiness checklist for dependable releases: https://getdx.com/blog/production-readiness-checklist/
- Jos Visser (Substack) — The Continuous Production Readiness Review: https://josvisser.substack.com/p/the-continuous-production-readiness
- how2.sh — How to Set Up Incident Containment Runbooks for Engineering Teams: https://how2.sh/posts/how-to-set-up-incident-containment-runbooks-for-engineering-teams/
- Unleash — Canary release vs progressive delivery: https://www.getunleash.io/blog/canary-release-vs-progressive-delivery
- Argo Rollouts docs — Canary feature: https://argo-rollouts.readthedocs.io/en/stable/features/canary/
- Argo Rollouts docs — Kayenta analysis provider: https://argo-rollouts.readthedocs.io/en/stable/analysis/kayenta/
- PagerDuty Incident Response Docs — Incident Commander: https://response.pagerduty.com/training/incident_commander/
- PagerDuty Incident Response Docs — Postmortem Process: https://response.pagerduty.com/after/post_mortem_process/
- PagerDuty — Incident Response Lifecycle for DevOps: https://www.pagerduty.com/resources/digital-operations/learn/incident-response-lifecycle-for-devops/
- RunFrame — Incident Severity Levels: SEV0-SEV4 Matrix, Examples & Template: https://runframe.io/blog/incident-severity-levels
- FireHydrant — Getting started with severity levels: https://firehydrant.com/blog/getting-started-with-severity-levels/
- Xurrent — Incident severity levels SEV0-SEV5 explained: https://www.xurrent.com/blog/incident-severity-levels
- RunFrame — How to reduce alert fatigue: https://runframe.io/blog/how-to-reduce-alert-fatigue
- Michal Bojko (Medium) — Failure Fatigue is Killing Your On-Call Team: https://medium.com/@michal.bojko.gdansk/failure-fatigue-is-killing-your-on-call-team-fight-back-with-runbook-as-code-04d8e72d5287
- incident.io — Why Do Post-Mortem Action Items Fail?: https://incident.io/blog/why-do-post-mortem-action-items-fail-how-to-make-incident-follow-ups-actually-get-done
- Harness.io — Do you really need that Change Advisory Board: https://www.harness.io/blog/change-advisory-board-really-needed
- ITSM.tools — Change Enablement in ITIL 4: https://itsm.tools/change-enablement/
