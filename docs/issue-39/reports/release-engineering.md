---
name: issue-39-phase-2-record
subject: issue-39
role: release-engineering
status: delivered
---

# Phase-2 delivery record — gate A+ final remediation (issue-39)

Contract v3 s19. Human APPROVE confirmed on issue #39
("APPROVE issue-39/release-engineering"). Executed against
`docs/issue-39/proposals/2026-08-01-gate-a-plus-final-remediation.md`.

loop_state: landed

## What was done, why, and the concrete upstream basis

**1. Source-guard the already-migrated gate.**
`readiness-checklist/hooks/readiness-fields-gate.sh` line 2 now sources
`gate-lib.sh` with the `||` guard (`exit 2` on unreachable core), verbatim
per core canon's usage comment in `core/hooks/lib/gate-lib.sh` (confirmed
by reading a fresh clone of `tokenmaxxxer/tokenmaxxxer-core`, commit
`52bdc15`). This closes the exact issue-75-confirmed fail-open shape: an
unguarded source that fails silently disables every downstream
`gate_kill_switch_active` call. Added mandatory case #7 (missing-core
deny) to `readiness-checklist/hooks/tests/allow-deny-check.sh`:
`CLAUDE_PLUGIN_ROOT_CORE` pointed at a nonexistent path (the relative
`../../core` fallback from this repo is also nonexistent, since this repo
has no `core/` sibling directory on disk) asserts exit 2.

**2. Migrate the four remaining gates onto `gate-lib.sh`/`gate-lib.py`.**
`proposal-norm/hooks/proposal-fields-gate.sh`,
`postmortem/hooks/postmortem-review-gate.sh`,
`error-budget-policy/hooks/error-budget-gate.sh`, and
`rollout-plan/hooks/rollout-plan-fields-gate.sh` all now: source
`gate-lib.sh` with the `||` guard; call `gate_trap_fail_closed` instead of
a hand-rolled `__fc`/`trap __fc EXIT`; call
`gate_kill_switch_active "${X_OFF:-}" || { trap - EXIT; exit 0; }` instead
of the hand-rolled `case` statement (fixes the fail-open-on-typo bug,
survey-confirmed present in all four); call
`gate_lib.gate_parse_json_or_deny` instead of hand-rolled `json.loads`;
call `gate_lib.gate_normalize_path` instead of the hand-rolled
`resolve()`; call `gate_lib.gate_reconstruct_write` instead of
`current.replace(o, n, 1)` / a MultiEdit loop that ignored `replace_all`.
Each gate's own field-semantic logic — proposal RFC-shape checks, the
incident/postmortem/reviewer chain, the error-budget hard stop, the
per-step-threshold rule — is unchanged; only the shared mechanics moved,
per readiness-fields-gate.sh's own issue-36 precedent.

**3. Bring all five `hooks/tests/allow-deny-check.sh` fixtures to the
full 7-case mandatory list.** Every one of the five plugins' fixtures now
covers: an Edit-reconstruction case, a MultiEdit mixed-`replace_all` case,
three malformed-JSON shapes (truncated, non-object, empty), a
kill-switch-unrecognized-value-stays-active case, an absolute-path and a
`./`-prefixed-path parity case, and a missing-core deny case — adapted per
gate to that gate's own protected path and field semantics, following
`readiness-checklist`'s fixture as the template.

**4. Close the Bash-tool bypass.** All five `hooks/hooks.json` matchers
are now `"Write|Edit|MultiEdit|Bash"`. Each gate's Python payload now
extracts Bash write candidates via `gate_lib.gate_bash_write_targets(
command)` when `tool_name == "Bash"`, normalizes each candidate the same
way a `Write`/`Edit`/`MultiEdit` `file_path` is normalized, and — because
a Bash command's resulting file content has no reconstructible shape (no
`gate_reconstruct_write` support for arbitrary shell redirects) — denies
outright (fail-closed) once a Bash command's target resolves to the
gate's protected path, rather than guessing at content. A Bash command
with no path-shaped write target still resolves no candidates and exits 0,
unchanged. One Bash-bypass fixture per gate (5 total) asserts a `cd ../..
&& echo x >> <protected path>` command denies, matching the verdict of an
existing deny-verdict Write fixture for the same target.

