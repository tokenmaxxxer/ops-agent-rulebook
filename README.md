# tokenmaxxxer / ops-agent-rulebook

A Claude Code plugin marketplace for the `ops` role defined in
`docs/specs/agent-roles.md` (tokenmaxxxer's spec repository): the role that
decides whether a change may ship, and — after it ships — whether it keeps
running. This repository is fully self-contained: it shares no code, no
file, and no state with `coding-agent-rulebook`, `qa-agent-rulebook`, or any
sibling `<role>-agent-rulebook` repository, and its `.claude-plugin/marketplace.json`
names no other repository.

## What `ops` does

**Decides**: whether it may ship, and whether it keeps running, gated by
measurable reliability rather than discretionary sign-off.

**Given to start**: the merged change and the measurement design the
`feasibility` role produced. `ops` does not invent what "healthy" means; it
consumes the definition set upstream.

**Produces**: a readiness verdict backed by pointable artifacts, a rollout
plan, and — after an incident — a postmortem.

**Prevents**: shipping without a rollback path, shipping without knowing
what "healthy" means numerically, and a release proceeding once the error
budget is spent.

## The state machine

Carried in `ops/state.md` (in whatever repository this plugin is installed
against), frontmatter field `status`: `idle -> readiness -> rollout ->
steady -> incident`, with `steady -> readiness` looping back for the next
change. See `docs/specs/state-machine.md` for the full transition table,
every gate's exact rule, and the fail-closed behavior on malformed input.

Two hooks in `ops-cycle` enforce it:

- `ops-cycle/hooks/capture-approval.sh` — `UserPromptSubmit`. Mints a
  single-use approval token, bound to `ops/state.md` and the
  `rollout -> steady` transition, only from an unambiguous promotion
  approval in the user's own turn. Never blocks; mints nothing on anything
  ambiguous.
- `ops-cycle/hooks/state-gate.sh` — `PreToolUse`, matcher `.*`. Refuses
  `readiness -> rollout` unless every checklist item resolves yes/no with a
  pointable artifact on every yes; refuses `rollout -> steady` without a
  matching token; refuses `incident -> steady` without a filed postmortem;
  and mechanically refuses `steady -> readiness` whenever `error_budget:
  exhausted` is recorded — regardless of anything else being ready. The
  gate is evaluated against the resolved target path a tool is about to
  write, not against which tool performs the write, so a shell redirect,
  `tee`, `cp`/`mv`, or in-place `sed` into `ops/state.md` is judged the same
  as a `Write`/`Edit` tool call. On malformed input (bad JSON, an
  unparseable state file, an undeterminable resulting `status:`) the gate
  denies — it never falls through to allow.

## Handoff protocol

The authoritative contract is this work repo's own
`docs/specs/role-handoff-contract.md` — not any pinned excerpt or external
copy. This section describes only how the ops role behaves against
whatever contract the work repo carries; if that file is absent,
`ops-cycle/hooks/state-gate.sh` refuses handoff-protocol actions rather
than proceeding without one.

### WAKES-ON

Per contract v2 §3's `ops` row: ops wakes on a change landed (merged) that
is ready to roll out.

### READ / DEPENDS-ON / NEVER-OVERWRITE

Per contract v2 §4, replacing v1's single ACCEPTS/refuse lever — which
conflated "may ops read this" with "may ops depend on this" — with three
separate questions:

- **READ (broad).** ops may read any board record under
  `docs/reports/records/**` and any `docs/proposals/*` file, unconditionally,
  for context. Reading something is never itself a violation.
- **DEPENDS-ON (narrow).** Per contract §4's own line: "ops depends on
  `build-proposal` (what merged) and `hypothesis` / `feasibility-record`
  (the measurement design)." `ops` does not invent what "healthy" means; it
  consumes the definition set upstream.
- **NEVER-OVERWRITE.** Per contract §11's table row for `ops`, ops writes
  only `docs/reports/records/<subject>/ops.md` (`kind: ops-record`) and
  `docs/reports/records/<subject>/postmortems/<incident-slug>.md`
  (`kind: postmortem`). An existing record already at a path ops does not
  own is refused and reported to the user — never overwritten or merged
  silently (see `### STOPS` below).

### WHERE UPSTREAM LIVES

- `build-proposal`: `docs/proposals/<date>-build-<slug>.md`
- `hypothesis`: `docs/proposals/<date>-<slug>.md`
- `feasibility-record`: `docs/reports/records/<subject>/feasibility.md`

### PRODUCES

- `ops-record` at `docs/reports/records/<subject>/ops.md`, per contract §2's
  `ops-record` table row. Required fields: `loop_state`
  (`idle,readiness,rollout,steady,incident`), `error_budget:
  ok|exhausted`, `postmortem: <pointer>`, a `## Checklist` section
  (`- item: <desc> | status: yes|no | artifact: <url/path/config key>`),
  plus the common header (contract §1).

  Tension flagged, not resolved, by the contract: per contract §10,
  "`ops-record` is rewritten in place as current system state changes
  (steady, incident, error-budget), not appended to as a dated record,
  unlike the rest of `reports`." The contract states this mismatch rather
  than resolving it; this rulebook carries that note forward rather than
  silently treating `ops-record` as append-only the way
  `coding.md`/`feasibility.md`/`qa.md` are.

- `postmortem` at
  `docs/reports/records/<subject>/postmortems/<incident-slug>.md`. Required
  fields: Impact, Actions taken during response, Root cause(s), Prevention
  follow-up (owner+tracking+closing-condition), Review (named human
  reviewer).

### FINDING BACK-EDGE

Per contract v2 §5, ops may both produce and receive `finding` blocks. When
ops closes a finding addressed to it (`addressed_to: ops`), its
`ops-record` write must carry a `finding-response` entry containing: the
finding reference (record path plus finding identifier), the action taken
or, if declined, the reason for declining, and — when a fix changed
something — proof of the fix (commit sha, targeted re-run result, or
equivalent). An entry missing any of these three parts does not close the
finding, per contract §5's own completeness rule.

### LOOP TERMINATION

Per contract v2 §6: a wake ops observes is consumed only by writing the
resulting `ops-record` entry (a `loop_state` change, a new `finding`, or a
`finding-response`); an unchanged board wakes no one, so a wake that
produces no board change is not a valid consumption of it.

### STOPS

- Upstream stale at role entry (contract §12): the recorded `sha` for
  whichever of `build-proposal`/`hypothesis`/`feasibility-record` was read
  no longer matches that path's current `sha`. Stop before further work;
  ask the user to proceed on the recorded version or re-confirm against
  current.
- An existing record already at a path ops does not own under
  `docs/reports/records/` (contract §11): refuse to write, report the
  conflict (path and whose territory it falls in) to the user — never
  overwrite or merge in silently.

## Install

```
curl -fsSL https://raw.githubusercontent.com/tokenmaxxxer/ops-agent-rulebook/main/install.sh | bash
```

This registers ONLY the `tokenmaxxxer-ops` marketplace and installs ONLY
this repository's plugins — `ops-cycle` and the `ops-agent-env` bundle — at
**user scope**. It applies to your account on every machine-local session;
it does not travel with a repo and does not reach Claude Code on the web or
Slack cloud sessions. `install.sh` writes nothing to the repo it's run
from: no `.claude/settings.json` at a repo root, and no `SessionStart` hook.

The script prefers a real `claude` CLI (standalone, or the binary bundled
inside the VSCode extension) if it finds one, and runs
`plugin install <name>@tokenmaxxxer-ops --scope user` for `ops-cycle` plus
the bundle, then updates each to the marketplace's latest. If no `claude`
binary is found — or `TOKENMAXXXER_SETTINGS_ONLY=1` is set to force it —
the script falls back to writing `~/.claude/settings.json` directly: it
resolves and prefix-checks the settings path against `$HOME` before any
write, merges in the marketplace declaration and enables the bundle,
preserves any existing keys, writes a `.bak` before touching an existing
file, follows a symlink at that path rather than replacing it, and aborts
leaving the original file untouched if it already exists but fails to
parse as JSON. Either path installs the same bundle the same way.

`install.sh --help` prints usage. The only other input it reads is the
`TOKENMAXXXER_SETTINGS_ONLY=1` environment variable described above.

Or, from any Claude Code session, the equivalent by hand:

```
/plugin marketplace add tokenmaxxxer/ops-agent-rulebook
/plugin install ops-agent-env@tokenmaxxxer-ops
```

One interactive step remains after either path: open `/plugin` ->
marketplaces -> tokenmaxxxer-ops and enable **auto-update**, so future stack
additions arrive automatically (there is no CLI switch for this toggle).
Verify with `/plugins`.

## Writing the settings by hand

If you'd rather not run the installer, the minimum to declare by hand is
the marketplace plus the `ops-agent-env` bundle — its dependency resolves on
the next CLI install. This is also exactly what `install.sh`'s CLI-less
fallback writes:

```json
{
  "extraKnownMarketplaces": {
    "tokenmaxxxer-ops": {
      "source": { "source": "github", "repo": "tokenmaxxxer/ops-agent-rulebook" }
    }
  },
  "enabledPlugins": {
    "ops-agent-env@tokenmaxxxer-ops": true
  }
}
```

## Plugins

| Plugin | What it does |
|---|---|
| [ops-cycle](ops-cycle/) | The `ops` role's state machine: readiness, rollout, steady, incident — gated by a checklist-with-artifact rule, a human approval token, a filed postmortem, and a mechanical error-budget release freeze. Ships a `readiness-checklist` skill for working the state file in the shape the gate expects. |
| [ops-agent-env](ops-agent-env/) | One-install bundle: pulls in `ops-cycle` as a dependency. Contains no code of its own. |

## Repo layout

- `install.sh` — the one-shot installer described above.
- `.claude-plugin/marketplace.json` — the marketplace manifest; every plugin
  `source` is `./`-relative to this repository.
- `ops-cycle/` — the role plugin: `.claude-plugin/plugin.json`,
  `hooks/hooks.json`, the two hook scripts, and `skills/`.
- `ops-agent-env/` — the bundle plugin: `.claude-plugin/plugin.json` only.
- `docs/` — lifetime-bucketed documentation (`decisions/`, `handbooks/`,
  `reports/`, `specs/`, `proposals/`, `_assets/`), matching the layout
  `coding-agent-rulebook` and `qa-agent-rulebook` use.

## Relationship to the rest of the org

This repository does not read, depend on, or reference
`coding-agent-rulebook`, `qa-agent-rulebook`, or any other
`<role>-agent-rulebook` sibling at install time or at runtime. The user
carries artifacts between roles by hand, per
`docs/specs/agent-roles.md`'s "Carrying output forward" — nothing here
automates that handoff.
