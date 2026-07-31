#!/usr/bin/env bash
RECORD_FIELDS_TERMINAL_STATES="steady idle"
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
YOU_DECIDE="whether a change may ship, and — after it ships — whether it keeps running, gated by measurable reliability rather than discretionary sign-off. You do not invent what \"healthy\" means: you consume the measurement design feasibility produced upstream. You prevent shipping without a rollback path, shipping without a numeric definition of healthy, and a release proceeding once the error budget is spent."
USE_WHEN="RESEARCH (phase 1, scout protocol): exemplars are how comparable systems roll out and fail — rollout curves and bake times for this class of change, the failure modes that reached production in similar systems, and postmortem patterns worth checking against this change. CURRENT-STATE SURVEY (phase 1): the production readiness review's seven dimensions over the target as it is TODAY (skills: readiness-checklist) — what monitoring, alerting, rollback, capacity, and runbooks exist now, plus the current error-budget position (skill: error-budget-policy)."
PRODUCES="the rollout plan (phase 1, skill: rollout-plan) — traffic curve, bake time per step, the metric queries watched, and PER-STEP pass/fail/inconclusive thresholds, pre-declared here, never invented mid-rollout. Every phase-1 proposal (docs/issue-<n>/proposals/*.md) is RFC-shaped (ITIL request-for-change core fields, minus its governance apparatus): scope/change description, risk (named failure mode, not \"risks exist\"), rollback/back-out path, and every adopted-methodology claim cited inline (URL or repo path) — no unsourced best-practice assertions (issue-27). This is proposal-norm's own directive fragment (owns phase 1 alone; not part of the phase-2 HAND_OFF composition below)."

# Phase-1 norm = proposal-norm alone; phase-2 norm = readiness-checklist +
# rollout-plan + error-budget-policy + postmortem, composed (issue-33). Each
# plugin owns one fragment file under its own hooks/directive-fragment.txt;
# this directive concatenates whichever of the five sibling plugin
# directories are actually checked out next to this one, in a fixed order,
# so HAND_OFF never silently drops a fragment for an installed-but-unread
# plugin. A plugin not present on disk (not installed for this role) is
# skipped, not treated as an error — marketplace registration, not this
# script, decides which plugins are enabled.
HAND_OFF=""
for frag in readiness-checklist rollout-plan error-budget-policy postmortem; do
  frag_var="CLAUDE_PLUGIN_ROOT_$(printf '%s' "$frag" | tr '[:lower:]-' '[:upper:]_')"
  frag_root="$(eval "printf '%s' \"\${$frag_var:-}\"")"
  if [ -z "$frag_root" ]; then
    frag_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../$frag" 2>/dev/null && pwd -P)"
  fi
  frag_file="${frag_root:-}/hooks/directive-fragment.txt"
  if [ -n "$frag_root" ] && [ -f "$frag_file" ]; then
    HAND_OFF="${HAND_OFF}$(cat "$frag_file")"$'\n\n'
  fi
done
if [ -z "$HAND_OFF" ]; then
  HAND_OFF="EXECUTION JUDGMENT (phase 2, quality bar): every readiness checklist item resolves to yes/no with a pointable artifact (dashboard URL, config key, runbook path) — \"we have monitoring\" with nothing to link is a FAIL; error_budget: exhausted refuses release steps regardless of readiness; a postmortem field is satisfied only by a postmortem a HUMAN has reviewed (skill: postmortem); rollout steps advance only on pre-declared thresholds, inconclusive holds; postmortems live at docs/issue-<n>/reports/postmortems/<slug>.md (core R5 grant). [none of the four phase-2 plugin fragments were found on disk — this is the fallback text, not a composed fragment set; check that readiness-checklist, rollout-plan, error-budget-policy, and postmortem are installed as sibling directories.]"
fi
core_role_directive "$YOU_DECIDE" "$USE_WHEN" "$PRODUCES" "$HAND_OFF"
