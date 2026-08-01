---
loop_state: idle
---

# Current-state survey — issue #36

## Scope
Audit target: `readiness-checklist/hooks/readiness-fields-gate.sh` (issue-33
deliverable), its test fixture `readiness-checklist/hooks/tests/allow-deny-check.sh`,
and `readiness-checklist/skills/readiness-checklist/SKILL.md`/README claims
about them. Precondition (core issue #72, "gate-house standard") confirmed
landed on `tokenmaxxxer-core` main: `core/hooks/lib/gate-lib.sh` +
`gate-lib.py`, `docs/handbooks/gate-house-standard.md`,
`core/hooks/tests/compliance-check.sh`, and
`core/hooks/tests/run-gate-lib-tests.sh` all exist there. No copy of any of
these exists in this repo today (`grep -rn gate-lib` across this repo hits
only doc references, no vendored file) — confirms nothing to deduplicate,
only to newly source.

## Defects confirmed by direct read of `readiness-fields-gate.sh`

1. **Kill-switch fail-open (matches core's own pre-issue-72 bug exactly).**
   Line: `case "${READINESS_FIELDS_GATE_OFF:-}" in ""|0|false|no|off) ;; *) exit 0 ;; esac`.
   Any unrecognized value — a typo, e.g. `1 ` with trailing space, or
   `disabled` — falls into `*) exit 0`, silently turning the gate off. This
   is the identical shape `gate-house-standard.md` names as core's own
   confirmed bug, now found live in this repo's own gate.
2. **`Edit`/`MultiEdit` ignore `replace_all`.** The `Edit` branch does
   `current.replace(o, n, 1)` unconditionally; `MultiEdit`'s loop does the
   same per edit, never reading `e.get("replace_all")`. A `replace_all:
   true` edit against a multiply-occurring `old_string` — e.g. flipping
   every `status: no` to `status: yes` in one call — silently only patches
   the first occurrence in the gate's simulated `new_text`, so the gate
   judges content the tool call will not actually produce.
3. **Semantic check is file-global substring, not section-scoped.** `items
   = re.findall(r'(?m)^\s*-\s*item:.*$', new_text)` scans the entire
   candidate file text for any line starting with `- item:`, with no
   requirement that it appear inside (or adjacent to) a `## Checklist`
   heading, and no adjacency check to the `status: rollout` line found
   earlier. A state file with an unrelated `- item: foo | status: yes |
   artifact: x` line anywhere outside the actual checklist section — in a
   comment, an appendix, a different section entirely — is silently
   admitted as a real checklist item. This is exactly the "scope claims
   `## Checklist` but parses the whole file" defect the issue names.
4. **Path resolution is real-filesystem-dependent, not pure.** `resolve()`
   calls `os.path.realpath` against `cwd` (from the tool-call payload) or
   `CLAUDE_PROJECT_DIR`, falling back to `os.getcwd()` — so gate behavior
   depends on the invoking process's actual working directory and the
   real filesystem's symlink structure at judge time, not a normalized,
   testable string operation. `gate_normalize_path` in `gate-lib.py` is
   deliberately pure string/path algebra with no filesystem touch,
   precisely to make this scoping testable without a real project-root
   fixture — this gate has no such pure layer today.
5. **No fail-closed wrapper around the internal Python payload's own
   unhandled exceptions beyond the outer bash trap.** The bash-level
   `__fc`/`trap __fc EXIT` (rc != 0/2 -> exit 2) is present and correct at
   the top per the issue's "trap-at-top" ask, and the heredoc does have its
   own `try/except Exception` fail-closed wrapper — so this specific axis
   is already sound; listed here only to record it as verified-clean
   rather than silently unaudited.

## Test coverage (thin, confirmed)

`allow-deny-check.sh` has exactly 4 cases, all `tool_name: "Write"`:
missing-artifact-deny, no-items-deny, complete-allow,
not-rollout-allow. None of the issue's mandatory additions exist:
no `Edit` case, no `MultiEdit` case (let alone one mixing
`replace_all: true/false`), no malformed-JSON case, no kill-switch
unrecognized-value case, no absolute-path case. This matches the issue's
"테스트 얇음(Write 3케이스)" note (4 by literal count, but 0 tool-shape
variety — all four are `Write`).

## README / SKILL.md claims vs. reality

`readiness-checklist/skills/readiness-checklist/SKILL.md` and the repo
README describe the gate at the behavior level (readiness -> rollout,
seven-dimension PRR, yes-needs-artifact) without naming implementation
files beyond the real ones (`readiness-fields-gate.sh`,
`allow-deny-check.sh`) — no ghost file references found in this specific
plugin's docs. The issue's README-hygiene ask (#4) is scoped generically
("유령 파일 제거, 실제 플러그인·경로·킬스위치 문서화") — confirmed as a
verify-clean item here too, but the migration itself changes the kill
switch's *behavioral description* (unrecognized value now stays active,
not disables), so the README/SKILL text describing
`READINESS_FIELDS_GATE_OFF` must be updated to match once gate-lib lands,
even though no ghost filenames need removing.

## Prior-art in this exact repo (precedent for the reference-not-copy migration)

`docs/issue-28/reports/implementation.md` already executed an equivalent
core-canon-reference migration for `ops/hooks/directive.sh` (sourcing
`core/hooks/lib/role-directive.sh`), including running
`core/hooks/tests/stub-check.sh` as its verification step. That record is
the direct template for this issue's phase-2 execution shape: reference
`gate-lib.sh`/`gate-lib.py` (never vendor), then run
`core/hooks/tests/compliance-check.sh readiness-checklist/hooks` clean as
the equivalent verification gate `stub-check.sh` played there.

## Scout skip record

Scouting skipped. Reason: the fix's design surface has no open axis to
scout — `docs/handbooks/gate-house-standard.md` in `tokenmaxxxer-core`
(landed, canon, this issue's stated precondition) fully specifies both the
API to adopt (`gate_trap_fail_closed`, `gate_kill_switch_active`,
`gate_deny`/`gate_allow`, `gate_parse_json_or_deny`, `gate_normalize_path`,
`gate_reconstruct_write`, `gate_bash_write_targets`) and the mandatory
six-case test harness shape. This is a conservative reference-adoption
task against an already-standardized target, not a product-shaped
decision with competing approaches to weigh — the skip conditions in the
scout directive ("spec literally leaves no design decision open") apply.
