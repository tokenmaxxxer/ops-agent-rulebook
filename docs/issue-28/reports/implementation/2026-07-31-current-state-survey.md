---
name: issue-28-current-state-survey
subject: issue-28
role: implementation
---

# Current-state survey — issue #28

Scope: this repo (`release-engineering-rulebook`, role `ops`) as it stands
today, against core canon that landed via core issue #63 (warrant-hunt
plugin) and core issue #66 (role-agnostic gates + `role-directive.sh`).
Canon source checked at `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core`
(main), commits `130cb13`/`2fd1fcb` (both merged; issue-63/66 worktrees
under `~/.tokenmaxxxer/work/` are stale copies of the same merged state).

Scouting skipped: this issue is a scoped mechanical reference-swap dictated
entirely by an already-landed upstream canon (core #63/#66) with no open
design choice left to this repo — spec-leaves-no-decision skip condition.

## Item 1 — warrant-hunter copy

`grep -r "warrant\|hunt"` across this repo finds no `agents/warrant-hunter.md`,
no hunt-cadence directive text, and no `agents/` directory at all. This repo
never carried a warrant-hunter copy (other rulebooks — coding-, product-,
feasibility-, review-agent-rulebook — did; this one, `ops`/release-engineering,
did not). **Item 1 is not applicable to this repo** — nothing to remove.

## Item 2 — gate copies and their registrations

Present, vendored, and registered in `ops/hooks/hooks.json`:
- `ops/hooks/trailer-gate.sh` (PreToolUse, `Bash`)
- `ops/hooks/record-fields-gate.sh` (PreToolUse, `Write|Edit|MultiEdit|NotebookEdit`)
- `ops/hooks/handbook-trigger-gate.sh` (PreToolUse, `Bash`)

All three are diffed against core's `core/hooks/{trailer,record-fields,handbook-trigger}-gate.sh`
and are functionally-equivalent-or-narrower reimplementations: same
fail-closed shell+Python two-layer structure, same §13/§20/§21 contract
citations, same root-resolution heuristic. Concrete drift found:
- Core's `handbook-trigger-gate.sh` derives its error-message role prefix
  from `CLAUDE_ROLE` and has a wider operational-surface pattern set
  (adds CI workflow / k8s-deploy-manifest / broader manifest-basename
  matching); this repo's copy hardcodes the `ops-cycle:` prefix and a
  narrower pattern list. Core's canon promotion note explicitly calls out
  that vendored copies had drifted on this exact prefix issue in another
  rulebook — the same drift class exists here, just not yet triggered.
- `core/hooks/hooks.json` already registers all three gates globally per
  plugin install (`${CLAUDE_PLUGIN_ROOT}/hooks/<name>.sh`), so once this
  repo's plugin depends on core, this repo's own `hooks.json` entries for
  these three are pure duplication (double-firing, not just dead code).

`core/hooks/tests/stub-check.sh` exists and is the verification harness for
item 3 (see below); it also independently checks (as part of its job) that
no vendored copy of the 4 canon gate filenames remains under a rulebook's
`hooks/` tree.

## Item 3 — directive.sh stub shape

`ops/hooks/directive.sh` (75 lines) is NOT a stub: it hand-rolls the kill
switch (`OPS_CYCLE_OFF`), the `CLAUDE_ROLE` guard, and the entire heredoc
body inline — none of it sources `core/hooks/lib/role-directive.sh` or
calls `core_role_directive`. Canon's expected shape (confirmed by reading
`core/hooks/lib/role-directive.sh` directly):

```bash
#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
core_role_directive "YOU DECIDE: ..." "USE WHEN: ..." "PRODUCES: ..." "HAND-OFF: ..."
```

`core_role_directive` signature: `core_role_directive <you_decide> <use_when> <produces> <hand_off>`
(4 positional content strings). It reads `CLAUDE_ROLE` itself (no-op if
unset), applies the `<ROLE_UPPER>_CYCLE_OFF=1` kill switch itself (role
name uppercased via `tr`, bash-3.2-safe), and emits the `[${role}] Role
directive...` heredoc plus a fixed `RECORD: docs/issue-<n>/reports/${role}.md,
phase-gated per contract v3 s19` footer — this repo's current
`RECORD REQUIREMENTS` paragraph in `directive.sh` duplicates that footer's
substance by hand.

`stub-check.sh`'s structural check (confirmed by reading the script) fails
any `directive.sh` whose non-blank/non-comment/non-shebang lines are
anything other than: the `role-directive.sh` source line, the
`core_role_directive` call, or a plain `VAR=value` assignment. The current
`ops/hooks/directive.sh` — with its `trap`, `case` guard, `cat <<'DIRECTIVE'`
heredoc, and inline `[ "${CLAUDE_ROLE:-}" = "ops" ]` check — fails every one
of those clauses.

## Item 4 — role-specific real difference: record-fields terminal states

`ops/hooks/record-fields-gate.sh` hardcodes `TERMINAL = {"steady", "idle"}`
for this role's `loop_state`, diverging from core's documented default
(`RECORD_FIELDS_TERMINAL_STATES` env var, default `"landed"`, space-separated
set, confirmed present in core's `record-fields-gate.sh` and read into a
Python `TERMINAL` set). This is the one genuine role-specific behavioral
difference the issue's item 4 anticipates, and core's gate already exposes
the exact override mechanism needed to preserve it without a vendored copy.

`ops/hooks/directive.sh`'s own body content (the `YOU DECIDE` /
`RESEARCH` / `CURRENT-STATE SURVEY` / `PROPOSAL` / `EXECUTION JUDGMENT`
paragraphs) is role-specific and must be preserved, remapped into the
`core_role_directive` call's four positional arguments.

## Item 5 — stub-check verification

Not yet run against this repo (nothing to check pre-migration — the current
`directive.sh` is known-failing by inspection above, and the three gate
files are known-present vendored copies by inspection above). Running
`core/hooks/tests/stub-check.sh` against `ops/` post-migration, and
recording the result, is phase-2 work per item 5 of the issue.

## Summary of the write surface for phase 2

- Delete: `ops/hooks/trailer-gate.sh`, `ops/hooks/record-fields-gate.sh`,
  `ops/hooks/handbook-trigger-gate.sh`.
- Edit: `ops/hooks/hooks.json` — drop the three now-core-owned
  `PreToolUse` entries (core's own `hooks.json` fires them per plugin
  install); confirm what, if anything, this repo's plugin manifest needs
  to declare a dependency on core (existing `.claude-plugin/` wiring, not
  yet inspected — phase-2 concern, since it is execution not proposal).
- Rewrite: `ops/hooks/directive.sh` as a canon stub sourcing
  `core/hooks/lib/role-directive.sh` and calling `core_role_directive`
  with the four preserved role-specific strings, plus a
  `RECORD_FIELDS_TERMINAL_STATES="steady idle"` assignment for item 4
  (a plain `VAR=value` line, allowed by `stub-check.sh`'s structural
  check).
- Verify: run `core/hooks/tests/stub-check.sh` against `ops/hooks/` and
  record the result per item 5.
