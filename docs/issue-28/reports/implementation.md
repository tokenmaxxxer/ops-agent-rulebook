---
loop_state: landed
upstream: docs/issue-28/proposals/2026-07-31-core-canon-reference-switch.md
---

# Implementation record — issue #28

## What was done
Executed the approved proposal's five items in one batch:

1. **Item 1 (warrant-hunter copy)** — confirmed not applicable, as the
   survey found: no `agents/warrant-hunter.md` and no hunt-cadence text
   exist in this repo.
2. **Item 2 (gate copies + registrations)** — deleted
   `ops/hooks/trailer-gate.sh`, `ops/hooks/record-fields-gate.sh`,
   `ops/hooks/handbook-trigger-gate.sh`, and their three `PreToolUse`
   entries from `ops/hooks/hooks.json`, which now only registers
   `SessionStart` → `directive.sh` (core's own `hooks.json` fires all
   three gates globally per plugin install).
3. **Item 3 (directive.sh stub)** — rewrote `ops/hooks/directive.sh` to
   source `core/hooks/lib/role-directive.sh` and call
   `core_role_directive` with the four role-unique strings (YOU DECIDE /
   RESEARCH+CURRENT-STATE SURVEY / PROPOSAL / EXECUTION JUDGMENT),
   carried over verbatim from the prior heredoc body per the proposal's
   4-argument remapping. `ops/.claude-plugin/plugin.json` gained a
   `dependencies` note documenting the core/warrant plugin requirement
   (matching the pattern already landed in sibling rulebooks, e.g.
   `brand-design`).
4. **Item 4 (role-specific terminal states)** — set
   `RECORD_FIELDS_TERMINAL_STATES="steady idle"` as a plain assignment
   in the stub, preserving this role's actual terminal set (vs. core's
   default `"landed"`).
5. **Item 5 (stub-check verification)** — ran
   `core/hooks/tests/stub-check.sh ops/hooks` (core repo at
   `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core`, commit `2fd1fcb`):
   all five checks passed — no vendored copy of any of the four
   canon-gate filenames remains under `ops/hooks/`, and `directive.sh`
   parses as a valid role-directive stub.

Additional cleanup discovered while executing item 2: `tests/run-gate-tests.sh`
directly invoked the now-deleted `record-fields-gate.sh` and
`trailer-gate.sh` by path and would have failed outright once those files
were removed. Deleted it (its coverage is superseded by core's own
`run-role-gates-tests.sh`) and updated `README.md`'s "Run the checks"
section to drop the reference and point at `stub-check.sh` instead.
Re-ran `tests/parse-check.sh` and `tests/deny-only-check.sh` after all
edits — both still pass (`deny-only-check` reports "no gate scripts under
ops/hooks", which is correct post-migration, not a regression).

## Why
Core canon for warrant-hunt (core #63) and the three role-agnostic gates
plus `role-directive.sh` (core #66) has landed and is merged to core
main. Keeping this repo's vendored gate copies registered alongside
core's own global registration would double-fire every gate, not just
carry dead code; keeping `directive.sh` hand-rolled would leave this
repo exposed to exactly the copy-paste drift core #66's survey already
found across other rulebooks (e.g. the hardcoded `ops-cycle:` prefix vs.
core's `CLAUDE_ROLE`-derived one). The terminal-states override exists
because this role's actual terminal `loop_state` set (`steady`, `idle`)
genuinely differs from core's default (`landed`) — a real per-role
difference, not accidental drift, so it stays as explicit configuration
per the proposal rather than being silently collapsed. `loop_state:
landed` is used for this record's own frontmatter (rather than `steady`)
because this record itself is written before the new
`RECORD_FIELDS_TERMINAL_STATES` value takes effect (it only loads at the
next `SessionStart`), so the currently-active gate still checks against
its own default terminal set.

## Verification
`core/hooks/tests/stub-check.sh ops/hooks` — all 5 checks `ok` (no
vendored `trailer-gate.sh`/`record-fields-gate.sh`/
`handbook-trigger-gate.sh`/`parse-check.sh`; `directive.sh` is a valid
role-directive stub). `tests/parse-check.sh` and `tests/deny-only-check.sh`
still pass post-migration.

## Open findings
None outstanding. The proposal's "what phase 2 will not decide
unilaterally" item (plugin-manifest dependency wiring) was resolved
during execution: `ops/.claude-plugin/plugin.json` now carries a
`dependencies` note matching the pattern already in place for other
migrated rulebooks (e.g. `brand-design`); actual install-time wiring of
the core/warrant plugins is an `on-the-record` concern per that note, not
this repo's.
