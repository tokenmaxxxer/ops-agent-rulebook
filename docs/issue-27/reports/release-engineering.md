---
loop_state: landed
upstream: docs/issue-27/proposals/2026-07-31-rulebook-maturation.md
---

# Release-engineering record — issue #27

## What was done
Executed the approved proposal's plugin-reflection plan (item (d)),
items 1-5:

1. **`ops/hooks/directive.sh` `PRODUCES` extension** — appended the
   RFC-shaped proposal-section requirement from (a) verbatim into the
   phase-1 `PRODUCES` string: every `docs/issue-<n>/proposals/*.md` must
   state scope/change description, a named risk, a rollback/back-out
   path, and cite a source for every adopted-methodology claim. No
   change to `YOU_DECIDE`/`USE_WHEN`/`HAND_OFF`.
2. **`ops/hooks/proposal-fields-gate.sh` (new)** — PreToolUse gate on
   `Write|Edit|MultiEdit`, same fail-closed/deny-only shape as core's
   `record-fields-gate.sh`. On a write resolving under
   `docs/issue-<n>/proposals/*.md`, denies (exit 2) unless the resulting
   content has a scope/change-description mention, a risk section, a
   rollback/back-out mention, and at least one inline citation (URL or
   `docs/...`/`` `*.md`/`*.sh` `` path). Registered in `hooks.json`.
3. **`ops/hooks/rollout-plan-fields-gate.sh` (new)** — PreToolUse gate,
   same shape. On a write resolving to `ops/rollout-plan.md`, parses
   `## Step` blocks; for any step whose `result:` is `pass` or `fail`,
   denies unless every `- name:` metric under that step carries a
   non-empty `threshold:` field. `result: pending` (or anything else) is
   never gated. Registered in `hooks.json`.
4. **Postmortem review field, record file** — confirmed as-is per the
   proposal: no gate or field change; `postmortem-template.md`'s
   existing `Reviewed by`/`Reviewer satisfied` fields and core's §20
   record-field set already cover these.
5. **Dangling state-machine references** — left untouched, out of scope
   per the proposal (flagged there for a future issue).

Verified: `bash -n` on both new scripts, `python3 -m json.tool` on the
edited `hooks.json`, and this repo's own
`tests/parse-check.sh`/`tests/deny-only-check.sh` (see Verification).

## Why
The approved proposal
(`docs/issue-27/proposals/2026-07-31-rulebook-maturation.md`) found the
role's four phase-2 skills already match the field's converged practice
(Google SRE error-budget-policy / PRR / canary rollout / postmortem
shapes) and needed no methodology change; what was missing was (a) a
named phase-1 proposal norm — RFC-shaped minus ITIL's governance
apparatus, because contract v3 already supplies issue-numbered identity
and the two-path Approve gate, so importing change-ID/CAB machinery would
duplicate rather than strengthen it — and (d) mechanical enforcement,
because `record-fields-gate.sh` already proves a gate catches the
"skipped field described only in prose" failure class that prose alone
does not. The two new gates apply that same proven pattern to this
role's own proposal documents and to the rollout-plan's per-step
threshold discipline, which the scout brief flagged as the field's core
discipline (never invent a threshold mid-rollout).

## Verification
- `bash -n ops/hooks/proposal-fields-gate.sh` / `rollout-plan-fields-gate.sh` — both parse.
- `python3 -c "import json; json.load(open('ops/hooks/hooks.json'))"` — valid JSON.
- `bash tests/parse-check.sh ops/hooks` — all 3 files `ok`.
- `bash tests/deny-only-check.sh ops/hooks` — no `permissionDecision: allow`
  found (first check passes). Its substance probe (empty-`docs/issue-999/
  reports/ops.md` refusal) now FAILS: it discovers the two new
  `*-gate.sh` files and expects at least one to refuse an empty role
  record, but neither gate targets the record file — that gate
  (`record-fields-gate.sh`) lives in core canon since issue-28's
  reference-switch and is not vendored here by design. Filed as an open
  finding below rather than silently worked around, since
  `deny-only-check.sh` is core-owned vendored content this role should
  not edit.

## Open findings
- `tests/deny-only-check.sh`'s substance probe assumes any local
  `*-gate.sh` file implies the record-fields gate is among them; that
  assumption predates issue-28's core-canon switch and is stale for any
  rulebook that (like this one, post-issue-27) adds a local gate for a
  reason other than the record file. Not fixed here: the script is
  core-owned vendored content ("every rulebook copies this file
  verbatim"), out of scope for issue-27, and the real record-fields
  check already runs separately via core's own `stub-check.sh`/
  `run-role-gates-tests.sh` per `docs/handbooks/tests.md`.

## Next steps
A future core issue should either scope `deny-only-check.sh`'s substance
probe to gates matching a record-fields naming convention, or drop the
assumption that any local `*-gate.sh` implies a record-fields gate.

## Open-finding resolution path
File a core-canon issue against `deny-only-check.sh` (core issues #63/#66
lineage); this repo's gates are correct as delivered and need no further
change here.
