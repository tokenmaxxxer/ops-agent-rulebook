#!/usr/bin/env bash
# Test harness for the five procedure-enforcing gates added alongside
# state-gate.sh. Each gate gets at least one crafted VIOLATION (must be
# refused, exit != 0) and one COMPLIANT case (must pass, exit 0). Fails the
# suite if any case does not match its expected outcome.
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

pass=0
fail=0

# run NAME GATE EXPECTED_EXIT PROJECT_DIR JSON
run() {
  local name="$1" gate="$2" expected="$3" projdir="$4" json="$5"
  local out actual
  out="$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$projdir" bash "$script_dir/$gate" 2>&1)"
  actual=$?
  if { [ "$expected" = "deny" ] && [ "$actual" -ne 0 ]; } || { [ "$expected" = "allow" ] && [ "$actual" -eq 0 ]; }; then
    echo "PASS: $name ($gate -> exit $actual, expected $expected)"
    pass=$((pass+1))
  else
    echo "FAIL: $name ($gate -> exit $actual, expected $expected)"
    echo "  output: $out"
    fail=$((fail+1))
  fi
}

# A plausible project root: git work-tree with the contract present.
proj="$(mktemp -d)"
git init -q "$proj"
mkdir -p "$proj/docs/specs" "$proj/docs/reports/records/checkout-flow" \
         "$proj/docs/reports/records/checkout-flow/postmortems" \
         "$proj/docs/handbooks" "$proj/docs/decisions"
printf '# role-handoff-contract\n' > "$proj/docs/specs/role-handoff-contract.md"

OPEN_RECORD='---\nkind: ops-record\nsubject: checkout-flow\nproduced_by: ops\nupstream:\n  - path: docs/reports/records/checkout-flow/feasibility.md\n    sha: abc123\nloop_state: readiness\n---\n\n## What was done\nStood up the readiness checklist.\n\n## Why\nPromotion to rollout needs a pointable-artifact checklist; chose the release-ops path over ad hoc canary because it is auditable.\n\n## Next steps\nPromote first canary step once the metric check is clean.\n\n## Open-finding resolution path\nNo open findings; any raised go to coding via a finding block.\n'
BAD_RECORD='---\nkind: ops-record\nsubject: checkout-flow\nloop_state: readiness\n---\n\nStood up the checklist.\n'

# ---- record-fields-gate.sh -------------------------------------------
run "record-fields: compliant open record" record-fields-gate.sh allow "$proj" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"docs/reports/records/checkout-flow/ops.md\",\"content\":\"$OPEN_RECORD\"}}"
run "record-fields: missing required sections" record-fields-gate.sh deny "$proj" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"docs/reports/records/checkout-flow/ops.md\",\"content\":\"$BAD_RECORD\"}}"
run "record-fields: non-record write passes" record-fields-gate.sh allow "$proj" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"src/app.py\",\"content\":\"print(1)\"}}"
run "record-fields: malformed payload fails closed" record-fields-gate.sh deny "$proj" \
  'not json{{{'

# ---- path-ownership-gate.sh ------------------------------------------
run "path-ownership: own ops.md allowed" path-ownership-gate.sh allow "$proj" \
  '{"tool_name":"Write","tool_input":{"file_path":"docs/reports/records/checkout-flow/ops.md","content":"x"}}'
run "path-ownership: own postmortems subdir allowed" path-ownership-gate.sh allow "$proj" \
  '{"tool_name":"Write","tool_input":{"file_path":"docs/reports/records/checkout-flow/postmortems/outage-1.md","content":"x"}}'
run "path-ownership: foreign role record refused" path-ownership-gate.sh deny "$proj" \
  '{"tool_name":"Write","tool_input":{"file_path":"docs/reports/records/checkout-flow/qa.md","content":"x"}}'
run "path-ownership: foreign subdir refused" path-ownership-gate.sh deny "$proj" \
  '{"tool_name":"Write","tool_input":{"file_path":"docs/reports/records/checkout-flow/spikes/probe-1.md","content":"x"}}'
run "path-ownership: outside records tree passes" path-ownership-gate.sh allow "$proj" \
  '{"tool_name":"Write","tool_input":{"file_path":"src/app.py","content":"x"}}'
run "path-ownership: malformed payload fails closed" path-ownership-gate.sh deny "$proj" \
  'not json{{{'

# ---- doc-bucket-gate.sh ----------------------------------------------
run "doc-bucket: inside a bucket allowed" doc-bucket-gate.sh allow "$proj" \
  '{"tool_name":"Write","tool_input":{"file_path":"docs/reports/2026-07-26-canary.md","content":"x"}}'
