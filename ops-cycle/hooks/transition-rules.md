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
(none) | idle | user | ops/state.md does not yet exist; user initializes the ops cycle
idle | readiness | user | user hands a merged change plus measurement design
readiness | rollout | agent | checklist complete, every yes item has a non-empty artifact
rollout | steady | user | user states an explicit promotion approval in their own turn
steady | incident | agent | a monitored signal crosses its declared threshold
incident | steady | agent | postmortem field is non-empty, naming a filed postmortem
steady | readiness | user | user hands a new change and error_budget is not exhausted
