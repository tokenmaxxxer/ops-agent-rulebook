# tokenmaxxxer / ops-agent-rulebook

The `ops` role on contract v3. An ops session is spawned with two plugin
sets installed: this marketplace's `ops` plugin, and the
[tokenmaxxxer-core](https://github.com/tokenmaxxxer/tokenmaxxxer-core)
plugins (`core`, `terse`, `freelunch`, `scout`). Core owns the interaction
protocol — issue in, two-phase PR out (research/survey/proposal → human
review Approve → execution), branch `issue-<n>/ops`, record at
`docs/issue-<n>/reports/ops.md`. This rulebook owns only what is
ops-specific.

## What `ops` decides

Whether a change may ship, and — after it ships — whether it keeps
running, gated by measurable reliability rather than discretionary
sign-off. ops consumes the measurement design feasibility produced; it
never invents what "healthy" means. It prevents shipping without a
rollback path, without a numeric health definition, and any release step
once the error budget is spent.

## What is here

Six plugins, each its own top-level directory (`hooks/` + `skills/`):

    ops/hooks/directive.sh                          SessionStart — the four facets:
                                                     research (how comparable systems
                                                     roll out and fail), survey (PRR
                                                     seven dimensions + current error
                                                     budget), proposal (rollout plan
                                                     with pre-declared per-step
                                                     thresholds), judgment
                                                     (pointable-artifact rule,
                                                     error-budget refusal,
                                                     human-reviewed postmortems)
    proposal-norm/hooks/proposal-fields-gate.sh      RFC-shaped proposal sections
                                                     (scope, risk, rollback, sourced
                                                     evidence) on docs/issue-<n>/
                                                     proposals/*.md (issue-27).
                                                     Kill switch: PROPOSAL_FIELDS_GATE_OFF=1
    rollout-plan/hooks/rollout-plan-fields-gate.sh   non-empty per-metric threshold
                                                     before a rollout-plan step is
                                                     written; result: pass|fail
                                                     (issue-27).
                                                     Kill switch: ROLLOUT_PLAN_FIELDS_GATE_OFF=1
    readiness-checklist/hooks/readiness-fields-gate.sh  readiness -> rollout on
                                                     ops/state.md: every `## Checklist`
                                                     item resolves yes/no, every yes
                                                     needs a real artifact (issue-33,
                                                     migrated to core's gate-lib.sh/
                                                     gate-lib.py — issue-36).
                                                     Kill switch: READINESS_FIELDS_GATE_OFF=1
                                                     (or true/yes/on; any other value,
                                                     including an unrecognized one,
                                                     leaves the gate active)
    error-budget-policy/hooks/error-budget-gate.sh   error_budget: exhausted refuses
                                                     release steps regardless of
                                                     readiness.
                                                     Kill switch: ERROR_BUDGET_GATE_OFF=1
    postmortem/hooks/postmortem-review-gate.sh       postmortem field is satisfied
                                                     only by a human-reviewed
                                                     postmortem.
                                                     Kill switch: POSTMORTEM_REVIEW_GATE_OFF=1
    ops/skills/, proposal-norm/skills/, rollout-plan/skills/,
    readiness-checklist/skills/, error-budget-policy/skills/, postmortem/skills/
                                                     the operator's-eye view for each
                                                     plugin's own gate
    tests/                                          repo-level checks (never installed)

## Record vocabulary

`loop_state`: `idle, readiness, rollout, steady, incident` (settled:
`steady`/`idle`). Signal fields: `error_budget: ok|exhausted` (exhausted
refuses release steps), `postmortem:` (human-reviewed pointer),
`## Checklist` rows `- item | status: yes|no | artifact: <pointer>`.
Postmortems live at `docs/issue-<n>/reports/postmortems/<slug>.md`
(a core R5 grant).

## Install

    claude plugin marketplace add tokenmaxxxer/ops-agent-rulebook
    claude plugin install ops@tokenmaxxxer-ops

Per-plugin gate kill switches are listed in "What is here" above; there is
no single repo-wide `OPS_CYCLE_OFF`.

## Run the checks

    /bin/bash tests/parse-check.sh
    /bin/bash tests/deny-only-check.sh
    /bin/bash <core>/hooks/tests/stub-check.sh ops/hooks
    /bin/bash <core>/hooks/tests/compliance-check.sh readiness-checklist/hooks
    /bin/bash readiness-checklist/hooks/tests/allow-deny-check.sh

The role-agnostic gates (trailer/record-fields/handbook-trigger) and their
tests now live in core canon (core issues #63/#66); this repo no longer
vendors copies. `readiness-fields-gate.sh` sources core's `gate-lib.sh`/
`gate-lib.py` (kill switch, JSON parsing, path normalization,
Write/Edit/MultiEdit reconstruction) rather than re-deriving that machinery
(issue-36); its own section-scoped `## Checklist` semantic check stays
local, since core does not canonize that shape.