run "doc-bucket: outside buckets refused" doc-bucket-gate.sh deny "$proj" \
  '{"tool_name":"Write","tool_input":{"file_path":"docs/random-note.md","content":"x"}}'
run "doc-bucket: outside docs passes" doc-bucket-gate.sh allow "$proj" \
  '{"tool_name":"Write","tool_input":{"file_path":"src/app.py","content":"x"}}'
run "doc-bucket: malformed payload fails closed" doc-bucket-gate.sh deny "$proj" \
  'not json{{{'

# ---- handbook-trigger-gate.sh (commit-time) --------------------------
# Compliant: stage an env-file change AND a handbook update, then commit.
git -C "$proj" config user.email t@t && git -C "$proj" config user.name t
printf 'FOO=1\n' > "$proj/.env.example"
printf '# checkout handbook\n' > "$proj/docs/handbooks/checkout.md"
git -C "$proj" add .env.example docs/handbooks/checkout.md
run "handbook-trigger: op-surface + handbook update allowed" handbook-trigger-gate.sh allow "$proj" \
  '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}'
# Violation: stage ONLY an env-file change, no handbook.
git -C "$proj" reset -q
git -C "$proj" add .env.example
run "handbook-trigger: op-surface without handbook refused" handbook-trigger-gate.sh deny "$proj" \
  '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}'
run "handbook-trigger: non-git-commit bash passes" handbook-trigger-gate.sh allow "$proj" \
  '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
run "handbook-trigger: malformed payload fails closed" handbook-trigger-gate.sh deny "$proj" \
  'not json{{{'

# ---- trailer-gate.sh (commit-time) -----------------------------------
# In-progress unit: an ops record with a non-terminal loop_state.
printf -- "$OPEN_RECORD" > "$proj/docs/reports/records/checkout-flow/ops.md"
run "trailer: in-progress commit with trailers allowed" trailer-gate.sh allow "$proj" \
  '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"do the thing\n\nSubject: checkout-flow\nKind: ops-record\""}}'
run "trailer: in-progress commit missing trailers refused" trailer-gate.sh deny "$proj" \
  '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"do the thing\""}}'
# No unit in progress: settle the record to steady -> trailer not required.
STEADY_RECORD='---\nkind: ops-record\nsubject: checkout-flow\nloop_state: steady\n---\n\n## What was done\nx\n\n## Why\nx\n'
printf -- "$STEADY_RECORD" > "$proj/docs/reports/records/checkout-flow/ops.md"
run "trailer: no in-progress unit, bare commit allowed" trailer-gate.sh allow "$proj" \
  '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"anything\""}}'
run "trailer: non-git-commit bash passes" trailer-gate.sh allow "$proj" \
  '{"tool_name":"Bash","tool_input":{"command":"echo hi"}}'
run "trailer: malformed payload fails closed" trailer-gate.sh deny "$proj" \
  'not json{{{'

# ---- fail-closed-on-internal-error --------------------------------------
# docs/proposals/2026-07-26-gates-fail-closed-on-internal-error.md: a
# crash-inducing payload must resolve to exit 2 (DENY) EXACTLY, never an
# uncaught exit 1 (which PreToolUse treats as fail-open). Assert the exact
# code, not just "non-zero".
run2() {
  local name="$1" gate="$2" json="$3"
  local out actual
  out="$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$proj" bash "$script_dir/$gate" 2>&1)"
  actual=$?
  if [ "$actual" -eq 2 ]; then
    echo "PASS: $name ($gate -> exit 2 DENY on crash payload)"
    pass=$((pass+1))
  else
    echo "FAIL: $name ($gate -> expected exit 2, got $actual)"
    echo "  output: $out"
    fail=$((fail+1))
  fi
}

# Null byte in file_path -> os.path.realpath raises ValueError in the judge;
# the python excepthook + shell rc-map must turn it into exit 2.
NULLPATH='docs/reports/records/checkout-flow/\u0000ops.md'
run2 "crash: record-fields null-byte path -> exit 2" record-fields-gate.sh \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$NULLPATH\",\"content\":\"x\"}}"
run2 "crash: path-ownership null-byte path -> exit 2" path-ownership-gate.sh \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$NULLPATH\",\"content\":\"x\"}}"
run2 "crash: doc-bucket null-byte path -> exit 2" doc-bucket-gate.sh \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"docs/\\u0000x.md\",\"content\":\"x\"}}"
# Commit-time gates: malformed JSON is the crash vector -> exact exit 2.
run2 "crash: handbook-trigger malformed JSON -> exit 2" handbook-trigger-gate.sh \
  'not json{{{'
run2 "crash: trailer malformed JSON -> exit 2" trailer-gate.sh \
  'not json{{{'

rm -rf "$proj"
echo
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
exit 0
