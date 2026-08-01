---
name: issue-39-gate-a-plus-final-remediation
subject: issue-39
role: release-engineering
status: proposed
---

# Proposal — gate A+ 최종 마감 (재감사 잔여 결함 보수)

Survey: `docs/issue-39/reports/release-engineering/survey.md`.
Scout: skipped, see
`docs/issue-39/reports/release-engineering/scout-brief.md`.

## Scope / change description

Bring all five of this repo's field-gates
(`readiness-fields-gate.sh`, `proposal-fields-gate.sh`,
`postmortem-review-gate.sh`, `error-budget-gate.sh`,
`rollout-plan-fields-gate.sh`) to full conformance with core's
`gate-house-standard` as confirmed by core issue #75 (PR #77, commit
`52bdc15`), close the `Bash`-tool coverage gap that lets a shell write
bypass every field gate, fix `tests/parse-check.sh`'s directory default so
the documented no-arg invocation actually parses every plugin's hooks,
and remove the `ops` old-role-name / ghost-file residue from `README.md`
and `.claude-plugin/marketplace.json`. Six work items:

1. **Source-guard the already-migrated gate.**
   `readiness-fields-gate.sh` line 2 sources `gate-lib.sh` with no `||`
   guard — the exact issue-75-confirmed fail-open shape, even though the
   rest of the file already uses `gate_kill_switch_active` and
   `gate_reconstruct_write`. Add the guard verbatim from the current
   canon usage comment:
   `. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "readiness-fields-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }`
   and add the missing-core mandatory case (#7 in the canon's 7-case
   list) to `readiness-checklist/hooks/tests/allow-deny-check.sh`:
   `CLAUDE_PLUGIN_ROOT_CORE` pointed at a nonexistent path with the
   relative fallback also nonexistent (run from a tempdir with no
   `../../core`) must assert exit 2.

2. **Migrate the four remaining gates onto `gate-lib.sh`/`gate-lib.py`.**
   For `proposal-fields-gate.sh`, `postmortem-review-gate.sh`,
   `error-budget-gate.sh`, `rollout-plan-fields-gate.sh`: replace the
   `__fc`/`trap __fc EXIT` header with `gate_trap_fail_closed`; replace
   the hand-rolled `case "${X_OFF:-}" in ...` block with
   `gate_kill_switch_active "${X_OFF:-}" || { trap - EXIT; exit 0; }`;
   replace the hand-rolled JSON parse with
   `gate_lib.gate_parse_json_or_deny`; replace the hand-rolled path
   resolve with `gate_lib.gate_normalize_path`; replace every hand-rolled
   `current.replace(o, n, 1)` / MultiEdit loop with
   `gate_lib.gate_reconstruct_write` — the same substitution
   `readiness-fields-gate.sh` already made in issue-36, applied to the
   other four verbatim. Each gate's own field-semantic logic (which
   sections are required, which record fields gate which transition)
   stays local and unchanged — only the shared mechanics move to
   `gate-lib`.

3. **Bring each of the five `hooks/tests/allow-deny-check.sh` fixtures up
   to the full 7-case mandatory list** (6 for the gate's own logic +
   missing-core): Edit reconstruction, MultiEdit mixed `replace_all`,
   malformed JSON (truncated + non-object + empty), kill-switch
   unrecognized-value-stays-active, absolute/`./`-prefixed path parity,
   and missing-core deny — adapted per gate the same way
   `readiness-checklist/hooks/tests/allow-deny-check.sh` already
   demonstrates the pattern for cases 1-6 (that file becomes the template
   for the other four, plus its own new case 7 from item 1).

4. **Close the `Bash`-tool bypass.** Add a `Bash` leg to all five
   `hooks.json` matchers (`"Write|Edit|MultiEdit|Bash"`) and, in each
   gate's Python payload, call `gate_lib.gate_bash_write_targets(command)`
   when `tool_name == "Bash"` to extract path-shaped candidates from the
   command string, then run each candidate through the same
   normalize/scope/field-check path already used for `Write`/`Edit`/
   `MultiEdit`. A `Bash` command with no path-shaped write target (a pure
   read, a `cd` with no redirect, etc.) resolves no candidates and is not
   this gate's business, same as today's non-matching-path early exit.
   Add one fixture per gate: a `Bash` command shaped like `cd ../.. &&
   echo x >> <the gate's protected path>` reaching the same target a
   `Write` fixture already covers, asserting the same verdict.

5. **Fix `tests/parse-check.sh`'s directory default.** The current
   no-arg default resolves to `ops/hooks` only, so the documented
   `/bin/bash tests/parse-check.sh` invocation silently checks 2 files and
   skips the other five plugins' `hooks/*.sh` and `hooks/tests/*.sh`
   entirely. Change the no-arg default to the repo root
   (`$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)`) so the existing
   recursive `find "$dir" -name '*.sh' -type f` already in the script
   walks every plugin's `hooks/` tree by default; keep the explicit-arg
   form working unchanged (still needed by any caller that wants to scope
   to one plugin, e.g. CI matrix jobs). Update `README.md`'s "Run the
   checks" section and `docs/handbooks/tests.md` to show the corrected
   expected file count.