**5. Fix `tests/parse-check.sh`'s directory default.** The no-arg default
now resolves to the repo root
(`$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)`) instead of
`ops/hooks` only; the explicit-arg form is unchanged. Ran the script after
the fix: it now walks 15 files (was silently 2). `README.md`'s "Run the
checks" section and `docs/handbooks/tests.md` were updated with that
count and a note pointing at the script's own self-reported count rather
than hand-tracking it.

**6. Zero the old role name and ghost file paths.**
- `README.md`: title, "ops role"/"an ops session"/"ops decides" prose,
  branch/record-path references, and the install snippet all now read
  `release-engineering`.
- `.claude-plugin/marketplace.json`: top-level `"name"` →
  `"tokenmaxxxer-release-engineering"`; the `ops` plugin entry's `"name"`
  → `"release-engineering"`, `"source": "./ops"` and the on-disk `ops/`
  directory left unchanged per the proposal's explicit rationale (renaming
  the directory would touch every gate's `ops/state.md`-family path
  construction, a materially larger and riskier change than the issue
  asked for).
- `ops/.claude-plugin/plugin.json`: `"name"` → `"release-engineering"`.
- Ghost paths fixed: `readiness-checklist/skills/readiness-checklist/
  SKILL.md`'s two `ops-cycle/...` references → `rollout-plan/skills/
  rollout-plan/SKILL.md` and `postmortem/skills/postmortem/SKILL.md`;
  `postmortem/skills/postmortem/SKILL.md`'s `ops-cycle/skills/postmortem/
  templates/postmortem-template.md` → `postmortem/skills/postmortem/
  templates/postmortem-template.md`.
- Added `tests/role-name-check.sh`: greps `README.md` and
  `.claude-plugin/**/*.json` for the literal tokens `ops-agent`,
  `tokenmaxxxer-ops`, `ops-cycle`; hard-fails (exit 1) if any is found.
  Added to README's "Run the checks" list.

## Deviations from the proposal, with rationale

- **`install.sh` still contains `ops-agent-rulebook` / `tokenmaxxxer-ops`
  tokens** (`MARKET="tokenmaxxxer-ops"`, `GITHUB_REPO="tokenmaxxxer/
  ops-agent-rulebook"`, and matching install-log strings). The proposal's
  item 6 scope is explicitly `README.md` and
  `.claude-plugin/marketplace.json` (plus the two SKILL.md ghost paths and
  a compliance test scoped to those same two file classes); it does not
  name `install.sh`. Left untouched to stay inside the approved scope,
  and `tests/role-name-check.sh` is likewise scoped to README.md and
  `.claude-plugin/**/*.json` per the proposal's own text, so it does not
  flag `install.sh`. Flagged below as an open finding rather than silently
  expanding scope mid-delivery.
- **Bash-bypass handling always denies rather than attempting partial
  content reconstruction.** The proposal says a Bash candidate should be
  "route[d] ... through the same normalize/scope/field-check path already
  used for Write/Edit/MultiEdit." A Bash command's resulting file content
  has no general reconstructible shape (`gate_reconstruct_write` only
  covers Write/Edit/MultiEdit/NotebookEdit tool-input shapes, not
  arbitrary shell text). Once a Bash candidate normalizes onto a gate's
  protected path, every gate here denies outright (fail-closed) rather
  than guessing at the resulting content — the same fail-closed posture
  each gate already takes for an Edit/MultiEdit it cannot reconstruct.
  This is at least as strict as full field-checking (it never
  under-refuses), and each gate's new Bash-bypass fixture asserts the same
  deny verdict as an existing deny-verdict Write fixture for the same
  target, per the proposal's own wording.
