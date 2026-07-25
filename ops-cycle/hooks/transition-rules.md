# ops-cycle transition rules

Single source of truth for legal transitions in the `ops` role's state
machine (`docs/specs/state-machine.md`; enforced by `state-gate.sh`). Both
`inject-transition-rules.sh` (UserPromptSubmit) and `state-gate.sh`
(PreToolUse) read this file. States and rows below are derived from the
`VALID_STATES` / `TRANSITIONS` sets already implemented in `state-gate.sh`
and from `docs/specs/state-machine.md`'s "Fires on" column — nothing here
is invented.

States: `idle`, `readiness`, `rollout`, `steady`, `incident`.

Bootstrap convention: when `ops/state.md` does not exist, the current
state is the synthetic literal `(none)` — not `idle`, not an error. `(none)`
is never a legal `to` value; nothing transitions back into it, and deleting
the state file is not a transition.

from | to | actor | precondition
--- | --- | --- | ---
(none) | idle | agent | ops/state.md does not yet exist; agent initializes the ops cycle — changed from `user`: no sourced practice puts a human gate on state-file creation itself, only on in-flight decisions below (docs/proposals/2026-07-28-role-workflow-plugins.md)
idle | readiness | user | user hands a merged change plus measurement design
readiness | rollout | agent | checklist complete, every yes item has a non-empty pointable artifact
rollout | rollout | agent | canary step promotion when the metric/threshold check is clean against a pre-defined, unambiguous threshold — Argo/Flagger/Kayenta auto-promote loops are real production practice for exactly this
rollout | incident | agent | canary metric breach past a hard pre-set threshold — sourced as automatic in mature tooling; raising costs nothing and understating costs more
rollout | steady | user | user states an explicit promotion approval in their own turn — traffic cutover to full/production is a human call even when the tooling that gets it to the last canary step is automatic
steady | incident | agent | a monitored signal crosses its declared threshold
incident | steady | user | postmortem is filed *and* a human ("senior engineers," per the sourced practice) has reviewed it and is satisfied with the document and its action items — a bare non-empty postmortem field is not sufficient
incident | readiness | user | postmortem action-item sign-off gates re-entry into a release cycle for the affected surface specifically, distinct from the general incident -> steady close
steady | readiness | user | user hands a new change and the error budget is not exhausted
