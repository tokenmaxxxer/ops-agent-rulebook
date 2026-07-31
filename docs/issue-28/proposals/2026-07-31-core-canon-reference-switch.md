---
name: issue-28-core-canon-reference-switch
subject: issue-28
role: implementation
status: proposed
---

# Proposal — switch to core canon for warrant-hunter and role-agnostic gates

Survey: `docs/issue-28/reports/implementation/2026-07-31-current-state-survey.md`.

## Scope confirmed against the issue's 5 items

1. **warrant-hunter copy removal** — not applicable. This repo has no
   `agents/warrant-hunter.md` and no hunt-cadence directive text (only
   coding-/product-/feasibility-/review-agent-rulebook carried that copy).
   No change required for this item; the survey records why.
2. **Gate-copy + hook-registration removal** — delete
   `ops/hooks/trailer-gate.sh`, `ops/hooks/record-fields-gate.sh`,
   `ops/hooks/handbook-trigger-gate.sh`, and remove their three
   `PreToolUse` entries from `ops/hooks/hooks.json`. Core's own
   `core/hooks/hooks.json` already fires all three globally
   (`${CLAUDE_PLUGIN_ROOT}/hooks/<name>.sh` under core's own plugin root)
   once this repo's plugin depends on core — keeping this repo's entries
   would double-fire the gates, not just carry dead code.
3. **directive.sh stubbing** — rewrite `ops/hooks/directive.sh` to:
   ```bash
   #!/usr/bin/env bash
   RECORD_FIELDS_TERMINAL_STATES="steady idle"
   . "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
   core_role_directive \
     "whether a change may ship, and — after it ships — whether it keeps running, gated by measurable reliability rather than discretionary sign-off. You do not invent what \"healthy\" means: you consume the measurement design feasibility produced upstream. You prevent shipping without a rollback path, shipping without a numeric definition of healthy, and a release proceeding once the error budget is spent." \
     "RESEARCH (phase 1, scout protocol): exemplars are how comparable systems roll out and fail — rollout curves and bake times for this class of change, the failure modes that reached production in similar systems, and postmortem patterns worth checking against this change. CURRENT-STATE SURVEY (phase 1): the production readiness review's seven dimensions over the target as it is TODAY (skills: readiness-checklist) — what monitoring, alerting, rollback, capacity, and runbooks exist now, plus the current error-budget position (skill: error-budget-policy)." \
     "the rollout plan (phase 1, skill: rollout-plan) — traffic curve, bake time per step, the metric queries watched, and PER-STEP pass/fail/inconclusive thresholds, pre-declared here, never invented mid-rollout." \
     "EXECUTION JUDGMENT (phase 2, quality bar): every readiness checklist item resolves to yes/no with a pointable artifact (dashboard URL, config key, runbook path) — \"we have monitoring\" with nothing to link is a FAIL; error_budget: exhausted refuses release steps regardless of readiness; a postmortem field is satisfied only by a postmortem a HUMAN has reviewed (skill: postmortem); rollout steps advance only on pre-declared thresholds, inconclusive holds; postmortems live at docs/issue-<n>/reports/postmortems/<slug>.md (core R5 grant)."
   ```
   Every non-blank/non-comment/non-shebang line is either the plain
   `VAR=value` assignment, the source line, or the `core_role_directive`
   call — matching `stub-check.sh`'s structural allowance exactly. The
   four positional strings are this repo's current directive body,
   carried over verbatim (re-flowed into the 4-argument shape), so the
   role-specific content the issue asks to preserve is preserved
   word-for-word rather than summarized.
4. **Role-specific real difference preserved explicitly** —
   `RECORD_FIELDS_TERMINAL_STATES="steady idle"` (this repo's actual
   current terminal set, vs. core's default `"landed"`) is set as a
   plain assignment in the stub above, using the override mechanism
   core's `record-fields-gate.sh` already exposes for exactly this case.
5. **stub-check verification** — phase 2 runs
   `core/hooks/tests/stub-check.sh` (or, if available in this checkout,
   `core/hooks/tests/run-role-gates-tests.sh`, which wraps it) against
   `ops/hooks/` and records the pass/fail result in
   `docs/issue-28/reports/implementation.md`, per contract v3 s19
   phase-2 record rules.

## What phase 2 will not decide unilaterally

Whether this repo's plugin manifest (`.claude-plugin/`) needs an explicit
dependency declaration on the core plugin for `core/hooks/hooks.json` to
actually fire in this repo's sessions was not resolved in phase 1 — it
requires reading this repo's current `.claude-plugin/` wiring, which is
execution-shaped inspection, not a proposal-stage design decision, and is
deferred to phase 2 under the approved plan above.

## Order constraint

Per the issue, this switch must land before this repo's "rulebook
maturation" phase 2 — noted, no action needed at proposal time beyond
recording it here as a known constraint on merge ordering.

Phase 1 stops here: proposal only, no APPROVE, no execution work.
