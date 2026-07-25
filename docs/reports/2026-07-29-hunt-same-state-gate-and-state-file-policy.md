---
proposal: docs/proposals/2026-07-29-same-state-gate-and-state-file-policy.md
---

# Hunt record — same-state-gate-and-state-file-policy

## after-proposal — stance 1: assume this change and another plugin's rule cancel each other — find the pair

Verdict: FINDING — `product-agent-rulebook`'s `hypothesis-testing` skill documents a same-state edit at `measuring` (update collected-data-notes/other fields while `status: measuring`, only `threshold` is forbidden) that the fixed gate now denies wholesale, because `transition-rules.md` has no `measuring | measuring` self-loop row.
Kind: composition
Seed: product-agent-rulebook/product-cycle/hooks/state-gate.sh (same-state short-circuit removal), product-agent-rulebook/product-cycle/skills/hypothesis-testing/SKILL.md step 5, product-agent-rulebook/product-cycle/hooks/transition-rules.md

### Reproduce
```
# Copy the repo, apply the proposal's own described fix (delete the
# `if new_stage == old_stage: allow()` branch and its comment) to
# product-cycle/hooks/state-gate.sh, leaving transition-rules.md untouched
# (per the proposal: "No transition-rules.md file is edited by this
# proposal ... no new self-loop is added anywhere").

mkdir -p product
cat > product/state.md <<'STATE'
---
stage: measuring
metric: 7-day activation rate
threshold: >= 20%
decision_rule: if >=20 persist, else kill
---
STATE

PAYLOAD=$(python3 - <<'PY'
import json
old_content = open("product/state.md").read()
new_content = old_content + "\ncollected-data notes: day 3, tracking at 18%\n"
print(json.dumps({
  "tool_name": "Write",
  "tool_input": {"file_path": "product/state.md", "content": new_content}
}))
PY
)
echo "$PAYLOAD" | CLAUDE_PROJECT_DIR="$PWD" bash product-cycle/hooks/state-gate.sh
echo "exit code: $?"
```

### Observed
```
product-cycle: refused — this transition is not in the table — `measuring -> measuring` is not a listed row in transition-rules.md for product/state.md.
exit code: 2
```

### Expected
`hypothesis-testing/SKILL.md` step 5 tells the model, in the role's own
documented workflow: "Update other fields (e.g. collected-data notes)
freely; do not touch `threshold`" while `status: measuring`. The proposal
removes the mechanism (the same-state short-circuit) that made that
sentence true without ever revisiting the sentence itself or adding the
`measuring | measuring` self-loop row that would keep it true. The
proposal's own "no new self-loop rows" constraint, applied uniformly,
silently breaks this specific skill's documented same-state write, which
after the fix is denied identically to the illegal `metric`/`threshold`
rewrite the proposal set out to block — the gate now cannot tell "append a
progress note" from "quietly rewrite the registered hypothesis," the exact
distinction the skill instructs the model to preserve.

## before-landing — stance 2: assume this guard goes silent when its own input is malformed — make it go silent

Verdict: FINDING — a state file whose on-disk `stage`/`status` value is the literal string `(none)` (the gate's own bootstrap sentinel for "file does not exist") is silently treated as if the file did not exist, allowing any `(none) -> X` row to fire even though the file exists and is malformed (its stage value is not a member of the real state set).
Kind: silent-failure
Seed: product-agent-rulebook/product-cycle/hooks/state-gate.sh (and siblings feasibility/review/ops-agent-rulebook/*/hooks/state-gate.sh), all of which use the string `(none)` both as (a) the synthetic old-state value substituted when product/state.md doesn't exist, and (b) an ordinary string that is otherwise indistinguishable from a real `stage:` field value once parsed from an existing file.

### Reproduce
```
cd /home/jwjung/tokenmaxxxer/product-agent-rulebook
gate=product-cycle/hooks/state-gate.sh
work=/tmp/prodtest-repro
rm -rf "$work"; mkdir -p "$work/product"
cat > "$work/product/state.md" <<'STATE'
---
stage: (none)
metric: x
threshold: y
---
STATE
payload='{"tool_name":"Write","tool_input":{"file_path":"product/state.md","content":"---\nstage: idle\nmetric: x\nthreshold: y\n---\n"}}'
printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$work" bash "$gate"
echo "exit=$?"
```

### Observed
No stderr output at all, `exit=0` (silent allow). The gate parsed the existing, malformed `product/state.md` (whose `stage:` value `(none)` is not a real state per transition-rules.md), matched it against the `(none) | idle` bootstrap row, and let the write through — exactly the "unparseable/unrecognized state value silently treated as an allowed case" failure mode named in the stance.

### Expected
Per the gate's own stated fail-closed policy ("anything this hook cannot parse or resolve is a DENY, never an allow"), a `stage:` value of `(none)` read from an *existing* file is not the same condition as the file being absent, and is not a value in the real state set (idle, scoping, researching, hypothesis-registered, measuring, decided). It should be denied with "the transition rules could not be loaded — product/state.md: `stage:` field is not a recognized state (`(none)`)" or equivalent, not silently accepted as if the file were missing.
