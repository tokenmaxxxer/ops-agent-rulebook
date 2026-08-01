---
loop_state: idle
---

# Proposal — gate A+ remediation for `readiness-fields-gate.sh` (issue #36)

Upstream survey: `docs/issue-36/reports/release-engineering/2026-08-01-current-state-survey.md`.

## Why (per issue #36's own audit)

The 2026-08-01 audit graded this repo B+ on four confirmed defect classes,
all verified by direct read in the survey: kill-switch fail-open on any
unrecognized value (identical shape to core's own pre-issue-72 bug),
`Edit`/`MultiEdit` ignoring `replace_all`, the semantic check scanning the
whole file for `- item:` lines instead of the `## Checklist` section, and
cwd/realpath-dependent path resolution with no pure normalize layer.
Core issue #72 landed the shared fix (`gate-lib.sh`/`gate-lib.py`,
`docs/handbooks/gate-house-standard.md`, `compliance-check.sh`,
`run-gate-lib-tests.sh`) specifically so downstream rulebooks reference it
rather than re-deriving their own version of each shape — issue #36's own
precondition names this as done and mandatory to adopt.

## What (phase-2 execution plan — proposal only, no code changes this phase)

### 1. Migrate `readiness-fields-gate.sh` to source `gate-lib.sh`/`gate-lib.py`

- Replace the hand-rolled `trap __fc EXIT`/`__fc` pair with
  `gate_trap_fail_closed` from `gate-lib.sh`, sourced as:
  `. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)}/../core/hooks/lib/gate-lib.sh"`
  (exact resolution path confirmed at execution time against how sibling
  plugins in this repo already reference core, per
  `ops/hooks/directive.sh`'s precedent — no new resolution convention
  invented here).
- Replace the `case "${READINESS_FIELDS_GATE_OFF:-}" in ...` block with
  `gate_kill_switch_active "${READINESS_FIELDS_GATE_OFF:-}" || { trap -
  EXIT; exit 0; }` — flips the bug so only a recognized on-spelling
  (`1`/`true`/`yes`/`on`) disables; empty, a recognized off-spelling, or
  any unrecognized value all stay active.
- In the Python heredoc: parse via `gate_lib.gate_parse_json_or_deny(raw,
  deny)` instead of the hand-rolled `try/except ValueError` + `isinstance`
  pair (loaded via the `GATE_LIB_PY`/`importlib.util` pattern
  `gate-lib.sh` exports — see its usage header).
- Replace `resolve()` with `gate_lib.gate_normalize_path(root, path)` for
  the pure root-relative-tail computation; keep `os.path.realpath` only
  for computing `root` itself once (matching `gate_normalize_path`'s
  documented contract that callers needing symlink-safety realpath their
  own root before calling it — the function itself stays filesystem-free,
  which is what makes the mandatory absolute-path/`./`-prefixed test cases
  below runnable without a real fixture tree).
- Replace the `Write`/`Edit`/`MultiEdit` content-reconstruction block with
  `gate_lib.gate_reconstruct_write(tool, tool_input, current_content)`,
  removing this gate's own `.replace(o, n, 1)` calls entirely. This is the
  direct fix for defect #2 (`replace_all` ignored) — the shared function
  honors each edit's own `replace_all` flag independently for `MultiEdit`.
- Replace the two `deny(...)`/implicit-allow exit points with
  `gate_lib`-equivalent `gate_deny`/`gate_allow` semantics where the bash
  layer calls them (the Python-side `deny()` local helper may stay as a
  thin wrapper calling `sys.stderr.write` + `sys.exit(2)`, since
  `gate_deny`/`gate_allow` are documented as bash-side calls in
  `gate-lib.sh`'s usage header — execution phase confirms which side of
  the bash/Python boundary each call belongs on and does not invent a
  third convention).

### 2. Fix the section/adjacency scoping (defect #3 — not a gate-lib function, this gate's own logic)

