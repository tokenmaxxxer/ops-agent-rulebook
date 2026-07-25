---
status: draft
---

# Agent roles and their state machines

This document defines the `ops` agent role this repository carries,
specifies how the human user drives it in a star topology (user at the
centre, agents never talking to each other), and gives its internal state
machine at the concreteness of `coding-agent-rulebook`'s warrant plugin:
named states, a named artifact carrying the state, explicit gate conditions
evaluated on a file, not on which tool wrote it.

Sources for every research claim are the eight files under
`docs/reports/research/2026-07-25-swpd-roles/`, cited by filename.

## Part 1 — Role

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

## Part 2 — Working with the role

The user is the only channel into and out of `ops`. Agents never talk to
each other, and `ops` runs in its own sandbox with only its own plugin
installed — it never reads another role's repository, exactly as
`coding-agent-rulebook` and `qa-agent-rulebook` today never read each
other's.

**Starting the role.** The user hands `ops` whatever its "given to start"
line in Part 1 names — a merged change plus a measurement design. The role
opened without its entry requirement met can still be opened — nothing locks
the door — but it has nothing to work from and says so; the requirement is
on the work, not a gate on entry.

**Answering a gate.** The role stops at named points (Part 3) and needs a
decision only the user can give. A valid answer is one of: a verdict
acceptance or a promotion approval. In every case the role never infers
approval from the content of a file — a file saying the right things is not
consent. Whether the user approved, rejected, or course-corrected is a
semantic judgement the model makes from the conversation, checked against
`ops`'s `transition-rules.md` table (Part 3) for whether the resulting move
is one the table allows for that actor. This is unlike `qa-cycle`'s own
mechanism, which mints a single-use verdict token from the user's own turn
(qa-agent-rulebook's `docs/specs/qa-cycle-state-machine.md`); `ops` uses no
such token.

**Carrying output forward.** The user moves artifacts into and out of the
`ops` sandbox by hand — copies in a specification-derived measurement design,
pastes out a rollout verdict. Nothing is automatic, nothing is shared
between repositories, and `ops` does not read another role's files directly.
This is the same constraint `coding-agent-rulebook` and `qa-agent-rulebook`
already satisfy toward each other today, extended to `ops`.

**Returning to a finished cycle.** The user may reopen `ops` at any time with
new input — a `steady`-state service can be handed a new change and cycle
back through `readiness`. Order relative to other roles is advisory: nothing
enforces any particular role running before `ops`; the user routes.

**The failure this arrangement has, stated plainly.** With the user as the
only router and no cross-agent communication, the thing that goes wrong is
the user losing track of which output is current — which measurement design
is the live one, which verdict is stale. The mitigation costs nothing and
requires no shared machinery: `ops`, on being opened, reports its own
current state and what its last output was based on, read from its own
repository — the same thing `warrant/hooks/state.sh` already does at
`SessionStart` for `coding` ("reads the proposal files and git, and says
where things stand. It writes nothing"). This is per-role visibility only.
There is no global view across roles, and `ops` stays silently stale if never
reopened — nobody is told an upstream measurement design changed unless
`ops` is reopened. That cost is accepted deliberately: any global view would
need a shared write target, and a shared write target is exactly what
per-repository write gates (`scope-gate.sh`'s write-set freeze, `qa-cycle`'s
workspace-only persistence) exist to refuse.

## Part 3 — State machine

Mechanism applying to the `ops` role below. There is no approval-token
minting hook and no regex deciding intent: whether the user approved,
rejected, or course-corrected is a semantic judgement the model makes from
conversation context, not a token minted by a hook.

`ops`'s legal transitions live in a per-repo data file
`ops-cycle/hooks/transition-rules.md`, pipe-delimited with columns
`from | to | actor | precondition`, where `actor` is `user` for transitions
that require the user to have said something and `agent` otherwise (its
bootstrap row's actor is `agent`, per Part 1). A `UserPromptSubmit` hook
renders the rows matching the current state into every prompt as a
condition→allowed-transition table. If the table or the state file cannot be
read, that hook still emits a block saying so and forbidding transitions
until it is fixed — it never exits silently.

The `PreToolUse` gate decides only two things: whether a write reaches
`ops`'s state file, judged by resolved target path rather than tool name or
literal filename (the same discipline `scope-gate.sh` applies for `coding`:
a guard that inspects only file-editing tool payloads is bypassed by the
same edit made through a shell redirect or in-place `sed`, so the gate
resolves the path regardless of which tool produced the write), and whether
the resulting transition is a row in the table. It reports "rules could not
be loaded" — for a gate that cannot establish its own input, i.e. the table
or state file itself is unreadable — and "transition not in the table" — for
a transition the table refuses — as distinct denials. Anything not reaching
the state file passes.

On each transition the model appends one line to the state file naming the
user utterance it read as the basis. Nothing enforces this; it exists so a
reader outside the session can see what the transition rested on.

This rulebook implements all of this itself — no shared file, no cross-repo
dependency.

A self-loop (a row whose `from` and `to` are the same state) is a legal
transition-table row like any other, gated the same way when marked
`actor: user`. It is how a repeatable, no-clean-single-precondition decision
(a canary-step promotion, a continuous sign-off) is recorded without minting
a state the shape does not need.

**Skills.** `ops` also carries a `skills/` directory,
`ops-cycle/skills/<name>/SKILL.md`, one skill per artifact-producing
conversation named in Part 3 below. A skill runs a conversation with the
user and writes a named artifact to its own file path (e.g.
`ops/rollout-plan.md`) — a different file from `ops`'s state file. **This
matters because it is easy to get backwards: the `PreToolUse` gate above
binds only to the state file's resolved path. A skill's artifact write is
never gated** — the model can write, revise, or fail to write a rollout
plan or a postmortem freely; only the write that changes the `status` field
in the state file is checked against the transition table.

**Bootstrap convention.** When `ops`'s state file does not exist, the
current state is the synthetic literal `(none)`. `ops`'s
`transition-rules.md` carries at least one row whose `from` is `(none)`,
naming its legal initial state; the write that creates the state file is
allowed exactly when such a row exists for the target, and denied otherwise
as an ordinary "transition not in the table" case — no separate mechanism
from the one above. The `UserPromptSubmit` injector renders `(none)` as a
normal current state and lists its rows like any other; it emits the "rules
could not be loaded" failure block only for a missing or unparseable
`transition-rules.md`, or a state file that exists but whose state field is
absent, duplicated, or unparseable — a missing state file is not a failure.
A state file that exists is checked, both by the `UserPromptSubmit` injector
and by the `PreToolUse` gate, against `ops`'s declared state list regardless
of what value it holds — `(none)` included — and any value outside that
list, `(none)` or otherwise, is treated identically to "unparseable," never
merged with the true-absent case. `(none)` never appears as a `to` value:
nothing transitions into it, and deleting the state file is not a
transition. This rulebook implements the convention independently, per the
no-shared-file rule above. `coding-agent-rulebook` and `qa-agent-rulebook`
are untouched by this convention.

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
