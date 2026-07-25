---
proposal: docs/proposals/2026-07-30-none-sentinel-collision.md
---

# Hunt record — none-sentinel-collision

## after-proposal — stance 3: assume the rule as written cannot hold — find the state nothing maintains

Verdict: FINDING — the proposal amends `docs/specs/agent-roles.md` to claim the known-state
membership check "applies to both the injector and the `PreToolUse` gate," but the frozen
`files:` list and the entire "What will be done" section only touch each repo's
`state-gate.sh`/`run-gate-tests.sh` — `inject-transition-rules.sh` is never in scope in any of
the four repos, so after this proposal lands the spec will describe injector behavior that the
injector does not have and nothing will maintain that claim.
Kind: design-error
Seed: docs/proposals/2026-07-30-none-sentinel-collision.md; four `inject-transition-rules.sh`
siblings under product-agent-rulebook/product-cycle/hooks/, feasibility-agent-rulebook/
feasibility-cycle/hooks/, review-agent-rulebook/review-cycle/hooks/, ops-agent-rulebook/
ops-cycle/hooks/ — none listed in the proposal's `files:` frontmatter.

### Reproduce
```
cd /home/jwjung/tokenmaxxxer/product-agent-rulebook
mkdir -p /tmp/sandbox/product
export CLAUDE_PROJECT_DIR=/tmp/sandbox
printf -- '---\nstage: (none)\n---\n' > "$CLAUDE_PROJECT_DIR/product/state.md"
bash product-cycle/hooks/inject-transition-rules.sh; echo "EXIT=$?"
```

### Observed
```
product-cycle: current state — stage: (none)
Legal transitions out of `(none)`:
| condition (precondition) | allowed transition | actor |
|---|---|---|
| product/state.md does not yet exist; the agent creates it with stage `idle` as the initial state | (none) -> idle | agent |
...
EXIT=0
```
The injector treats an *existing* `product/state.md` whose `stage` value is the literal
sentinel `(none)` exactly like a genuinely-absent file: it prints the bootstrap row as if the
file had never been created, with exit 0 and no warning — the same collision the proposal
is fixing in `state-gate.sh`, left live in `inject-transition-rules.sh`. Grepping the other
three repos' injectors (feasibility, review, ops) shows the same pattern: `current_stage`/
`old_status`/current-state read from an existing file is checked only for
present-and-non-empty, never for membership in the role's known-state set, and none of the
four injectors are in the proposal's file list to be fixed alongside the gate.

### Expected
Either the proposal's file list and "What will be done" section should include each repo's
`inject-transition-rules.sh` (so the injector enforces the same known-state check the spec
amendment says it does), or the `agent-roles.md` amendment should not claim the check applies
to the injector. As written, the built system will have a spec that documents a guarantee one
of its two enforcement points doesn't provide, and nothing — no test, no code path — keeps
that sentence honest.

## before-landing — stance 4: assume the write set cannot carry this work — find the path the build will need that the proposal does not list

Verdict: NO FINDING
Seed: the four `state-gate.sh`, four `inject-transition-rules.sh`, four `run-gate-tests.sh`,
and `docs/specs/agent-roles.md` across feasibility-agent-rulebook, ops-agent-rulebook,
product-agent-rulebook, review-agent-rulebook (branch `none-sentinel`); candidates probed:
each repo's `hooks/hooks.json`, `.claude-plugin/marketplace.json`, `skills/*/SKILL.md`,
`README.md`, `docs/specs/state-machine.md`, and each `transition-rules.md` (deliberately not
in the write set).

Checked and ruled out: `hooks.json` registrations match how `state-gate.sh`/
`inject-transition-rules.sh` are actually invoked (UserPromptSubmit / PreToolUse
Write|Edit|NotebookEdit|Bash) in all four repos, with no hardcoded state list or filename
beyond the plugin-relative path to its own `transition-rules.md`, which exists in all four.
Each repo's hardcoded state-file path (`feasibility-record.md`, `ops/state.md`,
`product/state.md`, `review-record.md`) matches what `README.md`/`docs/specs/state-machine.md`
document and what `run-gate-tests.sh` exercises. Ran all four `run-gate-tests.sh`: 11/12/13/12
passed, 0 failed. Cross-checked every state name in `docs/specs/agent-roles.md`'s per-role
tables against each repo's `transition-rules.md` from/to columns — all match exactly (product:
idle/scoping/researching/hypothesis-registered/measuring/decided; feasibility: idle/scoped/
probing/verdict-provisional/verdict; review: idle/scoped/auditing/draft-reported/reported; ops:
idle/readiness/rollout/steady/incident).

Did find two pieces of doc drift under the hunt's candidate list —
`feasibility-cycle/skills/feasibility-cycle/SKILL.md` lists only `idle, scoped, probing,
verdict` (omitting `verdict-provisional`), and `feasibility-cycle/skills/feasibility-cycle/
SKILL.md` plus `docs/specs/state-machine.md` still reference a nonexistent
`hooks/capture-approval.sh` — but both predate this diff by several commits (from the
pre-`same-state-gate` token-based-approval architecture) and are unaffected by it: `git diff
same-state-gate none-sentinel` touches only `state-gate.sh`, `inject-transition-rules.sh`, and
`run-gate-tests.sh` in each repo, never `transition-rules.md`, `SKILL.md`, `README.md`, or
`state-machine.md`. Neither is a path the *build* newly depends on; both are pre-existing
inaccuracies the proposal does not touch, worsen, or rely on.

No file outside the stated write set is read, written, or newly required for the described
known-state-membership behavior to work correctly in any of the four repos.
