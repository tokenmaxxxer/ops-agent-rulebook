---
status: draft
---

# Agent roles and their state machines

This document defines the agent roles the tokenmaxxxer org runs beyond the
two that already exist (`coding`, `qa`), specifies how the human user drives
every role in a star topology (user at the centre, agents never talking to
each other), and gives each role's internal state machine at the concreteness
of `coding-agent-rulebook`'s warrant plugin: named states, a named artifact
carrying the state, explicit gate conditions evaluated on a file, not on
which tool wrote it.

Sources for every research claim are the eight files under
`docs/reports/research/2026-07-25-swpd-roles/`, cited by filename.

## Part 1 — Roles

### `product`

**Decides**: what to build — value risk and business-viability risk, in
Cagan's product-trio framing where the PM owns exactly those two risks
(product-discovery.md). In a feature team, by contrast, that risk sits with
whichever stakeholder requested the feature and the PM only executes a list
— tokenmaxxxer's `product` role is deliberately the empowered-team version,
not the feature-team version (product-discovery.md).

**Given to start**: an idea — nothing more is required to open the role.

**Produces**: a specification, or a kill record. Which one depends on
running the idea through a pre-registered hypothesis: the metric, the
threshold, and the decision rule fixed before data collection, exactly as
`hypothesis-testing`'s registered-rule discipline requires and as Stage-Gate
formalizes with must-meet (binary, knockout) vs. should-meet (weighted)
criteria — a single "No" on a must-meet kills the project regardless of
should-meet scores (lifecycle-frameworks-handoffs.md).

**Prevents**: building something nobody wants, and — the sharper failure —
deciding that only after the fact, against no threshold fixed in advance.
Teresa Torres documents the softer version of this same failure: when
discovery and delivery split into separate teams, each handoff loses context
"like a game of telephone," producing distorted requirements
(product-discovery.md). `product` is scoped to prevent both the after-the-fact
judgment call and the telephone-game handoff, by fixing the rule before the
handoff happens.

### `feasibility`

**Decides**: whether the specification can be built, and whether it may be
built — the lead-engineer feasibility-risk seat in Cagan's trio
(product-discovery.md), plus the constraint classes the trio's engineer alone
cannot clear: legal, regulatory, and threat-model risk
(security-legal-compliance.md).

**Given to start**: the specification only, deliberately without the market
argument that motivated it. The split mirrors Stage-Gate's separation of
execution from gating authority (lifecycle-frameworks-handoffs.md): a
feasibility verdict argued from "but this will make money" is not a
feasibility verdict.

**Produces**: a constraint list, a go/no-go verdict, and the measurement
design — what events get collected, and where. The measurement-design output
exists because instrumentation decided after the fact cannot measure the
thing it needed to measure; DORA's architecture-capability findings tie
architectural decisions made early to delivery performance measured much
later (engineering-architecture.md, lifecycle-frameworks-handoffs.md), and
GDPR's DPIA is the sharpest form of this pattern turned into law: the
privacy impact assessment must be completed "prior to the processing," not
after — a legally forced instance of shift-left
(security-legal-compliance.md).

**Prevents**: late discovery of a technical, legal, or regulatory blocker,
and instrumentation added too late to measure the thing it was supposed to
measure.

### `review`

**Decides**: whether what was built is what was specified — a per-requirement
verdict, not a holistic judgment of code quality.

**Given to start**: the change and the specification, deliberately without
the building agent's intent, reasoning, or proposal prose. This mirrors the
qa-cycle's own discipline of working from what is observed rather than from
what the target team says it meant (qa-testing.md), and the security/legal
review functions this role absorbs: privacy engineering and DPO-style review
work from the artifact and the DPIA, not from the implementer's stated
intent (security-legal-compliance.md). Design/UX critique — is the built
thing accessible, is it consistent with what was designed — is also folded
into this role's per-requirement verdict when the specification carries
design requirements (design-ux.md).

**Produces**: a verdict of Present, Surface, Absent, or Incorrect for every
requirement in the specification — the same four-way classification
`implementation-audit` uses for exactly this reason: a surface imitation of
a requirement must be distinguishable from a real one, not merged into a
single pass/fail.

**Prevents**: a surface imitation of a requirement passing as an
implementation — the single most game-able failure mode when the entity
grading the work also built it.

