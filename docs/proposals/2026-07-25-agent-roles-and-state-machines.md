---
status: landed
files:
  - docs/specs/agent-roles.md
  - docs/specs/agent-station-topology.md
  - docs/proposals/2026-07-25-agent-station-topology-spec.md
  - docs/proposals/2026-07-25-lineage-closure-per-repo-ledger.md
  - docs/reports/2026-07-25-hunt-agent-station-topology-spec.md
  - docs/reports/2026-07-25-hunt-lineage-closure-per-repo-ledger.md
---

## Intent

The research into software product development roles is complete: eight sourced
reports under `docs/reports/research/2026-07-25-swpd-roles/` cover product
discovery, design/UX, engineering/architecture, QA/testing, release/ops/SRE,
security/legal/compliance, data/experimentation, and lifecycle handoff
mechanics across real organizations. What is needed now is a single document,
`docs/specs/agent-roles.md`, that defines which agent roles the tokenmaxxxer
org needs beyond the two that already exist, how the human user drives each
role without the star topology (user at the center, agents never talking to
each other) breaking down, and each role's internal state machine specified at
the same level of concreteness as `coding-agent-rulebook`'s warrant plugin —
named states, a named artifact carrying the state, explicit gate conditions,
not prose description.

## Cleanup included in this work

Five files produced earlier in this session went beyond what was asked and are
deleted as part of this change:

- `docs/specs/agent-station-topology.md`
- `docs/proposals/2026-07-25-agent-station-topology-spec.md`
- `docs/proposals/2026-07-25-lineage-closure-per-repo-ledger.md`
- `docs/reports/2026-07-25-hunt-agent-station-topology-spec.md`
- `docs/reports/2026-07-25-hunt-lineage-closure-per-repo-ledger.md`

They explored a shared cross-repository coordination mechanism (a topology
spec plus a lineage/ledger scheme) that this proposal's constraints explicitly
reject — no shared file, no cross-repo dependency, no machinery imposed on the
rulebooks. Deleting them is part of landing this proposal, not a separate
cleanup task.

The eight research files under `docs/reports/research/2026-07-25-swpd-roles/`
are the requested deliverable of the prior research phase and are kept
untouched — they are read as input to this proposal, not modified.

## Constraints already settled

- Each rulebook repository is fully self-contained and independently
  installable into its own sandbox; no shared code, no cross-repo dependency,
  no shared file.
- Agents never communicate with each other. The human user is the only
  channel and sits at the centre of a star topology.
- `coding-agent-rulebook` and `qa-agent-rulebook` are NOT modified and are NOT
  required to change. Whatever this document specifies leaves both working
  exactly as they do today.
- The user does the coordination manually — checking outputs and deciding
  what goes where. No machinery is imposed on the rulebooks to automate that:
  no artifact lineage frontmatter, no ledger files, no shared index. Those
  were explored (see Cleanup above) and rejected.
- Each role implements its own state machine independently. There is no
  shared engine.

## What will be done

Write `docs/specs/agent-roles.md` in three parts.

**Part 1 — Role definitions.** One entry per role: `product`, `feasibility`,
`review`, `ops`, plus short entries for `coding` and `qa` describing them as
they exist today (via `coding-agent-rulebook`'s warrant plugin and the
`qa-agent-rulebook`), not as something to change. Each entry states: what the
role decides, what it must be given to start, what it produces, and which
failure it exists to prevent — each grounded in and citing the research
files, e.g. `product` decides value/viability risk per Cagan's product-trio
framing (product-discovery.md); `feasibility` absorbs the lead-engineer's
feasibility-risk seat in that same trio and the architecture-capability
findings from DORA (engineering-architecture.md, lifecycle-frameworks-handoffs.md);
`review` covers the security/privacy/legal/compliance gate functions
(security-legal-compliance.md) plus accessibility and design-critique
concerns (design-ux.md); `ops` covers release/deploy/reliability
(release-ops-sre.md). The design/UX role question is recorded as open: is it
its own role, or does it fold into `product`? Design-to-development handoff
is the most-reported breakage point (92%/91% dissatisfaction, design-ux.md);
UX research responsibilities are being absorbed into product roles
industry-wide (design-ux.md, 2024–2026 layoff/reassignment data). Both sides
are recorded; neither is decided here.

**Part 2 — Interaction with the user in a star topology.** Specify, per role:
how the user starts it (what they hand it — a request, a prior role's
output), how the user answers its gates (what question the role poses, what
answer unblocks it), how output reaches the next role (the user carries it —
nothing automatic, no shared file), and what happens when the user reopens a
role that already finished (it reports its own last state from its own
artifact, on its own `SessionStart`, the way `coding-agent-rulebook`'s
`state.sh` does — never from anything another role wrote). The core risk
named directly: with the user as the only router and no cross-agent
communication, the risk is the user losing track of what is current. Each
role addresses that using only what exists in its own repository: the
artifact's `status` field plus a session-start reporter that reads it back at
the moment the user opens the role, mirroring warrant's `state.sh`.

**Part 3 — State machines, one per role.** For `product`, `feasibility`,
`review`, `ops`: exact state names, every legal transition, the user input or
condition firing each transition, the rejection rule that fails an illegal
transition, and what the role refuses to do in each state — at
`coding-agent-rulebook` warrant flow's concreteness (named states, a named
artifact carrying `status`, explicit gate conditions in a `PreToolUse`-style
check). State explicitly that rejection rules bind to the target path being
written, never to which tool performs the write — mirroring warrant's
`scope-gate.sh`, which judges `tool_input`'s resolved path/command content,
not the tool name. For `coding` and `qa`: describe their existing state
machines as-is (warrant's `proposed -> approved -> landed` on
`docs/proposals/*.md`, and whatever equivalent `qa-agent-rulebook` already
runs) without proposing any change.

## Out of scope

- Any modification to `coding-agent-rulebook` or `qa-agent-rulebook`.
- Any rulebook implementation code, hook, plugin manifest, or repository
  creation.
- Any shared file, index, ledger, or cross-repository convention.
- Deciding the design/UX role question — it is recorded as open.

## How we will know it worked

The document is adequate when a reader can name every role and what it is
given and produces; can follow, for any one role, the exact states and the
user input that moves between them; and can see that nothing in it requires
editing the two existing rulebooks.