- **`ops/hooks/directive.sh` fails core's `stub-check.sh`** (pre-existing,
  confirmed via `git status` — this file was not touched by this
  delivery). Out of this issue's scope; noted as an open finding, not
  fixed.
- **`tests/deny-only-check.sh`'s own `probe_dir` default still hardcodes
  `ops/hooks`** (separate from `tests/parse-check.sh`, which item 5 fixed).
  The proposal names only `tests/parse-check.sh`'s directory default;
  left unchanged to stay inside scope.

## Test suites run, with actual pass counts

All commands below were run in this environment, where
`CLAUDE_PLUGIN_ROOT_CORE` is already set by the harness to a real
installed checkout of `tokenmaxxxer-core` (confirmed current: has
`gate_bash_write_targets` in both `gate-lib.sh` and `gate-lib.py`).

    /bin/bash readiness-checklist/hooks/tests/allow-deny-check.sh
    16/16 ok

    /bin/bash proposal-norm/hooks/tests/allow-deny-check.sh
    17/17 ok

    /bin/bash postmortem/hooks/tests/allow-deny-check.sh
    14/14 ok

    /bin/bash error-budget-policy/hooks/tests/allow-deny-check.sh
    15/15 ok

    /bin/bash rollout-plan/hooks/tests/allow-deny-check.sh
    15/15 ok

    /bin/bash tests/parse-check.sh
    15/15 files parse clean under bash 5.1.16 (no-arg default now walks
    the repo root; was 2 files before the fix)

    /bin/bash tests/deny-only-check.sh
    ok (no permissionDecision:"allow" under the repo; ops/hooks has no
    *-gate.sh files so the substance probe reports nothing to check —
    unchanged pre-existing behavior, this repo's field gates live under
    the other five plugins' hooks/, which the probe does not scan; out of
    this issue's scope to change)

    /bin/bash tests/role-name-check.sh
    ok (no ops-agent/tokenmaxxxer-ops/ops-cycle tokens in README.md or
    .claude-plugin/**/*.json)

    <core>/hooks/tests/compliance-check.sh against each of the five
    migrated gates' hooks/ directories
    5/5 ok — readiness-checklist, proposal-norm, postmortem,
    error-budget-policy, rollout-plan all report "compliance-check: ok"
    (no hand-rolled kill switch, no hand-rolled .replace() reconstruction,
    no unguarded gate-lib.sh source line)

    <core>/hooks/tests/stub-check.sh against ops/hooks
    FAIL (pre-existing, unrelated to this delivery — see Deviations above)

`core/hooks/tests/run-gate-lib-tests.sh` is core's own internal harness
for `gate-lib.sh`/`gate-lib.py` themselves (fixed relative paths to its
own sibling `hooks/lib/`), not designed to be invoked against a
rulebook's hooks directory; `compliance-check.sh` above is the
core-canon script meant for that purpose, and was run against all five
migrated gates.

**Total: 77/77 fixture assertions pass across the five gates' own
`allow-deny-check.sh` suites, plus parse-check, deny-only-check,
role-name-check, and 5/5 core compliance-check runs all green.** The one
failing suite (`stub-check.sh` against `ops/hooks/directive.sh`) is a
pre-existing, out-of-scope defect not touched by this delivery.

## Open findings

- `install.sh` still contains the `tokenmaxxxer-ops` / `ops-agent-rulebook`
  old-brand tokens (out of this issue's approved scope — see Deviations
  above); a follow-up issue should extend the role-name purge to it if the
  team wants zero residual old-brand strings repo-wide.
- `ops/hooks/directive.sh` fails core's `stub-check.sh` (pre-existing,
  not touched by this delivery); worth its own issue to bring back to a
  stub shape or confirm the deviation is intentional.
- `tests/deny-only-check.sh`'s own `probe_dir` default still hardcodes
  `ops/hooks` (separate script from `tests/parse-check.sh`, which this
  issue fixed); its substance probe therefore never actually exercises
  the five migrated gates. Not in this issue's scope, but the same class
  of defect item 5 just fixed elsewhere in this repo.
