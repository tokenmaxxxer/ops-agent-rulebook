---
loop_state: landed
upstream: docs/issue-36/proposals/2026-08-01-gate-a-plus-remediation.md
---

# Implementation record — issue #36

## What was done

Executed the approved proposal's four items against
`readiness-checklist/hooks/readiness-fields-gate.sh`:

1. **Migrated to core's gate-lib.sh/gate-lib.py** (core issue #72, landed:
   `tokenmaxxxer-core` commit `5550961`). The gate now sources
   `${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh`
   (identical resolution depth to `ops/hooks/directive.sh`'s own
   `role-directive.sh` precedent — no new convention invented) and calls:
   - `gate_trap_fail_closed` in place of the hand-rolled `trap __fc EXIT`.
   - `gate_kill_switch_active` in place of the
     `case ... in ""|0|false|no|off) ;; *) exit 0 ;; esac` block. This
     flips the confirmed bug: only a recognized on-spelling
     (`1`/`true`/`yes`/`on`, case-insensitive) now disables the gate;
     empty, a recognized off-spelling, or any unrecognized value (a typo)
     all stay active.
   - `gate_lib.gate_parse_json_or_deny` in place of the hand-rolled
     `try/except ValueError` + `isinstance` pair.
   - `gate_lib.gate_normalize_path` in place of the realpath/cwd-dependent
     `resolve()` — pure root-relative-tail computation; `root` itself is
     still realpath'd once from `cwd`/`CLAUDE_PROJECT_DIR`, matching
     `gate_normalize_path`'s documented contract.
   - `gate_lib.gate_reconstruct_write` in place of the gate's own
     `.replace(o, n, 1)` calls for `Write`/`Edit`/`MultiEdit` — the direct
     fix for the `replace_all`-ignored defect; `MultiEdit` now honors each
     edit's own `replace_all` flag independently.
2. **Section/adjacency-scoped semantic check** (this gate's own logic —
   not a shared `gate-lib` primitive). Checklist items are now matched
   only within the contiguous block from the first
   `(?m)^##\s*Checklist\s*$` heading to the next `(?m)^##\s` heading or
   end-of-file, via a bounded substring search rather than
   `re.findall` over the whole `new_text`. An `- item:`-shaped line
   outside that block (e.g. under `## Appendix`) is ignored, not admitted
   as a real checklist entry. A candidate file with no `## Checklist`
   heading at all now denies explicitly ("no `## Checklist` section at
   all") rather than falling through to the generic no-items message.
3. **Test additions** — `readiness-checklist/hooks/tests/allow-deny-check.sh`
   extended from 4 cases (all `Write`) to 14, adding every issue-mandated
   shape: an `Edit` case (reconstructed content judged, not the tool's
   naive default), a `MultiEdit` case mixing `replace_all: true/false` in
   one call, two malformed-JSON cases (truncated JSON, top-level array),
   a kill-switch unrecognized-value case (`READINESS_FIELDS_GATE_OFF=disabled`
   stays active) alongside the recognized-on case, an absolute-`file_path`
   case and a `./`-prefixed case (both resolving to the same scope as the
   relative-path fixtures), and two section-scoping cases (a stray
   item-shaped line outside `## Checklist` is ignored; a file with no
   `## Checklist` heading at all denies).
4. **README hygiene.** No ghost-file references existed in this plugin's
   own docs (survey already confirmed this); `SKILL.md` never described
   the kill switch's behavior, so it needed no change. The repo README's
   `## What is here` section, however, was found stale beyond the
   readiness-checklist scope during execution: it described
   `proposal-fields-gate.sh` and `rollout-plan-fields-gate.sh` as living
   under `ops/hooks/`, when both are now separate top-level plugins
   (`proposal-norm/hooks/`, `rollout-plan/hooks/`) with no `ops/hooks/`
   copies, and it named a repo-wide `OPS_CYCLE_OFF` kill switch that does
   not exist (each plugin has its own `*_GATE_OFF`). Rewrote that section
   to list all six real plugins, their real gate paths, and their real
   kill-switch names (including `READINESS_FIELDS_GATE_OFF`'s corrected
   behavior), and updated "Run the checks" to include
   `compliance-check.sh readiness-checklist/hooks` and the extended
   `allow-deny-check.sh`. Left `rollout-plan`/`error-budget-policy`/
   `postmortem`/`proposal-norm`'s own gates untouched — those still hand-roll
   the same kill-switch/reconstruction shapes readiness-fields-gate.sh had,
   but fixing them is out of this issue's stated scope (readiness-fields-gate.sh
   only) and not raised here as a new finding beyond noting it for a future
   issue.

## Why

Issue #36's own 2026-08-01 audit (graded B+) confirmed four defect
classes by direct read: kill-switch fail-open on any unrecognized value
(the identical shape core's own pre-issue-72 bug had), `Edit`/`MultiEdit`
ignoring `replace_all`, the semantic check scanning the whole file instead
of the `## Checklist` section, and cwd/realpath-dependent path resolution
with no pure normalize layer. Core issue #72 landed the shared fix
specifically so downstream rulebooks reference it rather than
re-deriving their own version of each shape (`docs/handbooks/
gate-house-standard.md` in `tokenmaxxxer-core`) — issue #36's own
precondition named this as done and mandatory to adopt, and it is now
confirmed merged to core's main (`tokenmaxxxer-core` PR #74).

## Verification

- `readiness-checklist/hooks/tests/allow-deny-check.sh`: all 14 cases
  green (`CLAUDE_PLUGIN_ROOT_CORE` pointed at the landed core checkout,
  commit `5550961`).
- `core/hooks/tests/compliance-check.sh readiness-checklist/hooks`: `ok`
  — no hand-rolled kill-switch, no hand-rolled `replace_all`-ignoring
  reconstruction detected.
- Full plugin test suite re-run clean after the change: `tests/parse-check.sh`,
  `tests/deny-only-check.sh`, and every plugin's own
  `hooks/tests/allow-deny-check.sh` (readiness-checklist: 14/14,
  rollout-plan: 3/3, error-budget-policy: 3/3, postmortem: 2/2,
  proposal-norm: 4/4) — all green, no regression from the migration or
  the README rewrite.
- Manual review of the section-scoped regex change: the stray-item and
  no-heading fixture cases in `allow-deny-check.sh` directly exercise and
  confirm the `## Checklist`-block boundary rejects outside-block matches.

## Open findings

None outstanding against this issue's stated scope. Noted but explicitly
out of scope: `rollout-plan-fields-gate.sh`, `error-budget-gate.sh`,
`postmortem-review-gate.sh`, and `proposal-fields-gate.sh` still hand-roll
kill-switch and content-reconstruction logic with the same shapes
`readiness-fields-gate.sh` had before this migration — a natural
follow-up issue, not raised here as a blocking finding since issue #36's
audit and remediation ask named only `readiness-fields-gate.sh`.