6. **Zero the old role name and ghost file paths.**
   - `README.md`: title → `# tokenmaxxxer / release-engineering-rulebook`;
     replace every prose "`ops` role" / "an `ops` session" / "`ops`
     decides" with "`release-engineering` role" / "a `release-engineering`
     session" / "`release-engineering` decides"; branch reference
     `issue-<n>/ops` → `issue-<n>/release-engineering`; record path
     `docs/issue-<n>/reports/ops.md` → `docs/issue-<n>/reports/
     release-engineering.md`; install snippet
     `claude plugin marketplace add tokenmaxxxer/ops-agent-rulebook` /
     `claude plugin install ops@tokenmaxxxer-ops` → the corresponding
     `release-engineering-rulebook` / `release-engineering@tokenmaxxxer-
     release-engineering` names, matched to whatever final plugin/
     marketplace name item 6 below settles on.
   - `.claude-plugin/marketplace.json`: `"name": "tokenmaxxxer-ops"` →
     `"name": "tokenmaxxxer-release-engineering"`; the `ops` plugin entry's
     `"name": "ops"` → `"name": "release-engineering"` (its `"source":
     "./ops"` and the on-disk `ops/` directory are the runtime record
     namespace referenced by every gate's `ops/state.md` /
     `ops/rollout-plan.md` path and by `directive.sh`'s own sibling-plugin
     discovery — renaming the directory is a larger, riskier surface
     change than renaming its display name/manifest entry, and the issue
     asks for README/manifest cleanup, not a directory rename; leaving
     `./ops` as the `source` path and only renaming the manifest
     `"name"` field is the narrower fix that satisfies the issue's actual
     ask without touching every gate's path-construction logic).
     `ops/.claude-plugin/plugin.json`'s own `"name": "ops"` → `"name":
     "release-engineering"` to match.
   - Ghost paths: `readiness-checklist/skills/readiness-checklist/
     SKILL.md`'s `ops-cycle/skills/rollout-plan/SKILL.md` →
     `rollout-plan/skills/rollout-plan/SKILL.md`;
     `postmortem/skills/postmortem/SKILL.md`'s `ops-cycle/skills/
     postmortem/SKILL.md` → `postmortem/skills/postmortem/SKILL.md`, and
     `ops-cycle/skills/postmortem/templates/postmortem-template.md` →
     `postmortem/skills/postmortem/templates/postmortem-template.md`.
   - Add a compliance test: extend `tests/deny-only-check.sh` (or add a
     small sibling `tests/role-name-check.sh` run alongside it, per
     README's "Run the checks" list) that greps `README.md` and
     `.claude-plugin/**/*.json` for the literal tokens `ops-agent`,
     `tokenmaxxxer-ops`, and `ops-cycle`, and hard-fails (non-zero exit)
     if any is found — so the old name cannot silently regress back in,
     matching the issue's "옛 이름은 하드 에러" requirement. The `ops/`
     directory name itself, `ops/state.md`-family paths, and prose uses of
     "ops" as the generic SRE-domain word are explicitly excluded from
     this check (false-positive risk on a legitimate directory/vocabulary
     name), scoped instead to the specific old-brand tokens listed above.

## Risk

Named failure mode: a mid-migration state where some gates call
`gate_lib.gate_reconstruct_write` and others still hand-roll
`.replace()`, or where `hooks.json` grows a `Bash` matcher before the
gate's Python payload handles `tool_name == "Bash"`, would leave a gate
either double-processing the same write or fail-closed on every `Bash`
call it doesn't yet understand (mirroring the exact `AttributeError` fail-
closed-on-everything defect core #75 found in pr-communications). Each of
the six items above is scoped to land as one gate-file's complete
before/after replacement in the same commit as its own `hooks.json` and
test-fixture update — no partial per-gate landing — so no gate is ever
left in a mixed old/new mechanics state mid-batch.

## Rollback / back-out path

Every changed file is a plain-text script, manifest, or doc under version
control; `git revert` of the phase-2 delivery commit(s) restores the prior
(A-) state exactly. Each gate carries its own `*_GATE_OFF` kill switch as
an immediate mitigation if a migrated gate misbehaves in production before
a revert lands, unchanged by this proposal.

## Sourced evidence

- Core canon, confirmed by direct read of a fresh clone of
  `tokenmaxxxer/tokenmaxxxer-core` (commit `52bdc15`):
  `docs/handbooks/gate-house-standard.md`,
  `core/hooks/lib/gate-lib.sh` (usage comment, guarded source line),
  `core/hooks/tests/compliance-check.sh`.
- `tokenmaxxxer/tokenmaxxxer-core` issue #75 (closed, PR #76/#77) and
  `tokenmaxxxer/on-the-record` issue #182 (closed, PR #183/#185) — read
  via `gh issue view`.
- This repo's current gate files (`grep`/`Read` against
  `readiness-checklist/hooks/readiness-fields-gate.sh`,
  `proposal-norm/hooks/proposal-fields-gate.sh`,
  `postmortem/hooks/postmortem-review-gate.sh`,
  `error-budget-policy/hooks/error-budget-gate.sh`,
  `rollout-plan/hooks/rollout-plan-fields-gate.sh`,
  `tests/parse-check.sh`, `README.md`,
  `.claude-plugin/marketplace.json`) and their test fixtures under each
  plugin's `hooks/tests/allow-deny-check.sh` — see
  `docs/issue-39/reports/release-engineering/survey.md` for the full
  per-file findings this proposal is built on.
- Git history (`git log --oneline`) confirming the repo's first commit
  title (`Build ops-agent-rulebook: the ops role's plugin marketplace`)
  and every commit since the contract-v3 restructure (PR #26) using the
  `release-engineering` role tag, as evidence `ops` is the stale name.

Phase 1 stops here: proposal only, no APPROVE, no execution work.
