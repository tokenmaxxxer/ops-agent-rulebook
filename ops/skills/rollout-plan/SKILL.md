---
name: rollout-plan
description: >-
  Use when working the ops role's rollout state (ops/state.md status:
  rollout). Asks the user for (or derives from the readiness record) the
  traffic curve and per-step metric thresholds that gate progressive
  delivery, and writes them to ops/rollout-plan.md. The rollout -> rollout
  (canary step promotion) and rollout -> incident (breach) agent rows in
  transition-rules.md read this file's thresholds mechanically — do not
  invent a threshold in the moment; it must already be written here.
  Do NOT use for the readiness checklist (readiness-checklist) or for the
  postmortem written after an incident (postmortem).
---

# rollout-plan — the canary/progressive-delivery plan

Belongs to the `rollout` state. Entered once `readiness -> rollout` fires
(checklist complete, every yes item has a pointable artifact).

## What it asks the user for

Either directly, or derived from the readiness record if already implied
there:

- The traffic curve: per-step traffic percentage (e.g. 5% -> 25% -> 50% ->
  100%).
- Wait/bake time per step.
- The metric queries evaluated at each step (request error rate, p99
  latency, and at least one business metric — the commonly tracked triad).
- The pass/fail/inconclusive threshold for each metric at each step —
  either Kayenta-style score bands (`pass >= 90`, `marginal >= 75`) or
  Flagger-style fields (`interval`, `stepWeight`, `maxWeight`, `threshold`:
  the number of failed checks tolerated before automatic abort).

(`docs/reports/research/2026-07-27-role-practice/ops.md`, "Progressive
rollout (canary / staged deploy)".)

## What it writes, and where

`ops/rollout-plan.md`, one entry per step:

```markdown
## Step 1 — 5% traffic
- bake_time: 10m
- metrics:
  - name: error_rate
    query: <metric query>
    threshold: pass >= 90 / marginal >= 75   # or Flagger-style threshold count
  - name: p99_latency
    query: <metric query>
    threshold: <value>
- result: pending   # pending | pass | marginal | fail
```

This file is not `ops/state.md` — writing it is never gated. Only the
resulting write to `ops/state.md` (the step promotion or the incident
declaration) is gated, and only on table membership.

## How the agent-owned rows read it

- `rollout -> rollout`: when a step's `result` comes back clean against its
  declared threshold, the agent promotes to the next step itself — no
  human turn required. This mirrors Argo Rollouts/Flagger/Kayenta's
  auto-promote loops, which are real, mature production practice for
  exactly this decision.
- `rollout -> incident`: when a step's `result` is a breach past its hard
  pre-set threshold, the agent declares the incident itself, immediately,
  without waiting to be asked. Raising costs nothing; understating costs
  more (PostHog's "when in doubt, raise it anyway," carried into the
  companion interaction research for `ops`).
- `rollout -> steady`: NOT agent-owned. Even once the last canary step
  passes, cutover to full/production traffic is a human call in every
  source that names this moment — ask the user for an explicit promotion
  approval in their own turn before writing `status: steady` (see
  `readiness-checklist`'s "Working `rollout -> steady`" section for the
  exact wording expected).
