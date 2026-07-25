---
name: error-budget-policy
description: >-
  Use when working the ops role's steady state (ops/state.md status:
  steady). Defines, per SLI, the measurement method, SLO target,
  measurement window, and consequence table Google's error-budget policy
  describes. Read (not written) by the steady -> readiness refusal rule:
  if error_budget reads exhausted, that transition is refused regardless
  of how ready the next change looks.
  Do NOT use to define what "healthy" means from scratch — this role
  consumes the SLO/measurement design feasibility already produced; it
  does not invent it.
---

# error-budget-policy — the steady-state handoff contract

Belongs to the `steady` state. Ops does not define what "healthy" means —
that is the measurement design `feasibility` already produced and `ops`
was handed at `idle -> readiness`. This skill's job is only to write down
the policy consequence, per SLI, so the `steady` refusal rule has something
mechanical to read.

## Fields, per SLI (Google's error-budget-policy shape)

- **Measurement method** — what raw signal (e.g. proportion of requests
  under a latency threshold).
- **SLO target** — the target percentage (e.g. 99.9%).
- **Measurement window** — the trailing window it is computed over (e.g.
  trailing 28 days).
- **Consequence table** — within budget: releases proceed at normal
  velocity. Budget exhausted: only P0/security-fix releases proceed until
  back within budget.

(`docs/reports/research/2026-07-27-role-practice/ops.md`, "Error budget
accounting" and "Error budget policy doc".)

## Where it is written

`ops/error-budget-policy.md`, one section per SLI:

```markdown
## <SLI name>
- measurement_method:
- slo_target:
- measurement_window:
- consequence:
    within_budget: releases proceed normally
    exhausted: only P0/security-fix releases proceed until back within budget
```

Writing this file is never gated — it is not `ops/state.md`.

## How it is read

`ops/state.md`'s `error_budget:` field (`ok` / `exhausted`) is checked
mechanically before `steady -> readiness`. If `exhausted`, the transition
is refused outright, regardless of how ready the next change looks — this
mirrors the policy's own carve-out that only P0/security-fix work proceeds
while the budget is spent. That carve-out is not automatic: route a true
P0 through the user rather than editing `error_budget:` to `ok` to unblock
it, which would be lying to the gate about a state that isn't true.

Disputes about whether the budget calculation is right, or whether an
exception applies, are the one place this policy names an explicit human
escalation path in the sourced practice (to the CTO, in Google's telling) —
if the user disputes the reading, that is a conversation to have, not a
field to silently overwrite.
