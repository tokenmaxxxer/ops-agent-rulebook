---
proposal: docs/proposals/2026-07-28-role-workflow-plugins.md
---

# Hunt record — role-workflow-plugins

## before-landing — stance 0: assume the gate just touched is bypassable — find the bypass

Verdict: FINDING — the pre-existing `new_stage == old_stage → allow()` short-circuit in state-gate.sh lets an agent silently rewrite gated content (a registered metric/threshold/decision-rule, probe evidence, verdict basis, etc.) with zero check, zero actor:user enforcement, and zero consultation of transition-rules.md, as long as the `stage`/`status` field itself is left unchanged — confirmed in product-agent-rulebook and shared by feasibility-agent-rulebook's state-gate.sh (same `if old_status == new_status: allow()` at line 268-269).
Kind: composition
Seed: product-agent-rulebook 60bdff9 (adds `scoping -> scoping` self-loop row) and feasibility-agent-rulebook 28f2f07 gate; both gates contain a same-state short-circuit that predates and is untouched by this landing.

### Reproduce
```
cd <scratch>/demo && mkdir -p product
cat > product/state.md <<'REC'
---
stage: hypothesis-registered
metric: activation_rate
threshold: "0.30"
decision_rule: "ship if >= threshold else kill"
---
Body.
REC
export CLAUDE_PROJECT_DIR="$PWD"
GATE=/home/jwjung/tokenmaxxxer/product-agent-rulebook/product-cycle/hooks/state-gate.sh
payload=$(python3 -c '
import json
content = open("product/state.md").read().replace("activation_rate","FAKE_METRIC_NO_USER_APPROVAL").replace("0.30","0.01")
print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"product/state.md","content":content}}))
')
echo "$payload" | bash "$GATE"; echo "exit=$?"
```

### Observed
`exit=0` — the gate allows the write. The metric/threshold that was only reachable via the `researching -> hypothesis-registered` (actor: agent, with a specific proposal precondition) row can be silently swapped for an arbitrary value the agent invented, without ever going through `hypothesis-registered -> measuring` (actor: user) or any row check at all, because `stage:` in the proposed content is unchanged from disk.

### Expected
A rewrite of a gated field's recorded value (metric, threshold, decision rule, probe evidence, verdict basis) should either require re-validation against the same-state row's stated precondition, or the gate should refuse same-state writes that change anything other than fields explicitly outside the transition's recorded basis. As written, "same stage" is being treated as "nothing worth checking," which makes every content precondition in transition-rules.md advisory prose rather than an enforced gate for any write that doesn't also flip the state label.