### `ops`

**Decides**: whether it may ship, and — after it ships — whether it keeps
running. Google's release/SRE split treats "may ship" and "keeps running" as
one continuous accountability, gated by measurable reliability rather than
discretionary committee sign-off: the multi-year DORA-adjacent finding is
that CAB/external-approval hurts delivery-speed metrics with no offsetting
safety benefit, which is why the reconciliation path is policy-as-code
automated gates, not a committee (release-ops-sre.md).

**Given to start**: the merged change and the measurement design that
`feasibility` produced — `ops` does not invent what "healthy" means, it
consumes the definition set upstream.

**Produces**: a readiness verdict (`launch-readiness`'s discipline: every
checklist item resolves to yes/no backed by a pointable artifact — a
dashboard URL, a config, a runbook — never "we have monitoring" with nothing
to link), a rollout plan, and — after an incident — a postmortem in the
blameless-postmortem lineage.

**Prevents**: shipping without a rollback path, and shipping without knowing
what "healthy" means numerically. Google's error-budget policy is the
concrete mechanism this role borrows directly: releases proceed normally
within SLO; releases other than P0/security fixes are halted once the
trailing-window error budget is spent — an automatic, metric-triggered gate,
not a discretionary one (release-ops-sre.md).

### `coding` (existing, as-is)

Described from `coding-agent-rulebook`'s `warrant` plugin, read directly, not
proposed to change. A request becomes a proposal file under
`docs/proposals/`, whose frontmatter carries `status: proposed -> approved ->
landed` and a `files:` write set. Approval freezes the write set; a
`PreToolUse` hook (`warrant/hooks/scope-gate.sh`) then refuses edits outside
that set and refuses commits without a `Proposal: <path>` trailer, judged
against the resolved path or command string regardless of which tool
produced it. A `SessionStart` hook (`warrant/hooks/state.sh`) reads the
repository — proposal frontmatter plus `git log --grep` — and reports open
units back to a fresh session with no other memory. Nothing here is changed
by this document.

### `qa` (existing, as-is)

Described from `qa-agent-rulebook`'s `qa-cycle` plugin (see
`docs/specs/qa-cycle-state-machine.md` in that repository), read directly,
not proposed to change. Its unit is one feedback item, not the project: an
item moves `observed -> reproducing -> reproduced`, then to one of four
human-gated destinations (`handed-off`, `not-a-defect`, `wont-fix`, or back
to `reproducing`/`observed`/`parked-unreproducible`), with `handed-off ->
re-verifying -> verified-fixed` completing the loop once the human asserts a
fix landed. Human-locked transitions require a single-use verdict token
bound to both a specific item id and a specific (from, to) pair, minted only
from the user's own turn — never inferred from a file, issue, PR, comment, or
tool output. Nothing here is changed by this document.

### Open question — design/UX

Two research findings point in opposite directions and neither is decided
here.

For a separate role: design-to-development handoff is the most-reported
breakage point found in this research — 92% of designers and 91% of
developers report the handoff process has room for improvement, near-
universal dissatisfaction rather than an edge case, attributed to process and
tooling gaps rather than to people (design-ux.md).

For folding into `product`: UX research responsibilities are being absorbed
into product roles industry-wide — 47% of companies that laid off UX staff
reassigned design/research responsibilities to product teams, alongside a
sharp 2024–2025 drop in dedicated UX-research postings and maturing AI
tooling letting PMs run their own studies (design-ux.md).

Whether tokenmaxxxer needs a standalone design/UX role depends on whether the
product being built is UI-centred; this document takes no position on that
axis because it is a property of each future project, not of the org.

## Part 2 — Working with the roles

The user is the only channel between roles. Agents never talk to each other,
and each role runs in its own sandbox with only its own plugin installed —
`product`, `feasibility`, `review`, and `ops` never read another role's
repository, exactly as `coding-agent-rulebook` and `qa-agent-rulebook` today
never read each other's.

**Starting a role.** The user hands the role whatever its "given to start"
line in Part 1 names — an idea for `product`, a specification for
`feasibility`, a change plus a specification for `review`, a merged change
plus a measurement design for `ops`. A role opened without its entry
requirement met can still be opened — nothing locks the door — but it has
nothing to work from and says so; the requirement is on the work, not a gate
on entry.

