---
proposal: docs/proposals/2026-07-26-conversational-state-machine.md
---

# Hunt record — conversational-state-machine

## after-proposal — stance 2: assume this guard goes silent when its own input is malformed — make it go silent

Verdict: FINDING — the proposal commits the new `inject-transition-rules.sh` UserPromptSubmit hook to the same "never blocks, silent exit 0 on any malformed/unreadable input" idiom already codified in the sibling hook it replaces (`capture-approval.sh`), with no exception carved out for a missing/unreadable/malformed `transition-rules.md` — so if that one data file is ever absent, empty, or unparseable, the model receives zero procedure on every subsequent prompt and nothing in the transcript indicates this happened, while `state-gate.sh`'s own table lookup (per the proposal, "allow only if that row exists ... denying otherwise") can only ever see this as "row not found" and denies transitions across the board, giving no distinguishable signal that the real cause is a missing/broken table rather than a genuinely illegal transition.
Kind: silent-failure
Seed: proposal's `inject-transition-rules.sh` (new UserPromptSubmit hook, replacing `capture-approval.sh`) is required to "follow the existing X_OFF kill-switch idiom" and the same non-blocking hook family already present in all four `<role>-cycle/hooks/capture-approval.sh` scripts.

### Reproduce
```
cd /home/jwjung/tokenmaxxxer/product-agent-rulebook
echo 'not valid json{{{' | CLAUDE_PROJECT_DIR="$PWD" bash product-cycle/hooks/capture-approval.sh
echo "exit=$?"
echo '{"prompt":"I approve the metric/threshold/decision rule, go ahead"}' | CLAUDE_PROJECT_DIR="/nonexistent-dir-xyz" bash product-cycle/hooks/capture-approval.sh
echo "exit=$?"
```

### Observed
Both invocations print nothing to stdout/stderr and exit 0 — confirmed by running the commands above (`exit=0` both times). The script's own header explicitly documents this as intended: "This hook never blocks. Malformed/unreadable input, no project root, no candidate specification file, or an ambiguous/absent approval all mean: emit nothing, exit 0." The proposal explicitly directs the new injector hook to be built in this same family (same `X_OFF` idiom, same hook slot, replacing this exact script in `hooks.json`), with no stated exception for the injector's own required input file (`transition-rules.md`) being missing or malformed. Since the injector is the *sole* channel by which procedure now reaches the model (approval-token minting/checking has been deleted from state-gate.sh), a silent exit-0 there means the model gets no transition rules at all, in a turn indistinguishable from a turn where the rules were injected but simply say "no legal transitions apply."
### Expected
An injector whose required data file is missing/empty/unparseable should not be able to silently produce a normal-looking turn with zero procedure; at minimum it should be a design constraint (stated in the proposal) that failure to read/parse `transition-rules.md` is observable — e.g. by emitting a visible warning block instead of nothing, or by the proposal explicitly requiring `state-gate.sh` to treat "table file missing/unparseable" as a distinguishable deny reason rather than an ordinary "row not present" outcome.

## before-landing — stance 3: assume the rule as written cannot hold — find the state nothing maintains

Verdict: FINDING — product-agent-rulebook's product/state.md is never created by anything, and the two hooks disagree about it in a way that deadlocks a clean checkout: the gate refuses the very write that would create the file (no row has `from = (none)`), while the injector refuses to proceed at all without the file already existing.
Kind: design-error
Seed: product-agent-rulebook 2365670 — state file newly defined as product/state.md field stage; state-gate.sh and inject-transition-rules.sh both require it to already exist and be parseable.

### Reproduce
```
cd /home/jwjung/tokenmaxxxer/product-agent-rulebook
export CLAUDE_PROJECT_DIR="$PWD"
mkdir -p product
rm -f product/state.md

# 1. UserPromptSubmit injector on a clean checkout (no product/state.md yet):
echo '{}' | bash product-cycle/hooks/inject-transition-rules.sh

# 2. The one write that could bootstrap it — creating product/state.md with stage: idle:
payload=$(python3 -c 'import json; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"product/state.md","content":"---\nstage: idle\n---\n"}}))')
echo "$payload" | bash product-cycle/hooks/state-gate.sh; echo "exit: $?"
```

### Observed
Injector: "product-cycle: transition rules could not be loaded — product/state.md is missing or unreadable ... No transition of product/state.md's `stage` field may be made until this is fixed."

Gate on the bootstrap Write: "product-cycle: refused — this transition is not in the table — `(none) -> idle` is not a listed row in transition-rules.md for product/state.md." (exit 2 — denied)

transition-rules.md's rows all start from one of `idle, scoping, researching, hypothesis-registered, measuring`; none has an empty/`(none)` `from`, and no code anywhere in the repo (checked with `find`/`grep` for `state.md`, `mkdir product`, etc.) ever creates `product/state.md`. capture-approval.sh, which might have played this role, was deleted in this same commit.

### Expected
Either a bootstrap row (`(none) | idle | ... `) that the gate accepts, or some mechanism (init script, SKILL step, or the gate itself special-casing a missing file as an allowed create) that actually produces `product/state.md` with `stage: idle` on a clean checkout. As written, the state machine can never leave state nothing, on any of the four repos' variant of this gate/injector pair for product-agent-rulebook — a brand-new checkout is permanently stuck: the agent cannot legally create the state file, and the injector refuses to say anything but "fix this" forever.
