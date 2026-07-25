---
status: landed
files:
  - docs/specs/agent-roles.md
  - product-agent-rulebook/product-cycle/hooks/transition-rules.md
  - product-agent-rulebook/product-cycle/hooks/state-gate.sh
  - product-agent-rulebook/product-cycle/skills/one-pager/SKILL.md
  - product-agent-rulebook/product-cycle/skills/one-pager/templates/one-pager-template.md
  - product-agent-rulebook/product-cycle/skills/assumption-mapping/SKILL.md
  - product-agent-rulebook/product-cycle/skills/opportunity-solution-tree/SKILL.md
  - product-agent-rulebook/product-cycle/skills/guardrail-metrics/SKILL.md
  - feasibility-agent-rulebook/feasibility-cycle/hooks/transition-rules.md
  - feasibility-agent-rulebook/feasibility-cycle/hooks/state-gate.sh
  - feasibility-agent-rulebook/feasibility-cycle/skills/spike-report/SKILL.md
  - feasibility-agent-rulebook/feasibility-cycle/skills/spike-report/templates/spike-report-template.md
  - feasibility-agent-rulebook/feasibility-cycle/skills/stride-table/SKILL.md
  - feasibility-agent-rulebook/feasibility-cycle/skills/build-vs-buy/SKILL.md
  - feasibility-agent-rulebook/feasibility-cycle/skills/license-scan/SKILL.md
  - feasibility-agent-rulebook/feasibility-cycle/skills/reversibility-tag/SKILL.md
  - review-agent-rulebook/review-cycle/hooks/transition-rules.md
  - review-agent-rulebook/review-cycle/hooks/state-gate.sh
  - review-agent-rulebook/review-cycle/skills/finding-record/SKILL.md
  - review-agent-rulebook/review-cycle/skills/finding-record/templates/finding-record-template.md
  - review-agent-rulebook/review-cycle/skills/severity-classification/SKILL.md
  - ops-agent-rulebook/ops-cycle/hooks/transition-rules.md
  - ops-agent-rulebook/ops-cycle/hooks/state-gate.sh
  - ops-agent-rulebook/ops-cycle/skills/readiness-checklist/SKILL.md
  - ops-agent-rulebook/ops-cycle/skills/rollout-plan/SKILL.md
  - ops-agent-rulebook/ops-cycle/skills/postmortem/SKILL.md
  - ops-agent-rulebook/ops-cycle/skills/postmortem/templates/postmortem-template.md
  - ops-agent-rulebook/ops-cycle/skills/error-budget-policy/SKILL.md
---

# Role workflow plugins: skills, revised states, and transition tables for `product`, `feasibility`, `review`, `ops`

**A note on evidence weight, stated up front as instructed**: the `ops`
interaction research file
(`docs/reports/research/2026-07-27-role-interaction/ops.md`) did exist at
the time this proposal was written and was read in full. All four
interaction-research files were available. Nothing in this proposal rests
on thinner evidence for `ops` than for the other three roles, on that
specific count — where `ops` design choices below are weaker, it is
because the sourced material itself is silent on a point (e.g. bootstrap
actor, "who calls an incident resolved"), not because the research file
was missing.

## Intent

`docs/specs/agent-roles.md` defines four new roles (`product`,
`feasibility`, `review`, `ops`) at the granularity of states, a carrying
artifact, and a transition table, enforced today by a `PreToolUse` gate
bound to resolved file path and a table lookup, with no approval-token
mechanism. That spec was written from org-level research
(`docs/reports/research/2026-07-25-swpd-roles/`). Two further research
passes since then went deeper: what each role's practitioners actually
*produce* (field-level artifact shapes, numeric gates, failure modes —
`docs/reports/research/2026-07-27-role-practice/`), and *when they involve
another human* (the concrete moment, what's carried in, who receives it,
what comes back — `docs/reports/research/2026-07-27-role-interaction/`).
Both passes found gaps in the existing state sets and named several
`actor: user` transitions the current tables do not encode. This proposal
turns that research into a concrete design: a revised state set per role
(only where the research names a gap), a full transition table per role in
the frozen format, and a set of skills that produce the artifacts the
practice research documented, using the field lists that research already
captured — not invented ones.

