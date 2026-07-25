---
proposal: docs/proposals/2026-07-26-state-gate-path-resolution.md
---

# Hunt record — state-gate-path-resolution

## after-proposal — stance 0: assume the gate just touched is bypassable — find the bypass

Verdict: FINDING — the Bash write-shape detector in state-gate.sh matches only the literal filename text in the command string, so referencing the target file through a shell variable (or any other indirection) makes the command invisible to the regex and falls through to allow(), defeating the proposal's fail-closed guarantee for Bash writes.
Kind: silent-failure
Seed: feasibility-agent-rulebook/feasibility-cycle/hooks/state-gate.sh (same pattern present in product-cycle, review-cycle, ops-cycle state-gate.sh — write_shapes regex requires the literal record filename adjacent to a redirect/tee/sed/cp/mv token)

### Reproduce
```
cd /home/jwjung/tokenmaxxxer/feasibility-agent-rulebook/feasibility-cycle
export CLAUDE_PROJECT_DIR=/tmp/scratch-proj   # dir containing feasibility-record.md with status: probing
payload='{"tool_name":"Bash","tool_input":{"command":"f=feasibility-record.md; echo \"status: verdict\" > $f"}}'
echo "$payload" | bash hooks/state-gate.sh; echo "EXIT: $?"
```

### Observed
`EXIT: 0` (allow) — the gate lets the Bash call through because its command-string regex `>>?\s*[^|&;]*\bfeasibility-record\.md\b` never matches (the filename appears in an assignment, not adjacent to the redirect operator), even though running the same shell command does overwrite `feasibility-record.md` to `status: verdict`, silently completing an unauthorized `probing -> verdict` transition with no token check at all.

### Expected
Per the proposal, any Bash write whose target cannot be statically resolved to a non-record path should be denied (fail closed). Any Bash command using indirection (variables, command substitution, string concatenation, glob patterns, etc.) around the record filename should also be denied, not allowed by default just because the literal string didn't appear adjacent to a redirect token.

## before-landing — stance 1: assume this change and another plugin's rule cancel each other — find the pair

Verdict: FINDING — the rewritten state-gate.sh's fail-closed "maybe" case fires on ANY Bash command with an unresolvable write-shaped target (redirect/tee/cp/mv/sed -i/dd/install/heredoc/eval), globally, before checking whether the command has anything to do with ops/state.md — so it denies commands the ops role's own readiness-checklist skill requires it to run (capturing a pointable artifact, e.g. redirecting a health-check response to an evidence file with a computed name) even though state.md is nowhere in the command.
Kind: composition
Seed: ops-agent-rulebook commit c718500 (ops-cycle/hooks/state-gate.sh), cross-checked against ops-cycle/skills/readiness-checklist/SKILL.md's requirement that every `yes` checklist item point at "something real: a dashboard URL, a runbook path, a config key, a file in this repo" — i.e. the role is expected to run ordinary Bash commands to produce such artifacts.

### Reproduce
```
mkdir -p /tmp/ops-repro/ops && cat > /tmp/ops-repro/ops/state.md <<'STATE'
---
status: idle
---
STATE
cd /tmp/ops-repro
export CLAUDE_PROJECT_DIR="$PWD"
payload='{"tool_name":"Bash","tool_input":{"command":"curl -s https://dashboard.example.com/health > /tmp/evidence-$(date +%s).json"}}'
echo "$payload" | bash /home/jwjung/tokenmaxxxer/ops-agent-rulebook/ops-cycle/hooks/state-gate.sh
echo "exit=$?"
```

### Observed
```
ops-cycle: refused — this Bash command has a write-shaped construct (redirect/tee/cp/mv/sed -i/dd/install/heredoc/eval) whose target path cannot be resolved statically (a variable, command substitution, glob, indirection, or eval), or otherwise names ops/state.md in a shape this gate does not recognize as a plain write. Rule: unresolvable Bash write targets deny fail-closed rather than being assumed safe against ops/state.md.
exit=2
```
The command never mentions ops/state.md, ops/, or any state-file path at all — it writes evidence to /tmp with a timestamp-derived filename — yet it is denied with an ops/state.md-specific message, under the PreToolUse hook whose matcher is `.*` (every tool call in the session, per ops-cycle/hooks/hooks.json).

### Expected
Per the gate's own header comment ("A write that does not touch ops/state.md is none of this gate's business and is allowed") and docs/specs/state-machine.md's "path-not-tool rule", a command with no relation to ops/state.md should be allowed regardless of whether its own target is statically resolvable. Instead the `EVAL_RE`/dynamic-target checks in `touches_state_file()` return `"maybe"` (deny) before ever comparing the command's target against `state_abs`, so any ordinary evidence-gathering command the readiness-checklist skill instructs the role to run — using a variable, `$(...)`, or a computed filename, which is normal for timestamped/health-check artifacts — is refused as if it targeted the state file.