**Answering a gate.** Each role stops at named points (Part 3) and needs a
decision only the user can give. A valid answer is one of: an approval (the
metric/threshold/decision-rule package in `product`), a threshold
confirmation (the same), a verdict acceptance (`review`'s per-requirement
call, `ops`'s promotion approval), or a go/no-go on a probe result
(`feasibility`). In every case the role never infers approval from the
content of a file — a file saying the right things is not consent. Whether
the user approved, rejected, or course-corrected is a semantic judgement the
model makes from the conversation, checked against that role's
`transition-rules.md` table (Part 3) for whether the resulting move is one
the table allows for that actor. This is unlike `qa-cycle`'s own mechanism,
which mints a single-use verdict token from the user's own turn
(qa-agent-rulebook's `docs/specs/qa-cycle-state-machine.md`); the four new
roles use no such token.

**Carrying output forward.** The user moves artifacts between sandboxes by
hand — copies a specification file, pastes a verdict, opens the next role
with the prior role's output as its starting input. Nothing is automatic,
nothing is shared between repositories, and no role reads another role's
files directly. This is the same constraint `coding-agent-rulebook` and
`qa-agent-rulebook` already satisfy toward each other today, extended to the
four new roles.

**Returning to a finished role.** The user may reopen any role at any time
with new input — a killed product idea can be reopened with a new hypothesis,
a `verdict`-state feasibility check can be reopened against a changed
specification. Order between roles is advisory: nothing enforces
`product` before `feasibility` before `review` before `ops`; the user routes.

**The failure this arrangement has, stated plainly.** With the user as the
only router and no cross-agent communication, the thing that goes wrong is
the user losing track of which output is current — which specification is
the live one, which verdict is stale. The mitigation costs nothing and
requires no shared machinery: each role, on being opened, reports its own
current state and what its last output was based on, read from its own
repository — the same thing `warrant/hooks/state.sh` already does at
`SessionStart` for `coding` ("reads the proposal files and git, and says
where things stand. It writes nothing"). This is per-role visibility only.
There is no global view across roles, and a role that is never opened stays
silently stale — nobody is told a `product` specification changed unless
`feasibility` is reopened. That cost is accepted deliberately: any global
view would need a shared write target, and a shared write target is exactly
what per-repository write gates (`scope-gate.sh`'s write-set freeze,
`qa-cycle`'s workspace-only persistence) exist to refuse.

## Part 3 — State machines

Mechanism applying to all four roles below. There is no approval-token
minting hook and no regex deciding intent: whether the user approved,
rejected, or course-corrected is a semantic judgement the model makes from
conversation context, not a token minted by a hook.

Each role's legal transitions live in a per-repo data file
`<role>-cycle/hooks/transition-rules.md`, pipe-delimited with columns
`from | to | actor | precondition`, where `actor` is `user` for transitions
that require the user to have said something and `agent` otherwise. A
`UserPromptSubmit` hook renders the rows matching the current state into
every prompt as a condition→allowed-transition table. If the table or the
state file cannot be read, that hook still emits a block saying so and
forbidding transitions until it is fixed — it never exits silently.

The `PreToolUse` gate decides only two things: whether a write reaches the
role's state file, judged by resolved target path rather than tool name or
literal filename (the same discipline `scope-gate.sh` applies for `coding`:
a guard that inspects only file-editing tool payloads is bypassed by the
same edit made through a shell redirect or in-place `sed`, so the gate
resolves the path regardless of which tool produced the write), and whether
the resulting transition is a row in the table. It reports "rules could not
be loaded" and "transition not in table" as distinct denials. Anything not
reaching the state file passes.

On each transition the model appends one line to the state file naming the
user utterance it read as the basis. Nothing enforces this; it exists so a
reader outside the session can see what the transition rested on.

Each of the four rulebooks (`product`, `feasibility`, `review`, `ops`)
implements all of this itself — no shared file, no cross-repo dependency.

A self-loop (a row whose `from` and `to` are the same state) is a legal
transition-table row like any other, gated the same way when marked
`actor: user`. It is how a repeatable, no-clean-single-precondition decision
(a timebox extension, a continuous sign-off, a disputed-finding
resolution) is recorded without minting a state the shape does not need.

**Skills.** Each of the four roles also carries a `skills/` directory,
`<role>-cycle/skills/<name>/SKILL.md`, one skill per artifact-producing
conversation named in Part 3 below. A skill runs a conversation with the
user and writes a named artifact to its own file path (e.g.
`product/one-pager.md`, `feasibility-cycle/skills/spike-report/...`,
`ops/rollout-plan.md`) — a different file from that role's state file.
**This matters because it is easy to get backwards: the `PreToolUse` gate
above binds only to the state file's resolved path. A skill's artifact
write is never gated** — the model can write, revise, or fail to write a
one-pager, a spike report, a rollout plan, or a postmortem freely; only the
write that changes the `status` field in the state file is checked against
the transition table.

**Bootstrap convention.** When a role's state file does not exist, the
current state is the synthetic literal `(none)`. Each role's
`transition-rules.md` carries at least one row whose `from` is `(none)`,
naming that role's legal initial state; the write that creates the state
file is allowed exactly when such a row exists for the target, and denied
otherwise as an ordinary "transition not in table" case — no separate
mechanism from the one above. The `UserPromptSubmit` injector renders
`(none)` as a normal current state and lists its rows like any other; it
emits the "rules could not be loaded" failure block only for a missing or
unparseable `transition-rules.md`, or a state file that exists but whose
state field is absent, duplicated, or unparseable — a missing state file is
not a failure. A state file that exists is checked, both by the
`UserPromptSubmit` injector and by the `PreToolUse` gate, against the role's
declared state list regardless of what value it holds — `(none)` included —
and any value outside that list, `(none)` or otherwise, is treated
identically to "unparseable," never merged with the true-absent case.
`(none)` never appears as a `to` value: nothing transitions
into it, and deleting the state file is not a transition. All four new-role
rulebooks (`product`, `feasibility`, `review`, `ops`) use this same literal;
each implements it independently, per the no-shared-file rule above.
`coding-agent-rulebook` and `qa-agent-rulebook` are untouched by this
convention.

### `product`

**Carrying artifact**: the specification file (e.g.
`docs/proposals/<date>-<slug>.md`); state lives in its frontmatter field
`status`.

**States**: `idle`, `scoping`, `researching`, `hypothesis-registered`,
`measuring`, `decided`.

**Transition table**:

| From | To | Fires on |
|---|---|---|
| `idle` | `scoping` | user hands the role an idea |
| `scoping` | `researching` | agent begins gathering evidence for the idea |
| `researching` | `hypothesis-registered` | agent proposes a metric, threshold, and decision rule; written into the file |
| `hypothesis-registered` | `measuring` | **gated** — user approves the registered package in their own turn |
| `measuring` | `decided` | the registered rule is applied to collected data |
| `hypothesis-registered` | `scoping` | user rejects the package; back to gathering |
| `scoping` | `scoping` | **gated, self-loop** — user co-creates or affirms the opportunity/outcome framing; not a hard gate, may loop indefinitely |
| `decided` | `scoping` | **gated** — a HiPPO-style conflict between the recorded decision and a senior stakeholder's opinion escalates and the broadened group reopens evidence-gathering; weakest-sourced row in this table |

The continuous re-interviewing loop (weekly interviews, a living Opportunity
Solution Tree) is not a state: it is carried by a second, separately
maintained artifact, `product/opportunity-tree.md`, updated on its own
cadence by its own skill, outside this table entirely — the gate does not
bind to it because it is not the state file.

**Rejection rule**: `hypothesis-registered -> measuring` fails unless the
file's metric field, threshold field, and decision-rule field are all
non-empty AND the transition-rules table has a `hypothesis-registered |
measuring | user | ...` row whose precondition the model judges met from the
user's own turn. A file with all three fields filled in but no such
semantic approval does not pass — content is not consent.

**Refuses while in each state**: in `idle`, refuses to scope anything (no
idea yet handed over). In `scoping`/`researching`, refuses to write a
decision rule that has not yet been derived from evidence. In
`hypothesis-registered`, refuses to enter `measuring` without the approval
condition above. In `measuring`, refuses edits to the threshold field —
once measurement starts, the finish line cannot move; a write to the
threshold field while `status: measuring` is a rejected write regardless of
which tool attempts it (Bash redirect included, per the rule above). In
`decided`, refuses to produce a verdict by fresh judgement — the output must
be the mechanical application of the rule fixed in `hypothesis-registered`,
not a new argument.

### `feasibility`

**Carrying artifact**: the feasibility record file; state in its frontmatter
field `status`.

**States**: `idle`, `scoped`, `probing`, `verdict-provisional`, `verdict`.
`probing` covers four probes: technical, prior art, legal/regulatory,
threat model. `verdict-provisional` is a draft disposition — findings and,
where applicable, a `conditions` list — recorded but not yet accepted;
`verdict` is reserved for the state after an explicit accept.

**Transition table**:

| From | To | Fires on |
|---|---|---|
| `idle` | `scoped` | user hands the role a specification |
| `scoped` | `probing` | agent begins the four probes |
| `probing` | `probing` | **gated, self-loop** — a probe's timebox expires with no conclusive answer; user decides extend (with a new, separately-scoped timebox) vs. stop |
| `probing` | `verdict-provisional` | **gated** — all four probes resolved (pass/fail/blocked, with evidence and a reversibility tag), draft disposition written |
| `verdict-provisional` | `verdict` | **gated** — user (or a named ADR/ARB-equivalent approver) explicitly changes status from provisional to accepted in their own turn; silence does not count |
| `verdict-provisional` | `scoped` | user rejects the draft verdict and returns it with a named reason |
| `probing` | `scoped` | a probe reveals the specification itself must change before probing can continue |

**Rejection rule**: `probing -> verdict-provisional` fails unless the file
records a resolution (pass/fail/blocked, with evidence) for each of the four
probe fields — technical, prior art, legal/regulatory, threat model. Any
field still empty or marked in-progress fails the transition.
`verdict-provisional -> verdict` fails unless the model judges, from the
user's own turn, that an explicit accept was given — a draft with all
fields filled in but no such semantic acceptance does not advance.

**Refuses while in each state**: in `idle`, refuses to probe anything without
a specification. In `scoped`, refuses to render a verdict before probing
starts. In `probing`, refuses to argue from the market case — the
specification is read without whatever motivated it (Part 1) — and refuses
to silently continue a probe past its declared timebox without the user
deciding extend vs. stop. In `verdict-provisional`, refuses to advance to
`verdict` without the user's explicit accept. In `verdict`, refuses to
revise the verdict without reopening `probing` on a new probe finding.

**Open question**: whether the four probes are four independent open
sub-states (`probing/technical`, `probing/prior-art`,
`probing/legal-regulatory`, `probing/threat-model`, each independently
resolvable — a more complex state file with per-probe status fields) or a
single sequential pipeline through them. This document does not decide it;
either shape satisfies the rejection rule above, which only requires all
four resolved before `verdict`.

### `review`

**Carrying artifact**: the review record file; state in its frontmatter
field `status`.

**States**: `idle`, `scoped`, `auditing`, `draft-reported`, `reported`.
`draft-reported` is entered once every requirement has a verdict, and is
where findings are confirmed with the reviewed party — disputes are
resolved there, inline — before the report is finalized into `reported`.

**Transition table**:

| From | To | Fires on |
|---|---|---|
| `idle` | `scoped` | user hands the role a change plus a specification |
| `scoped` | `auditing` | agent begins per-requirement verification |
| `auditing` | `auditing` | **gated, self-loop** — reviewer needs evidence/access the reviewed party must grant before a specific requirement can be checked |
| `auditing` | `draft-reported` | **gated** — every requirement has a verdict |
| `draft-reported` | `draft-reported` | **gated, self-loop** — the reviewed party disputes a finding; reviewer attempts resolution by clarification, recorded inline |
| `draft-reported` | `reported` | **gated** — user (or a named governance-equivalent party) confirms the draft as final |

**Rejection rule**: `auditing -> draft-reported` fails unless every
requirement line extracted from the specification carries exactly one
verdict of `Present`, `Surface`, `Absent`, `Incorrect`, or `Unverifiable` in
the record file. Any requirement with no verdict field, or a verdict value
outside that five-way set, fails the transition. `Unverifiable` is for a
requirement the reviewer genuinely cannot check from the given evidence —
distinct from `Absent` (verifiably not there). `draft-reported -> reported`
fails unless the model judges, from the user's own turn, that the draft was
confirmed as final — either by agreement or by an explicit
"publish with the disagreement noted" call.

**Refuses in every state**: reading the building agent's intent, reasoning,
or proposal prose, in `idle`, `scoped`, `auditing`, and `reported` alike —
this is not a state-dependent restriction, it is a standing one for the
whole role, mirroring why `review` is handed only the change and the
specification (Part 1).

### `ops`

**Carrying artifact**: the readiness/rollout record file; state in its
frontmatter field `status`, plus a checklist section.

**States**: `idle`, `readiness`, `rollout`, `steady`, `incident`.

Bootstrap into `idle` is `actor: agent`, matching `product` and `review`:
no sourced practice puts a human gate on state-file creation itself, only
on the in-flight decisions below, so `ops` carries no asymmetry against the
other two roles on this point.

**Transition table**:

| From | To | Fires on |
|---|---|---|
| `idle` | `readiness` | user hands the role a merged change plus the measurement design |
| `readiness` | `rollout` | **gated** — every checklist item resolves yes/no, each yes pointing at an artifact |
| `rollout` | `rollout` | **self-loop** — canary step promotion when the metric/threshold check is clean against a pre-defined threshold |
| `rollout` | `incident` | canary metric breach past a hard pre-set threshold |
| `rollout` | `steady` | **gated** — user's promotion approval, in their own turn |
| `steady` | `incident` | a monitored signal crosses its declared threshold |
| `incident` | `steady` | **gated** — postmortem is filed *and* a human has reviewed it and is satisfied with the document and its action items; a bare non-empty postmortem field is insufficient |
| `incident` | `readiness` | **gated** — postmortem action-item sign-off gates re-entry into a release cycle for the affected surface |
| `steady` | `readiness` | a new change is handed to the role |

**Rejection rule**: `readiness -> rollout` fails unless every checklist item
in the file resolves to `yes` or `no`, and every `yes` names a pointable
artifact — a URL, a file path, or a config key — in the same line; a `yes`
with an empty pointer field fails the transition, per `launch-readiness`'s
rule that "we have monitoring" with nothing to link is not a pass.
`rollout -> steady` fails unless the model judges, from the user's own turn,
that the `rollout | steady | user | ...` row's precondition is met — an
unattended rollout cannot self-promote to steady
state. `incident -> steady` fails unless a postmortem is filed *and* the
model judges, from the user's own turn, that a human has reviewed it and is
satisfied with the document and its action items — a filed-but-unreviewed
postmortem does not pass.

**Refuses while in each state**: in `idle`, refuses to assess readiness
without both inputs. In `readiness`, refuses to promote itself into
`rollout` without the checklist condition above. In `rollout`, promotes
itself step-to-step automatically while each canary step's metrics stay
clean, declares an incident itself on a breach, but refuses to call itself
`steady` without the user's promotion approval at the last step. In
`steady`, refuses further release transitions once the error budget is
exhausted — this is mechanical, mirroring Google's error-budget policy
directly: within budget, releases proceed; once the trailing-window budget
is spent, only P0/security-fix releases are accepted, all others blocked
until back within budget (release-ops-sre.md). In `incident`, refuses to
close back to `steady` without a filed *and human-reviewed* postmortem.

## Reference

Full sourcing for every claim above is in
`docs/reports/research/2026-07-25-swpd-roles/`: `product-discovery.md`,
`design-ux.md`, `engineering-architecture.md`, `qa-testing.md`,
`release-ops-sre.md`, `security-legal-compliance.md`,
`data-experimentation.md`, `lifecycle-frameworks-handoffs.md`.

Gate mechanics with published, checkable criteria — not just a named
gate but a stated rule for what makes it fail — were found in exactly four
places across this research: Cooper's Stage-Gate must-meet/should-meet split,
Google's error-budget release-freeze policy, GDPR's Article 35 DPIA
requirement, and Shape Up's betting table. The strongest-enforced gate in
industry practice found anywhere in this research is ordinary code review,
because unlike the other four it has a mechanical blocking device attached
directly to the merge action rather than a process convention around it.
