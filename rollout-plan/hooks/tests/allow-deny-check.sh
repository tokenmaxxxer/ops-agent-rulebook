#!/usr/bin/env bash
# Allow/deny fixture for rollout-plan-fields-gate.sh (issue-27/33,
# extended for issue-39's mandatory 7-case list: Edit reconstruction,
# MultiEdit replace_all, malformed JSON x3 shapes, kill-switch
# unrecognized-value, absolute/./-prefixed path parity, missing-core
# deny, plus the Bash-bypass fixture).
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
gate="$here/../rollout-plan-fields-gate.sh"
fail=0

run() {
  local label="$1" expect="$2" content="$3"
  td="$(mktemp -d)"
  payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"ops/rollout-plan.md","content":sys.argv[1]},"cwd":sys.argv[2]}))' "$content" "$td")"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" bash "$gate" >/dev/null 2>&1
  rc=$?
  rm -rf "$td"
  if [ "$rc" = "$expect" ]; then
    echo "ok    $label (rc=$rc)"
  else
    echo "FAIL  $label — expected rc=$expect, got rc=$rc"
    fail=1
  fi
}

run_payload() {
  local label="$1" expect="$2" payload="$3"; shift 3
  printf '%s' "$payload" | env "$@" bash "$gate" >/dev/null 2>&1
  rc=$?
  if [ "$rc" = "$expect" ]; then
    echo "ok    $label (rc=$rc)"
  else
    echo "FAIL  $label — expected rc=$expect, got rc=$rc"
    fail=1
  fi
}

missing_threshold='## Step 1
- name: error_rate
- result: pass'

pending='## Step 1
- name: error_rate
- threshold:
- result: pending'

thresholded='## Step 1
- name: error_rate
  threshold: pass >= 90
- result: pass'

run "result: pass with missing threshold -> deny" 2 "$missing_threshold"
run "result: pending, no threshold required -> allow" 0 "$pending"
run "fully thresholded and result: pass -> allow" 0 "$thresholded"

# --- Edit case: an Edit that flips result to pass while a threshold is
# still unset -> deny; the same Edit after a threshold was filled in ->
# allow (issue-39 mandatory case).
td="$(mktemp -d)"
mkdir -p "$td/ops"
printf '%s' '## Step 1
- name: error_rate
- threshold:
- result: pending' > "$td/ops/rollout-plan.md"
payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":"ops/rollout-plan.md","old_string":"result: pending","new_string":"result: pass"},"cwd":sys.argv[1]}))' "$td")"
run_payload "Edit: result flips to pass, threshold still unset -> deny" 2 "$payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

td="$(mktemp -d)"
mkdir -p "$td/ops"
printf '%s' '## Step 1
- name: error_rate
  threshold: pass >= 90
- result: pending' > "$td/ops/rollout-plan.md"
payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":"ops/rollout-plan.md","old_string":"result: pending","new_string":"result: pass"},"cwd":sys.argv[1]}))' "$td")"
run_payload "Edit: result flips to pass, threshold pre-declared -> allow" 0 "$payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

# --- MultiEdit case: mix of replace_all true/false in one call.
td="$(mktemp -d)"
mkdir -p "$td/ops"
printf '%s' '## Step 1
- name: error_rate
  threshold:
- result: pending
## Step 2
- name: latency
  threshold:
- result: pending' > "$td/ops/rollout-plan.md"
payload="$(python3 -c '
import json, sys
edits = [
    {"old_string": "threshold:", "new_string": "threshold: pass >= 90", "replace_all": True},
    {"old_string": "- result: pending\n## Step 2", "new_string": "- result: pass\n## Step 2", "replace_all": False},
]
print(json.dumps({"tool_name": "MultiEdit", "tool_input": {"file_path": "ops/rollout-plan.md", "edits": edits}, "cwd": sys.argv[1]}))
' "$td")"
run_payload "MultiEdit: replace_all fills both thresholds, step 1 result: pass -> allow" 0 "$payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

# --- Malformed-JSON cases: truncated, non-object, and empty payload all
# deny rather than proceed on a best-effort guess (issue-39 mandatory
# case).
run_payload "malformed JSON (truncated) -> deny" 2 '{"tool_name": "Write", "tool_inp' CLAUDE_PROJECT_DIR=/tmp
run_payload "malformed JSON (top-level array) -> deny" 2 '["not", "an", "object"]' CLAUDE_PROJECT_DIR=/tmp
run_payload "malformed JSON (empty payload) -> deny" 2 '' CLAUDE_PROJECT_DIR=/tmp

# --- Kill-switch case: an unrecognized value must NOT disable the gate
# (issue-39 mandatory case).
td="$(mktemp -d)"
payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"ops/rollout-plan.md","content":sys.argv[1]},"cwd":sys.argv[2]}))' "$missing_threshold" "$td")"
run_payload "kill switch = 'disabled' (unrecognized) -> gate stays active, denies" 2 "$payload" CLAUDE_PROJECT_DIR="$td" ROLLOUT_PLAN_FIELDS_GATE_OFF=disabled
run_payload "kill switch = '1' (recognized on) -> gate disabled, allows" 0 "$payload" CLAUDE_PROJECT_DIR="$td" ROLLOUT_PLAN_FIELDS_GATE_OFF=1
rm -rf "$td"

# --- Absolute-path / ./-prefixed case: the same target reached via an
# absolute file_path and a ./-prefixed variant match the same scope a
# relative-path fixture already matches (issue-39 mandatory case).
td="$(mktemp -d)"
abs_payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1]+"/ops/rollout-plan.md","content":sys.argv[2]},"cwd":sys.argv[1]}))' "$td" "$missing_threshold")"
run_payload "absolute file_path to ops/rollout-plan.md -> same scope, denies" 2 "$abs_payload" CLAUDE_PROJECT_DIR="$td"
dot_payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"./ops/rollout-plan.md","content":sys.argv[1]},"cwd":sys.argv[2]}))' "$missing_threshold" "$td")"
run_payload "./-prefixed file_path to ops/rollout-plan.md -> same scope, denies" 2 "$dot_payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

# --- Missing-core case: CLAUDE_PLUGIN_ROOT_CORE points at a nonexistent
# path with no ../../core fallback reachable — the gate must fail closed
# (exit 2), not silently allow (issue-39 mandatory case).
td="$(mktemp -d)"
payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"ops/rollout-plan.md","content":sys.argv[1]},"cwd":sys.argv[2]}))' "$missing_threshold" "$td")"
run_payload "missing core (CLAUDE_PLUGIN_ROOT_CORE unreachable, no ../../core fallback) -> deny (exit 2)" 2 "$payload" CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$td/does-not-exist-core"
rm -rf "$td"

# --- Bash-bypass case: a Bash command reaching ops/rollout-plan.md must
# be caught, not silently pass through the PreToolUse gate because it
# used a shell instead of Write/Edit/MultiEdit (issue-39 mandatory case;
# matches the deny verdict of the "missing threshold" Write fixture
# above).
td="$(mktemp -d)"
mkdir -p "$td/ops"
printf '%s' "$missing_threshold" > "$td/ops/rollout-plan.md"
bash_payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"cd ../.. && echo x >> ops/rollout-plan.md"},"cwd":sys.argv[1]}))' "$td")"
run_payload "Bash write to ops/rollout-plan.md -> denies" 2 "$bash_payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

exit "$fail"
