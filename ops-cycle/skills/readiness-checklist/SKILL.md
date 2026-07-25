---
name: readiness-checklist
description: >-
  Use when working the ops role's readiness or rollout state (ops/state.md
  status: readiness, or preparing to promote rollout -> steady, or closing
  an incident back to steady). Walks the launch-readiness discipline this
  role is built on: every checklist item resolves to yes/no backed by a
  pointable artifact, never "we have monitoring" with nothing to link.
  Also covers the exact wording state-gate.sh (PreToolUse) and
  capture-approval.sh (UserPromptSubmit) require, so edits to ops/state.md
  pass the gate on the first try instead of being refused and retried.
  Do NOT use for writing the specification or feasibility work upstream of
  ops — this is scoped to readiness, rollout, steady, and incident only.
---

# readiness-checklist — the ops role's gate, worked from the inside

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

## Working `rollout -> steady`

Gated on a human approval token this skill cannot mint for you — only
`ops-cycle/hooks/capture-approval.sh` mints it, and only from an
unambiguous statement in the user's own turn (e.g. "I approve promoting
this to steady state", "approved for production"). A bare "ok" or "looks
good" does not mint a token — state the approval explicitly, naming
"steady" or "production" alongside an approval/promotion verb. If you are
the agent and need this transition, say so to the user and ask them to
state the approval themselves; do not write `status: steady` and hope —
the gate checks for `ops/tokens/promote.token` and denies without it.

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
threshold; nothing here gates that direction. Closing back,
`incident -> steady`, requires a non-empty `postmortem:` field in
`ops/state.md`'s frontmatter naming the filed postmortem (a path under
`docs/reports/`, following the `blameless-postmortem` discipline). Write
the postmortem first, then close the loop.