This is a design document. It proposes what to build; it does not build
it.

## Constraints that change what gets built

- Semantic judgement of the user's answers is the model's, not a regex or
  a minted token. Every `actor: user` row is satisfied by the model
  reading the user's own turn and judging the precondition met — there is
  no approval-token mechanism for these four roles, unlike `qa-cycle`.
- Each rulebook implements everything itself. No shared file, no
  cross-repo import, no shared write target. `product-agent-rulebook`,
  `feasibility-agent-rulebook`, `review-agent-rulebook`, and
  `ops-agent-rulebook` each carry their own `transition-rules.md`,
  `state-gate.sh`, `inject-transition-rules.sh`, and `skills/` directory.
- The gate binds to the resolved target path of a write, never to tool
  name. An unresolvable `Bash` target aimed at the state file's own
  directory is denied; everything else passes. This proposal adds states
  and rows to the tables the gate reads; it does not change the gate's
  binding rule.
- `coding-agent-rulebook` and `qa-agent-rulebook` are out of scope and were
  not read for this proposal.
- Every artifact field list below is the one the practice research
  documented (ADR/MADR fields, spike-report fields, OWASP finding fields,
  PRR's seven dimensions, postmortem's four required sections). Where the
  practice research flagged a claim `[unsourced]` or as this document's
  own synthesis, that qualifier is carried forward here rather than
  silently upgraded to a sourced fact.

## What will be done

### `product`

