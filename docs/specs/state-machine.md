---
status: draft
---

# ops-cycle state machine

This transcribes the `ops` role's state machine from
`docs/specs/agent-roles.md` (Part 3, tokenmaxxxer's spec repository) into
this repository's own words, so `ops-cycle` is self-contained and does not
depend on reading that repository at runtime. The mechanics below are what
`ops-cycle/hooks/state-gate.sh` and `ops-cycle/hooks/capture-approval.sh`
actually implement; if this document and the hooks ever disagree, the hooks'
behavior — verified by the smoke tests referenced below — is authoritative
and this document is the one that's stale.

## Carrying artifact and state field

**State file**: `ops/state.md`, at the root of the repository the role is
being run against (resolved via `$CLAUDE_PROJECT_DIR` when set, otherwise
`git rev-parse --show-toplevel`, otherwise the current working directory).

**State field**: the frontmatter key `status:`, one of the five state names
below.

**Other frontmatter fields the gate reads**:

- `error_budget:` — `ok` or `exhausted`. Read only to decide whether a
  release transition out of `steady` is permitted.
- `postmortem:` — a non-empty pointer (path or URL) to a filed postmortem.
  Read only to decide `incident -> steady`.

**Checklist section**: a `## Checklist` heading followed by lines of the
exact shape

```
- item: <description> | status: yes|no | artifact: <url, path, or config key>
```

read only to decide `readiness -> rollout`.

## States

`idle`, `readiness`, `rollout`, `steady`, `incident`.

## Transition table

| From | To | Fires on | Gate |
|---|---|---|---|
| `idle` | `readiness` | user hands the role a merged change plus the measurement design | none |
| `readiness` | `rollout` | checklist complete | **gated** — every checklist item resolves yes/no; every `yes` has a non-empty `artifact:` |
| `rollout` | `steady` | user's promotion approval | **gated** — a matching approval token exists (see below) |
| `steady` | `incident` | a monitored signal crosses its declared threshold | none |
| `incident` | `steady` | incident resolved, postmortem filed | **gated** — `postmortem:` is non-empty |
| `steady` | `readiness` | a new change is handed to the role | **gated, mechanically** — refused if `error_budget: exhausted` |

Any `(from, to)` pair not in this table is refused as an unknown transition.
A write that leaves `status:` unchanged is not a transition and is not
gated by this table at all (e.g. filling in checklist items while staying
in `readiness`).

## Gate rules, precisely

**`readiness -> rollout`**: refused unless the state file's `## Checklist`
section has at least one parseable item, and no item is `status: yes` with
an empty `artifact:` field. A `yes` with nothing to point at — no URL, no
file path, no config key — fails the gate exactly as `launch-readiness`
requires: "we have monitoring" with nothing to link is not a pass. Items
marked `no` never block this transition regardless of their `artifact:`
field.

**`rollout -> steady`**: refused unless `ops/tokens/promote.token` exists
and its contents name both `file: ops/state.md` and
`transition: rollout -> steady`. That token has exactly one writer:
`ops-cycle/hooks/capture-approval.sh`, a `UserPromptSubmit` hook that mints
it only when the state file's current `status` is `rollout` and the user's
own turn contains an unambiguous promotion-approval statement (an
approval/promotion verb — approve, approved, promote, "ship it", "go
live" — tied within the same sentence to "steady", "steady state", or
"production"; bare assent like "ok" or "sounds good" never mints one, even
if it happens to contain a matching word elsewhere in the turn). The token
is single-use: `state-gate.sh` deletes it immediately after allowing the
transition it covers, so one approval promotes one rollout, not every
rollout thereafter.

**`steady -> readiness` while `error_budget: exhausted`**: mechanically
refused, full stop — not advisory, not overridable by a perfect checklist
or a strongly worded request. This is the direct mechanical form of
Google's error-budget release-freeze policy: normal releases are blocked
once the trailing-window error budget is spent, and this repository has no
override path for a supposed P0/security exception — that case is a
decision for the user to route by hand (e.g. by first correcting
`error_budget:` back to `ok` once it is genuinely no longer exhausted),
never something the gate infers on its own.

**`incident -> steady`**: refused unless `postmortem:` in the frontmatter is
non-empty, naming the filed postmortem artifact.

## The path-not-tool rule

Both hooks judge the write by the resolved target path (or, for `Bash`, the
parsed target of a redirection, `tee`, `cp`/`mv`, or an in-place
`sed`/`perl`/`ruby` edit), never by which tool performed it — the same
discipline `coding-agent-rulebook/warrant/hooks/scope-gate.sh` follows. A
`Bash` command that plainly names `ops/state.md` but does not match any of
the write-shaped patterns `state-gate.sh` recognizes is treated as an
unresolved potential write and denied, not silently passed — see "Fails
closed" below.

## Fails closed

`state-gate.sh` denies, rather than allowing, on every one of these:

- The tool-call payload is not valid JSON, or is not a JSON object.
- `ops/state.md` exists but its frontmatter cannot be parsed (no opening or
  closing `---`, or no `status:` key, or a `status:` value outside the five
  known states).
- A write is identified as targeting `ops/state.md`, but the resulting
  `status:` value cannot be determined from the tool input given (e.g. a
  one-line `echo ... > ops/state.md` that does not carry the full
  frontmatter block, or an `Edit` whose `old_string` does not match the
  file's current text).
- A `Bash` command names `ops/state.md` in a shape the gate's target-path
  regexes do not recognize as a plain write.
- The resulting `(from, to)` pair is not one of the six transitions listed
  above.

`capture-approval.sh`, by contrast, never blocks: it is a `UserPromptSubmit`
hook and its only job is minting a token when the conditions are clearly
met. Malformed input, no state file, the wrong current state, or an
ambiguous prompt all mean it mints nothing and exits cleanly — the checking
half of the pattern is `state-gate.sh`'s job, not this hook's.

## Verified behavior

The gate rules above were exercised end to end during this repository's
build (not part of the committed test suite — no automated test harness
ships in this repository): `idle -> readiness` via a full-content `Write`
allowed; `readiness -> rollout` with a `yes` item carrying an empty
`artifact:` denied with the specific item named; `steady -> readiness`
denied while `error_budget: exhausted` and allowed once corrected to `ok`;
`rollout -> steady` denied with no token, allowed once
`capture-approval.sh` minted one from an explicit approval prompt, and the
token file confirmed consumed (deleted) after the allowed transition;
malformed JSON input denied.