`gate-lib.sh`/`gate-lib.py` do not ship a "find the `## Checklist` section"
helper — that check is specific to this gate's own state-machine shape,
not a shared cross-rulebook primitive core canonized. The fix stays local:
require the `- item:` lines matched to fall within the contiguous block
starting at the first `(?m)^##\s*Checklist\s*$` heading and ending at the
next `(?m)^##\s` heading or end-of-file, rather than `re.findall` over the
whole `new_text`. Any `- item:`-shaped line found outside that block is
ignored, not silently admitted as a real checklist entry.

### 3. Mandatory test additions (issue #36 item 3, and core's six-case harness as the floor)

Extend `readiness-checklist/hooks/tests/allow-deny-check.sh` (or add a
sibling fixture file, decided at execution time by whichever keeps the
existing 4 cases least disrupted) with, at minimum:

- `Edit` case: `old_string` occurs multiple times in current content,
  `replace_all: true` in the tool call, asserting the gate judges the
  *fully* replaced content (i.e., correctly denies/allows based on what
  the real edit would produce, not just the first occurrence).
- `MultiEdit` case: a mix of `replace_all: true` and `replace_all: false`
  edits in one call.
- Malformed-JSON case: truncated JSON, and a non-object top level (e.g. a
  JSON array), both expected to deny (rc=2).
- Kill-switch case: `READINESS_FIELDS_GATE_OFF` set to an unrecognized
  value (e.g. a typo like `"1 "` or `"disabled"`), asserting the gate
  stays **active** (does not silently allow through unconditional
  `exit 0`).
- Absolute-path case: same target (`ops/state.md`) reached via an absolute
  `file_path`, and a `./`-prefixed variant, both matching the same scope a
  relative-path fixture already matches.
- Section-scoping case (this gate's own addition, not from core's generic
  six): a state file containing a `- item: ... | status: yes | artifact:`
  line *outside* the `## Checklist` block, asserting it is NOT treated as
  a real checklist item.

Additionally, per core's own standard, run a copy of
`core/hooks/tests/run-gate-lib-tests.sh`'s six-case shape adapted to this
gate (the items above already satisfy cases 1-5 of that shape; case 6,
"a `Bash`-tool file write reaching the same target," decided at execution
time — `readiness-fields-gate.sh`'s `hooks.json` matcher is currently
`Write|Edit|MultiEdit` only, with no `Bash` matcher; adding `Bash`-write
coverage is only in scope if the gate's matcher itself gains `Bash`,
which is a scope question for execution, not proposed here as a foregone
conclusion).

Full suite green at delivery time (issue #36 item 3's "배송 상태에서 전
스위트 green"), including running
`core/hooks/tests/compliance-check.sh readiness-checklist/hooks` clean as
the direct equivalent of issue-28's `stub-check.sh` verification step.

### 4. README/SKILL.md hygiene (issue #36 item 4)

Survey found no ghost-file references in this plugin's own docs already.
The one required update: `readiness-checklist/skills/readiness-checklist/SKILL.md`
and any README text describing `READINESS_FIELDS_GATE_OFF`'s behavior must
be re-worded to match the corrected kill-switch semantics (unrecognized
value now stays active, not disables) once the migration lands — a
behavioral-accuracy fix, not a file-existence one.

## What this proposal does NOT decide

- The exact bash-line-for-line diff of `readiness-fields-gate.sh` — left
  to phase-2 execution, bounded by the function-for-function mapping
  above (no re-derivation of any `gate_*` shape core already owns).
- Whether the new test cases live in `allow-deny-check.sh` or a new
  sibling file — execution's call, least-disruptive to the existing 4
  passing cases.
- Whether `hooks.json`'s matcher gains `Bash` (needed only for core's
  six-case item 6) — out of this issue's stated defect list, deferred to
  execution's judgment on whether it's in scope.

## Verification plan for phase 2

1. `core/hooks/tests/compliance-check.sh readiness-checklist/hooks` clean
   (no hand-rolled kill-switch, no hand-rolled `replace_all`-ignoring
   reconstruction).
2. Extended `allow-deny-check.sh` (or sibling) green, all 4 existing cases
   plus every case listed in section 3 above.
3. Manual review confirming the `## Checklist`-scoped regex change (not a
   `gate-lib` function, this gate's own logic) actually rejects the
   outside-block fixture case.
