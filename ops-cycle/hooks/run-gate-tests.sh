#!/usr/bin/env bash
# Test harness for state-gate.sh. Feeds hook JSON on stdin to the gate and
# asserts exit code / deny output. Exits non-zero if any case fails.
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
gate="$script_dir/state-gate.sh"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

fail=0
pass=0

# run_case NAME EXPECTED_EXIT STATE_CONTENT(or empty for none) JSON
run_case() {
  local name="$1" expected="$2" state_content="$3" json="$4"
  local work="$tmp_root/$name"
  mkdir -p "$work/ops"
  if [ -n "$state_content" ]; then
    printf '%s' "$state_content" > "$work/ops/state.md"
  else
    rm -f "$work/ops/state.md"
  fi
  local out
  out="$(CLAUDE_PROJECT_DIR="$work" printf '%s' "$json" | CLAUDE_PROJECT_DIR="$work" bash "$gate" 2>&1)"
  local actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "PASS: $name (exit $actual)"
    pass=$((pass+1))
  else
    echo "FAIL: $name (expected exit $expected, got $actual)"
    echo "  output: $out"
    fail=$((fail+1))
  fi
}

# (a) same-state write to state file, state has NO self-loop row -> DENY
run_case "same-state-no-self-loop" 2 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: idle\n---\nnote: updated\n"}}'

# (b) same-state write, state DOES have self-loop row (rollout|rollout) -> ALLOW
run_case "same-state-with-self-loop" 0 \
$'---\nstatus: rollout\n---\n' \
'{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: rollout\n---\nnote: canary step 2\n"}}'

# (c) normal table-legal transition -> ALLOW
run_case "legal-transition" 0 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: readiness\n---\n"}}'

# (d) transition absent from table -> DENY
run_case "illegal-transition" 2 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: incident\n---\n"}}'

# (e) Bash write outside state file's directory -> ALLOW (fail-closed regression guard)
run_case "bash-write-outside-dir" 0 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Bash","tool_input":{"command":"curl -s https://example.com > /tmp/evidence-$(date +%s).json"}}'

# (f) malformed hook JSON -> DENY with visible output, never silent exit 0
malformed_out="$(cd "$tmp_root" && mkdir -p malformed/ops && printf 'not json{{{' | CLAUDE_PROJECT_DIR="$tmp_root/malformed" bash "$gate" 2>&1)"
malformed_exit=$?
if [ "$malformed_exit" -ne 0 ] && [ -n "$malformed_out" ]; then
  echo "PASS: malformed-json (exit $malformed_exit, output present)"
  pass=$((pass+1))
else
  echo "FAIL: malformed-json (exit $malformed_exit, output: '$malformed_out')"
  fail=$((fail+1))
fi

# (g) state file exists with value (none) -> DENY, rules-could-not-be-loaded
run_case "existing-none-sentinel" 2 \
$'---\nstatus: (none)\n---\n' \
'{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: idle\n---\n"}}'

# (h) state file exists with empty status value -> DENY likewise
run_case "existing-empty-status" 2 \
$'---\nstatus:\n---\n' \
'{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: idle\n---\n"}}'

# (i) state file exists with a value outside the known-state set -> DENY likewise
run_case "existing-out-of-set-status" 2 \
$'---\nstatus: bogus-typo-state\n---\n' \
'{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: idle\n---\n"}}'

# (j) state file exists with a valid value followed by trailing whitespace/CRLF
# -> treated as that valid state (not broken); a legal transition from it is ALLOWED
run_case "existing-valid-trailing-whitespace-crlf" 0 \
$'---\r\nstatus: idle   \r\n---\r\n' \
'{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: readiness\n---\n"}}'

# (k) state file genuinely absent -> the (none) -> X bootstrap row is still ALLOWED
run_case "genuinely-absent-bootstrap-allowed" 0 \
"" \
'{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: idle\n---\n"}}'

echo
echo "Results: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
exit 0
