---
name: readiness-checklist
description: >-
  Use when working the ops role's readiness state (ops/state.md status:
  readiness), preparing to move readiness -> rollout, or checking what
  state-gate.sh (PreToolUse) requires before a write to ops/state.md will
  pass. Walks the launch-readiness discipline this role is built on: every
  checklist item resolves to yes/no backed by a pointable artifact, never
  "we have monitoring" with nothing to link. There is no approval-token
  mechanism here — actor: user rows are satisfied by the model reading the
  user's own turn and judging the precondition met, not by minting or
  checking a token.
  Do NOT use for writing the specification or feasibility work upstream of
  ops — this is scoped to readiness, and to the readiness-adjacent parts of
  rollout, steady, and incident only.
---

# readiness-checklist — the ops role's gate, worked from the inside

Belongs to the `readiness` state. Asks the user, dimension by dimension,
whether each of the seven Production Readiness Review (PRR) items is
satisfied and — for every "yes" — what the pointable artifact is (a
dashboard URL, a config key, a runbook path). Writes the checklist into
`ops/state.md`'s `## Checklist` section, the file this plugin's `readiness
-> rollout` transition is gated on.

The seven dimensions (converged open-source PRR shape, `docs/reports/
research/2026-07-27-role-practice/ops.md`):

1. Service Levels — is the SLO/SLI defined?
2. Architecture Design Review — has the design been reviewed?
3. Performance — has it been load-tested?
4. Documentation — does a runbook exist?
5. Observability — do dashboards/alerts exist?
6. Testing — has failure-injection been done?
7. Deployment Strategy — is a rollback path defined?

This role's state machine (`docs/specs/state-machine.md`) is enforced
mechanically by two hooks in this plugin, not by judgment calls. This skill
is the operator's-eye view of what those hooks actually check, so the state
file gets written in a shape that passes the gate instead of bouncing off it.

## The state file

`ops/state.md`, at the repository root the role is being run against.
Frontmatter carries the state field:

```markdown
---
status: readiness      # idle | readiness | rollout | steady | incident
error_budget: ok        # ok | exhausted — read only while status: steady
postmortem: docs/reports/2026-07-25-incident-x.md   # only while closing incident -> steady
---
```

Below the frontmatter, a `## Checklist` section holds one line per item,
in this exact shape (the gate's regex is strict about it):

```
- item: <what is being checked> | status: yes | artifact: <url, path, or config key>
- item: <what is being checked> | status: no | artifact:
```

A `no` item is fine — it just means the transition isn't ready yet. A
`yes` item with an empty `artifact:` field is what fails the gate: per
`launch-readiness`, "we have monitoring" with nothing to link is not a
pass. Point at something real: a dashboard URL, a runbook path, a config
key, a file in this repo.

## Working `idle -> readiness`

Opened when the user hands the role a merged change plus the measurement
design `feasibility` produced (`docs/specs/agent-roles.md`, ops: "given to
start"). Write `ops/state.md` with `status: readiness` and start filling in
checklist items — this transition itself is not gated by anything beyond
existing.

## Working `readiness -> rollout`

Gated: every checklist item must resolve yes/no, and every yes needs a
real artifact. Before flipping `status: rollout`, re-read the whole
checklist section and ask, for each `yes`: does the `artifact:` field name
something a stranger could actually open? If not, it is not a yes yet —
mark it `no` and keep working it, or fill in the real pointer.

If `state-gate.sh` refuses the transition, its stderr names the exact item
that failed and why — fix that item's `artifact:` field (or flip it to
`no`) and retry; do not attempt to route around it by writing through Bash
redirection with a different form — the gate reads the target path for any
tool, so that produces the same refusal.

## Working `readiness -> rollout`, and `rollout`'s own agent-owned steps

Once every checklist item resolves and every `yes` has a real artifact, the
agent moves itself to `rollout` — no human gate on this step. From there,
`rollout -> rollout` (canary step promotion on a clean metric check) and
`rollout -> incident` (breach past a hard pre-set threshold) are both
`actor: agent` rows the `rollout-plan` skill's declared thresholds drive
mechanically. See `ops-cycle/skills/rollout-plan/SKILL.md`.

## Working `rollout -> steady`

There is no approval-token mechanism. This transition is `actor: user`: it
may only be taken once the user has said something in their own turn that
unambiguously states the promotion approval (e.g. "I approve promoting this
to steady state", "approved for production"). A bare "ok" or "looks good"
is not enough — if the user's turn is vague, ask them to state the
approval explicitly, naming "steady" or "production" alongside an
approval/promotion verb, rather than writing `status: steady` on a guess.
Before writing `ops/state.md`, record which of the user's own utterances
you read as satisfying this precondition — the injected transition rules
require this record as a line in the state file; nothing enforces it
mechanically, so do it because the row's `actor: user` designation depends
on it having actually happened.

## Steady state and the error budget

While `status: steady`, the `error_budget:` field is read mechanically
before any transition back toward a release (`steady -> readiness`,
i.e. picking up a new change). If it reads `exhausted`, that transition is
refused outright — not a suggestion, a hard denial — regardless of how
ready the next change looks. Per Google's error-budget policy this
mirrors: only P0/security-fix work proceeds while the budget is spent; the
mechanical check here does not carve that exception in automatically, so
route a true P0 through the user rather than editing the field to `ok`
to unblock it — that would be lying to the gate about a state that isn't
true.

## Closing an incident

`steady -> incident` fires on a monitored signal crossing its declared
threshold; nothing here gates that direction. Closing back to `steady` is
`actor: user` and requires more than a filled-in field: the postmortem
(`ops-cycle/skills/postmortem/SKILL.md`) must be filed *and* the user must
say, in their own turn, that a human reviewer has reviewed it and is
satisfied with the document and its action items — Google's own rule is
that "an unreviewed postmortem might as well never have existed," so a bare
non-empty `postmortem:` field is not sufficient on its own. `incident ->
readiness` is a separate, later `actor: user` row: postmortem action-item
sign-off specifically gates re-entry into a release cycle for the affected
surface, distinct from the general close.