**Revised state set.** The states stay `idle`, `scoping`, `researching`,
`hypothesis-registered`, `measuring`, `decided` — unchanged as a set. The
practice research's central finding is that nothing in this list covers
the *continuous* re-interviewing loop (weekly interviews, a living
Opportunity Solution Tree, updated on the same cadence, independent of
any single hypothesis's lifecycle). Decision: **do not add a state for
it.** The continuous work and the per-hypothesis lifecycle are different
shapes — one is ongoing and undated, the other has a start and an end —
and folding them into one state machine would blur that distinction rather
than clarify it. Instead, the Opportunity Solution Tree becomes a second,
separately-maintained artifact (`product/opportunity-tree.md`) updated by
its own skill on its own cadence, outside the transition table entirely;
the gate does not bind to it, because it is not the state file. This
mirrors how the existing spec already keeps the measurement-design output
of `feasibility` outside `ops`'s gated fields.

The two moments the interaction research found with no home in the
existing five-state table:

- **Opportunity/problem sign-off** (moment 1, product interaction
  research): Torres's practice treats this as continuous, iterative
  co-creation with stakeholders, not a single gate — the research itself
  flags this as a weaker fit than the others. Decision: encode it as a
  `scoping -> scoping` self-loop, `actor: user`, rather than a new state,
  since the research's own language ("no clean single precondition") rules
  out treating it as a hard gate.
- **HiPPO escalation** (moment 6): when a senior stakeholder's opinion
  conflicts with the recorded decision after `decided`, the research finds
  no sourced terminal resolution rule, only the recommended tactic
  (broaden the room, argue from evidence). Decision: encode it as a
  `decided -> scoping` row, `actor: user`, explicitly marked as the
  weakest-sourced row in this table — reopening evidence-gathering is the
  only sourced move ("cross-functional teams with... authority to make
  collaborative decisions"), so that is what the row does, without
  inventing a forcing rule the research doesn't support.

**Transition table** (frozen format `from | to | actor | precondition`;
citations to `docs/reports/research/2026-07-27-role-interaction/product.md`
unless noted):

| from | to | actor | precondition |
|---|---|---|---|
| `(none)` | `idle` | agent | `product/state.md` does not yet exist; agent creates it at `idle` (unchanged, `agent-roles.md`) |
| `idle` | `scoping` | user | user hands the role an idea (unchanged, `agent-roles.md`) |
| `scoping` | `scoping` | user | opportunity/outcome framing drafted; user co-creates or affirms it (moment 1) — not a hard gate, may loop indefinitely |
| `scoping` | `researching` | agent | agent begins gathering evidence (unchanged) |
| `researching` | `hypothesis-registered` | agent | metric, threshold, decision rule proposed and written (unchanged) |
| `hypothesis-registered` | `measuring` | user | funding/betting decision recorded — a bet, a stage-gate go, or an equivalent alignment/go call (moment 2 + moment 3) |
| `hypothesis-registered` | `scoping` | user | user rejects the registered package (unchanged) |
| `measuring` | `decided` | agent | registered decision rule mechanically applied to collected data (unchanged; deliberately not `actor: user` — pre-registration exists precisely so this step has no discretionary case, per the companion practice research) |
| `decided` | `scoping` | user | HiPPO-style conflict between the recorded decision and a senior stakeholder's opinion escalates and the broadened stakeholder group reopens evidence-gathering (moment 6) — weakest-sourced row in this table; no terminal forcing rule exists in the research |

Five `actor: user` rows.

**Skills** (`product-cycle/skills/`):

- **`one-pager`** — belongs to `scoping`. Asks the user for: background/
  context, a problem statement kept explicitly separate from any proposed
  solution, candidate hypotheses, known risks, and goals/success metrics
  (the Reforge/Lenny's one-pager shape, product practice research). Writes
  `product/one-pager.md`. Template at
  `product-cycle/skills/one-pager/templates/one-pager-template.md` carries
  those five fields as headings, each required non-empty before the skill
  reports the one-pager complete.
- **`assumption-mapping`** — belongs to `researching`. Asks the user (or
  derives from interview evidence already on file) for candidate
  assumptions across the five Torres categories: desirability, viability,
  feasibility, usability, ethical. Plots each on the evidence-strength ×
  importance 2x2; the critical + weak-evidence quadrant becomes the
  priority test list, run through one of the four assumption-test types
  (prototype test, one-question survey, data mining, engineering spike).
  Writes `product/assumption-map.md`. Injects the Mom Test's three
  interview rules (talk about the customer's life not your idea; past
  specifics not future hypotheticals; interviewer talks ≤20%) as a
  standing directive any time the agent drafts interview questions in this
  state.
- **`opportunity-solution-tree`** — cross-cutting, triggered by the
  `scoping -> scoping` self-loop. Asks the user which opportunity/solution
  the tree should be updated with this cycle. Writes/updates
  `product/opportunity-tree.md`, four layers: desired outcome (one node),
  opportunities, candidate solutions per opportunity, assumption tests per
  solution (practice research's OST shape). This file is outside the gate
  — it is not `product/state.md` and no transition binds to it.
- **`guardrail-metrics`** — belongs to `hypothesis-registered`, read at
  `measuring`. Asks the user to name guardrail metrics — metrics that must
  not move adversarially, distinct from the primary metric — before
  `measuring` starts. Requires this field non-empty as a precondition of
  `hypothesis-registered -> measuring`, the same discipline already
  applied to the metric/threshold/decision-rule fields.

**Conversational flow, from `(none)`.** The agent opens by asking what
idea it's been handed — nothing else is assumed at `idle`. Once the user
states an idea, the agent moves to `scoping` and runs the `one-pager`
skill: it asks for background, then explicitly asks the user to state the
problem *without* proposing a solution yet, then risks, then a first cut
at goals/metrics. It writes `product/one-pager.md` and, before leaving
`scoping`, asks the user to affirm the outcome framing — if the user's
answer is vague ("that sounds about right"), the agent's next question is
not to proceed but to ask where that read came from ("is that from a
customer conversation, or your own read?"), per the product interaction
research's core rule that a vague response is a prompt to re-ask for its
evidentiary source, not a green light. Once affirmed, the agent moves to
`researching`, runs `assumption-mapping`, asks the user (or interview
notes already on file) for assumptions in each of the five categories,
plots them, and proposes which top-quadrant assumption to test first. When
enough evidence exists, the agent drafts a hypothesis statement in the
"We believe / we will know" template and asks the user which guardrail
metrics must not move. The user answers, the agent writes both, and the
package moves to `hypothesis-registered`, awaiting a funding/betting
decision recorded in the user's next turn before `measuring` may start.

### `feasibility`

**Revised state set.** The existing four (`idle`, `scoped`, `probing`,
`verdict`) are extended by one new state: **`verdict-provisional`**,
inserted between `probing` and `verdict`. Revised set: `idle`, `scoped`,
`probing`, `verdict-provisional`, `verdict`.

- **Timebox-extension point during `probing`**: the interaction research
  finds a spike (or RFC/Last-Call-equivalent) never silently continues past
  its declared timebox — it goes back to a human, who decides extend vs.
  stop, and an extension is a *new*, separately-scoped timebox, not a
  silent continuation. Decision: **do not add a new sub-state**; add a
  `probing -> probing` self-loop, `actor: user`, so the existing state
  covers the extension decision without minting
  `probing/extension-requested` as its own named state — the loop already
  satisfies "a human decided, recorded" without adding machinery the
  four-state shape doesn't need.
- **Provisional-vs-accepted split inside `verdict`**: both the practice
  and interaction research converge on this being real — MADR's own
  `proposed` status, ADR/ARB acceptance as an explicit status flip, PEP's
  `proposed` before a Delegate's pronouncement, and the practice research's
  own finding that real technical-risk practice produces
  feasible-with-conditions outcomes, not a flat binary. Decision: **add
  `verdict-provisional`** as a distinct state — a draft disposition with
  recorded findings and (where applicable) a `conditions` list — with
  `verdict` reserved for the state after an explicit accept.

**Transition table** (citations to
`docs/reports/research/2026-07-27-role-interaction/feasibility.md` unless
noted):

| from | to | actor | precondition |
|---|---|---|---|
| `(none)` | `idle` | agent | first write to `feasibility-record.md` (unchanged, existing `transition-rules.md`) |
| `(none)` | `scoped` | agent | `market_argument_supplied: false` recorded in frontmatter (unchanged) |
| `scoped` | `probing` | agent | agent begins the four probes (unchanged) |
| `probing` | `scoped` | agent | a probe reveals the specification itself must change (unchanged) |
| `probing` | `probing` | user | practitioner reports a probe's timebox expired with no conclusive answer; user decides extend (with a new, separately-scoped timebox) vs. stop |
| `probing` | `verdict-provisional` | agent | all four probe fields (technical, prior_art, legal_regulatory, threat_model) resolved pass/fail/blocked with evidence and a draft disposition, including a reversibility classification per finding |
| `verdict-provisional` | `verdict` | user | user (or a named ADR/ARB-equivalent approver) explicitly changes status from provisional to accepted in their own turn — silence does not count |
| `verdict-provisional` | `scoped` | user | user rejects the draft verdict and returns it with a named reason (rework), mirroring an ADR/ARB "reject or require changes" outcome |

Three `actor: user` rows.

**Skills** (`feasibility-cycle/skills/`):

- **`spike-report`** — belongs to the technical probe inside `probing`.
  Asks the user (or derives from the specification) for: Spike Title,
  Description/Goal (the question being investigated), Type of spike
  (technical/functional/architectural), Estimated Timebox, and — written
  *before* work starts, not after — Acceptance Criteria. On completion,
  records Tasks/Activities, Outcomes/Learnings, Recommendation, and open
  questions. Writes to the technical-probe field plus
  `feasibility-cycle/skills/spike-report/templates/spike-report-template.md`
  as the field skeleton. The skill refuses to mark acceptance criteria
  filled if the timestamp on that field postdates the timebox's start —
  catching the "acceptance criteria written after the fact" failure mode
  named in the practice research.
- **`stride-table`** — belongs to the threat-model probe. Produces one row
  per (element, STRIDE category — one or more of
  Spoofing/Tampering/Repudiation/Information Disclosure/Denial of
  Service/Elevation of Privilege, entry point or trust boundary crossed,
  mitigation-or-accepted-risk disposition). Every row requires a
  disposition field non-empty before the threat-model probe can resolve.
- **`build-vs-buy`** — belongs to the prior-art probe. Produces a
  build-vs-buy comparison table plus, for each open-source dependency, an
  attached health score (OpenSSF Scorecard or equivalent).
- **`license-scan`** — belongs to the legal-regulatory probe. Produces a
  per-dependency license verdict (FOSSA/ScanCode-or-equivalent) plus a
  regulatory-applicability note.
- **`reversibility-tag`** — cross-cutting across all four probes. Asks the
  agent (as a standing directive, not a user prompt) to classify every
  technical-probe finding as a one-way or two-way door (Bezos framing)
  before it is written to the probe-resolution field — the rigor required
  of the other three probes' evidence scales with this tag, per the
  practice research's synthesis that reversibility is a cross-cutting
  field on every finding rather than a fifth probe.

**Conversational flow, from `(none)`.** The agent's first write creates
`feasibility-record.md` at `idle`, or directly at `scoped` if the caller
already marks `market_argument_supplied: false`. In `scoped`, the agent
asks the user for the specification (deliberately without whatever
motivated it) and states the four probes it will run. Entering `probing`,
it runs each probe's skill: for the technical probe it asks the user (or
proposes) a spike question and a timebox — "what specifically do we need
to know, and how many days (1–3) do we have to find out" — writes the
acceptance criteria before starting, then investigates. If the timebox
expires without an answer, the agent stops and asks the user: extend with
a new timebox, or record the gap as an open finding and move on — it does
not silently keep going. For prior-art it runs `build-vs-buy`, for
legal-regulatory it runs `license-scan`, for threat-model it runs
`stride-table`, tagging every technical finding one-way/two-way as it
goes. Once all four resolve, the agent writes a draft disposition —
feasible, infeasible, or feasible-with-conditions, each condition tied to
a probe's finding — and moves to `verdict-provisional`. It then asks the
user to accept, reject, or request rework; only an explicit "yes, accept
this" in the user's own turn moves the record to `verdict`.

### `review`

**Revised state set.** The existing four (`idle`, `scoped`, `auditing`,
`reported`) become five: `idle`, `scoped`, `auditing`, **`draft-reported`**,
`reported`.

- **Draft-versus-final split inside `reported`**: Fagan inspection's
  follow-up phase, the exit-conference convention of pre-circulating a
  draft before the synchronous discussion, and the audit-practice pattern
  of a written management response attached per finding all show the same
  shape — a report is drafted, walked through with the party being
  reviewed, and only then finalized. Decision: **add `draft-reported`**
  as the state entered once every requirement has a verdict, with
  `reported` reserved for after the user has reviewed the draft and closed
  it (or the model has recorded the dispute resolution inline).
- **`Unverifiable` verdict**: both the practice research (Fagan follow-up /
  AICPA tolerable-deviation framing) and the interaction research
  (reviewers repeatedly need to request evidence/access they don't have
  before a requirement can be checked at all) independently support this
  gap — two research passes converge on the same missing case from
  different angles. Decision: **add `Unverifiable`** as a fifth verdict,
  for a requirement the reviewer genuinely cannot check from the given
  evidence — distinct from `Absent` (verifiably not there).

**Transition table** (citations to
`docs/reports/research/2026-07-27-role-interaction/review.md` unless
noted):

| from | to | actor | precondition |
|---|---|---|---|
| `(none)` | `idle` | agent | `review-record.md` does not yet exist; agent creates it (unchanged) |
| `idle` | `scoped` | user | user hands the role a change plus a specification, and reviewer/auditee have agreed the engagement's scope and boundaries (entrance-conference equivalent) |
| `scoped` | `auditing` | agent | agent begins per-requirement verification; no further human input required to begin |
| `auditing` | `auditing` | user | reviewer needs evidence/access the party being reviewed must grant before a specific requirement can be checked — stays in `auditing`, not its own state |
| `auditing` | `draft-reported` | agent | every requirement carries exactly one verdict from `Present`, `Surface`, `Absent`, `Incorrect`, `Unverifiable` |
| `draft-reported` | `draft-reported` | user | the reviewed party disputes a finding; reviewer attempts resolution by clarification, recorded as a management-response-equivalent artifact attached to the finding, not a new state |
| `draft-reported` | `reported` | user | user (or a named governance-equivalent party) confirms the draft as final — either by agreement or by an explicit "publish with the disagreement noted" call |

Three `actor: user` rows.

**Skills** (`review-cycle/skills/`):

- **`finding-record`** — belongs to `auditing`/`draft-reported`. Produces,
  per requirement: (1) a stable identifier for the specific requirement/
  claim; (2) the verdict (one of the five above); (3) an evidence pointer
  into the actual diff (file/line/hunk), never a paraphrase; (4) a
  one-line rationale connecting evidence to verdict; (5) for `Incorrect`,
  what the spec required vs. what was built. Writes to `review-record.md`'s
  per-requirement section. Template at
  `review-cycle/skills/finding-record/templates/finding-record-template.md`.
  Refuses to accept a verdict with no evidence pointer, mirroring OWASP's
  mandatory Evidence/PoC field.
- **`severity-classification`** — belongs to `draft-reported`, optional,
  used only where the review's scope is extended into risk-weighting
  (severity is not required for pure fidelity-checking per the existing
  spec). Uses a deterministic table-lookup shape (Chromium's five bands or
  Microsoft's four-level bug bar), not an averaged subjective score like
  DREAD — the practice research's explicit lesson from DREAD's own
  abandonment.

**Conversational flow, from `(none)`.** The agent's first write opens
`review-record.md` at `idle`. At `idle`, it asks the user for the change
and the specification, and confirms with the user what is explicitly out
of scope — the entrance-conference equivalent — before moving to
`scoped`. Entering `auditing`, the agent works requirement by requirement
without asking permission for its own severity or existence judgments (per
the interaction research's "what proceeds without asking" finding); it
only stops to ask the user when it needs evidence or access it does not
have — e.g., "the spec requires X be logged at runtime; I can't observe
that from a static diff — can you point me at a log sample, or should this
be `Unverifiable`?" Once every requirement has a verdict, the agent writes
the finding-record file and moves to `draft-reported`, then tells the user:
"draft ready — N Present, M Surface, K Absent, J Incorrect, L
Unverifiable; want to walk through any before I finalize?" If the user
disputes a finding, the agent re-examines it, records the outcome inline
(retained with the reviewer's position and the reviewed party's rebuttal
side by side, if unresolved), and stays in `draft-reported`. Only an
explicit "publish it" or equivalent in the user's own turn moves the
record to `reported`.

### `ops`

**Revised state set.** Unchanged: `idle`, `readiness`, `rollout`,
`steady`, `incident`. Decision, on the first named question: **the
five-state cycle is sufficient** — the practice research maps every
sourced practice (PRR/launch checklist onto `readiness`, canary/
progressive delivery onto `rollout`, SLO/error-budget accounting onto
`steady`, IC/timeline/postmortem onto `incident`) onto it cleanly, with the
one named gap (SLO/error-budget *definition* itself has no state) being a
deliberate, already-made design choice — `ops` consumes the measurement
design `feasibility` produced rather than inventing "healthy," so it is
not a defect to fix.

Decision, on the second named question — **`ops`'s bootstrap actor**: the
existing `ops-cycle/hooks/transition-rules.md` has `(none) -> idle` as
`actor: user`, while `product` and `review` both bootstrap as `actor:
agent`. The interaction research is explicit that it found nothing
supporting either choice from `ops`-specific evidence — every sourced
human-authority claim in that research is about in-flight decisions
(launch, rollback, severity, postmortem sign-off), never about starting
the state machine. Given no evidence justifies the asymmetry, and given
this proposal's own constraint that a state file's existence is not itself
a consequential decision (the same bootstrap convention treats it as
`agent` for the other three roles), **`ops`'s bootstrap row changes to
`actor: agent`**, for consistency with `product` and `review` absent any
reason to hold it to a stricter bar.

**Transition table** (citations to
`docs/reports/research/2026-07-27-role-interaction/ops.md` unless noted):

| from | to | actor | precondition |
|---|---|---|---|
| `(none)` | `idle` | agent | `ops/state.md` does not yet exist; agent initializes the ops cycle — **changed from `user`**: no sourced practice puts a human gate on state-file creation itself, only on in-flight decisions below |
| `idle` | `readiness` | user | user hands a merged change plus the measurement design (unchanged, `agent-roles.md`) |
| `readiness` | `rollout` | agent | checklist complete, every yes item has a non-empty pointable artifact (unchanged) |
| `rollout` | `rollout` | agent | canary step promotion when the metric/threshold check is clean against a pre-defined, unambiguous threshold — Argo/Flagger/Kayenta auto-promote loops are real production practice for exactly this |
| `rollout` | `incident` | agent | canary metric breach past a hard pre-set threshold — sourced as automatic in mature tooling; raising costs nothing and understating costs more |
| `rollout` | `steady` | user | user states an explicit promotion approval in their own turn (unchanged) — traffic cutover to full/production is a human call even when the tooling that gets it to the last canary step is automatic |
| `steady` | `incident` | agent | a monitored signal crosses its declared threshold (unchanged) |
| `incident` | `steady` | user | **changed from `agent`**: postmortem is filed *and* a human ("senior engineers," per the sourced practice) has reviewed it and is satisfied with the document and its action items — Google's own stated rule, "an unreviewed postmortem might as well never have existed," makes a bare non-empty postmortem field insufficient |
| `incident` | `readiness` | user | postmortem action-item sign-off gates re-entry into a release cycle for the affected surface specifically, distinct from the general `incident -> steady` close |
| `steady` | `readiness` | user | user hands a new change and the error budget is not exhausted (unchanged) |

Five `actor: user` rows.

**Skills** (`ops-cycle/skills/`):

- **`readiness-checklist`** (existing, extended) — the seven-dimension
  shape: Service Levels (SLO/SLI defined), Architecture Design Review,
  Performance, Documentation, Observability, Testing, Deployment Strategy.
  Every item resolves yes/no; every yes names a pointable artifact — a
  dashboard URL, a config key, a runbook path — never bare prose, per the
  `launch-readiness` discipline already cited in `agent-roles.md`.
- **`rollout-plan`** — belongs to `rollout`. Asks the user for (or derives
  from the readiness record) the traffic curve: per-step traffic
  percentage, wait/bake time per step, the metric queries evaluated at
  each step, and the pass/fail/inconclusive threshold for each (Kayenta's
  `pass`/`marginal` bands, or Flagger's `interval`/`stepWeight`/
  `maxWeight`/`threshold` fields). Writes `ops/rollout-plan.md`; the
  `rollout -> rollout` and `rollout -> incident` agent rows read this
  file's thresholds mechanically.
- **`postmortem`** — belongs to `incident`. Enforces Google's required
  trigger criteria and required sections: impact (what broke, for whom,
  how long), actions taken during response, root cause(s), prevention/
  follow-up action items. Enforces, per action item: one named individual
  owner (never a team), a tracking location outside the postmortem
  document itself, and a stated closing/verification condition —
  incident.io's four named failure patterns, made into a mechanical field
  check. Writes to `ops/postmortem-<incident-id>.md` using
  `ops-cycle/skills/postmortem/templates/postmortem-template.md`. Does not
  itself mark the postmortem "reviewed" — that is the human gate on
  `incident -> steady` above, not something this skill can self-certify.
- **`error-budget-policy`** — belongs to `steady`. Defines, per SLI: the
  measurement method, the SLO target, the measurement window, and the
  consequence table (within budget: releases proceed; budget exhausted:
  only P0/security-fix releases proceed until back within budget).
  Read, not written, by the `steady`-state refusal rule already in
  `agent-roles.md`.

**Conversational flow, from `(none)`.** The agent initializes
`ops/state.md` at `idle` on its own when handed a merged change — no human
gate on this step. It then asks the user for the measurement design (what
`feasibility` produced) and moves to `readiness`, running the
`readiness-checklist` skill: it asks, dimension by dimension, "is the SLO
defined — what's the dashboard URL," "is there a runbook — what's the
path," refusing to mark a `yes` complete without a pointer. Once every
item resolves, it moves to `rollout` on its own and runs `rollout-plan`,
asking the user (or reading the readiness record) for the traffic curve
and per-step thresholds. As each canary step's metrics stay clean against
the declared threshold, the agent promotes itself automatically; on a
breach, it declares an incident itself, immediately, without waiting to be
asked — "when in doubt, raise it" is the sourced default. At the last
canary step, it stops and asks the user for an explicit promotion
approval before calling itself `steady`. If an incident fires, the agent
builds a live timeline, and once resolved, runs `postmortem`, asking the
user for impact, root cause, and — critically — a named individual owner
and closing condition for every action item, refusing team-only
ownership. It then tells the user the draft is ready for review, and does
not move to `steady` until the user confirms it has actually been
reviewed and is satisfactory — not merely that the file exists.

## Out of scope

- `coding-agent-rulebook` and `qa-agent-rulebook` are untouched; neither
  was read for this proposal.
- No approval-token minting mechanism is added for any of the four roles;
  semantic judgement of the user's turn remains the model's job, as today.
- The gate's binding rule (resolved path, not tool name) is not changed by
  this proposal in any repo.
- The `inject-transition-rules.sh` rendering mechanism is not changed —
  only the `transition-rules.md` data files it reads grow new rows and
  states.
- No cross-repo or shared-file mechanism is introduced; the four rulebooks
  remain fully independent, each implementing its own revised table and
  skills.
- SLO/error-budget *definition* is not added as an `ops` state or skill
  output beyond reading what `feasibility` already produced — that
  boundary is unchanged.
- A dedicated forcing rule for an unresolved HiPPO standoff (`product`),
  an unresolved feasibility-vs-schedule conflict, or an unresolved
  review-finding dispute past "publish with disagreement noted" is
  explicitly not designed here — the research found no sourced terminal
  rule for any of these, and this proposal does not invent one.

## How we will know it worked

- Every new state appears in its repo's `transition-rules.md` with at
  least one `from` row and (except for terminal-shaped states) at least
  one `to` row, in the frozen `from | to | actor | precondition` format,
  parseable by the existing `inject-transition-rules.sh` and
  `state-gate.sh` mechanism without modification to the gate's binding
  logic.
- Every `actor: user` row added here carries an inline citation to a named
  moment in that role's `2026-07-27-role-interaction/*.md` file; no row
  was added on the strength of the practice research alone.
- Every new skill's `SKILL.md` names the state it belongs to, the artifact
  it writes, the artifact's file path, and the field list — and every
  field list traces to a named template or shape in the practice research
  (MADR, OWASP, PRR's seven dimensions, the hypothesis-brief template,
  spike-report fields, STRIDE's per-row shape), not an invented one.
- A fresh session opened against any of the four repos, with no state file
  present, is told its state is `(none)` and offered exactly the rows this
  proposal's tables list for that role — nothing more, nothing less.
- The five sections above (revised states, transition table, skills,
  conversational flow, what stays unchanged) exist for all four roles;
  none was left as a stub.

## What did not work

- product와 feasibility의 `state-gate.sh`에 `new_stage == old_stage` / `old_status == new_status` 단축 경로가 남아 있다고 생각하지 않았는데, before-landing 헌터가 재현했다: `stage: hypothesis-registered`를 유지한 채 등록된 `metric`/`threshold`를 다시 쓰는 Write가 exit 0으로 통과하고, 전이표도 `actor: user`도 조회되지 않는다. 자기 루프 행은 이 단축 경로 뒤에서 장식이었다. 미수정.
- 기록: docs/reports/2026-07-28-hunt-role-workflow-plugins.md
