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

    ops/hooks/directive.sh              SessionStart — the four facets:
                                        research (how comparable systems roll
                                        out and fail), survey (PRR seven
                                        dimensions + current error budget),
                                        proposal (rollout plan with
                                        pre-declared per-step thresholds),
                                        judgment (pointable-artifact rule,
                                        error-budget refusal, human-reviewed
                                        postmortems)
    ops/hooks/record-fields-gate.sh     s20 minimum content on the record
    ops/hooks/trailer-gate.sh           commits staging docs/issue-<n>/** carry
                                        `Subject: issue-<n>`
    ops/hooks/handbook-trigger-gate.sh  s21 same-turn handbook sync
    ops/skills/                         readiness-checklist, rollout-plan,
                                        error-budget-policy, postmortem
    tests/                              repo-level checks (never installed)

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

Kill switch: `OPS_CYCLE_OFF=1`.

## Run the checks

    /bin/bash tests/parse-check.sh
    /bin/bash tests/run-gate-tests.sh
    /bin/bash tests/deny-only-check.sh
