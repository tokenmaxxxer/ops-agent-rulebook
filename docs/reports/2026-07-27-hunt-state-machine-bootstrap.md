---
proposal: docs/proposals/2026-07-27-state-machine-bootstrap.md
---

# Hunt record — state-machine-bootstrap

## before-landing — stance 4: assume the write set cannot carry this work — find the path the build will need that the proposal does not list.

Verdict: FINDING — the new `(none) -> <initial>` bootstrap transition creates a state file that two of the four repos' own `.gitignore` (ops-agent-rulebook, feasibility-agent-rulebook) ignore inside the plugin checkout itself, so the first-ever bootstrap write silently never reaches git in exactly the self-test scenario the `.gitignore` comments say they're guarding against.
Kind: silent-failure
Seed: `(none)` bootstrap rows added to product/feasibility/review/ops transition-rules.md and state-gate.sh/inject-transition-rules.sh; write set was limited to transition-rules.md, state-gate.sh, inject-transition-rules.sh, docs/specs/agent-roles.md per repo — `.gitignore` was never in scope.

### Reproduce
```
cd /home/jwjung/tokenmaxxxer/ops-agent-rulebook
mkdir -p ops && printf -- '---\nstatus: idle\n---\n' > ops/state.md
git status --short ops/state.md      # -> empty, nothing to report
git check-ignore -v ops/state.md     # -> .gitignore:4:ops/state.md   ops/state.md

cd /home/jwjung/tokenmaxxxer/feasibility-agent-rulebook
printf -- '---\nstatus: idle\n---\n' > feasibility-record.md
git status --short feasibility-record.md   # -> empty
git check-ignore -v feasibility-record.md  # -> .gitignore:5:feasibility-record.md   feasibility-record.md
```

### Observed
Both repos' own `.gitignore` ignore their state file by name (`ops/state.md`, `feasibility-record.md`), each with a comment explaining this is defensive "in case a test sandbox/smoke test is ever run from this checkout." The new `(none) -> idle` row is exactly the transition state-gate.sh/inject-transition-rules.sh now treat as ordinary (no longer an error) the first time the role writes its state file — inside such a self-test run that write is silently swallowed by git: `git status` shows nothing, no error, no diff, indistinguishable from a role that never ran.

### Expected
Either the state file's first write should be visible to git in a self-test/smoke-test run of these repos (e.g. a scoped exception or a check outside `.gitignore`), or the bootstrap-row proposal should have flagged that its target file collides with an existing ignore rule in two of the four repos it touches — the write set (limited to transition-rules.md/state-gate.sh/inject-transition-rules.sh/agent-roles.md) has no path to reconcile this, since `.gitignore` was never listed.
