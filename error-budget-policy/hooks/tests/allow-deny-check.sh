#!/usr/bin/env bash
# Allow/deny fixture for error-budget-gate.sh (issue-33, extended for
# issue-39's mandatory 7-case list: Edit reconstruction, MultiEdit
# replace_all, malformed JSON x3 shapes, kill-switch unrecognized-value,
# absolute/./-prefixed path parity, missing-core deny, plus the
# Bash-bypass fixture).
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
gate="$here/../error-budget-gate.sh"
fail=0

run() {
  local label="$1" expect="$2" current="$3" new="$4"
  td="$(mktemp -d)"
  mkdir -p "$td/ops"
  if [ -n "$current" ]; then
    printf '%s' "$current" > "$td/ops/state.md"
  fi
  payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":sys.argv[1]},"cwd":sys.argv[2]}))' "$new" "$td")"
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

exhausted='---
status: steady
error_budget: exhausted
---
'
ok_budget='---
status: steady
error_budget: ok
---
'
to_readiness='---
status: readiness
error_budget: exhausted
---
'

run "budget exhausted, attempt steady -> readiness -> deny" 2 "$exhausted" "$to_readiness"
run "budget ok, steady -> readiness -> allow" 0 "$ok_budget" "$to_readiness"
run "no prior record -> allow (nothing to refuse a transition away from)" 0 "" "$to_readiness"

# --- Edit case: current record has error_budget: exhausted; an Edit that
# flips status to readiness -> deny; an Edit that leaves status alone ->
# allow (issue-39 mandatory case).
td="$(mktemp -d)"
mkdir -p "$td/ops"
printf '%s' "$exhausted" > "$td/ops/state.md"
payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":"ops/state.md","old_string":"status: steady","new_string":"status: readiness"},"cwd":sys.argv[1]}))' "$td")"
run_payload "Edit: budget exhausted, steady -> readiness -> deny" 2 "$payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

td="$(mktemp -d)"
mkdir -p "$td/ops"
printf '%s' "$exhausted" > "$td/ops/state.md"
payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":"ops/state.md","old_string":"error_budget: exhausted","new_string":"error_budget: exhausted # unchanged"},"cwd":sys.argv[1]}))' "$td")"
run_payload "Edit: budget exhausted, status stays steady -> allow" 0 "$payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

# --- MultiEdit case: mix of replace_all true/false in one call.
td="$(mktemp -d)"
mkdir -p "$td/ops"
printf '%s' "$exhausted" > "$td/ops/state.md"
payload="$(python3 -c '
import json, sys
edits = [
    {"old_string": "status: steady", "new_string": "status: readiness", "replace_all": False},
    {"old_string": "exhausted", "new_string": "exhausted", "replace_all": True},
]
print(json.dumps({"tool_name": "MultiEdit", "tool_input": {"file_path": "ops/state.md", "edits": edits}, "cwd": sys.argv[1]}))
' "$td")"
run_payload "MultiEdit: replace_all true no-op, status flips to readiness -> deny" 2 "$payload" CLAUDE_PROJECT_DIR="$td"
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
mkdir -p "$td/ops"
printf '%s' "$exhausted" > "$td/ops/state.md"
payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":sys.argv[1]},"cwd":sys.argv[2]}))' "$to_readiness" "$td")"
run_payload "kill switch = 'disabled' (unrecognized) -> gate stays active, denies" 2 "$payload" CLAUDE_PROJECT_DIR="$td" ERROR_BUDGET_GATE_OFF=disabled
run_payload "kill switch = '1' (recognized on) -> gate disabled, allows" 0 "$payload" CLAUDE_PROJECT_DIR="$td" ERROR_BUDGET_GATE_OFF=1
rm -rf "$td"

# --- Absolute-path / ./-prefixed case: the same target reached via an
# absolute file_path and a ./-prefixed variant match the same scope a
# relative-path fixture already matches (issue-39 mandatory case).
td="$(mktemp -d)"
mkdir -p "$td/ops"
printf '%s' "$exhausted" > "$td/ops/state.md"
abs_payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1]+"/ops/state.md","content":sys.argv[2]},"cwd":sys.argv[1]}))' "$td" "$to_readiness")"
run_payload "absolute file_path to ops/state.md -> same scope, denies" 2 "$abs_payload" CLAUDE_PROJECT_DIR="$td"
dot_payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"./ops/state.md","content":sys.argv[1]},"cwd":sys.argv[2]}))' "$to_readiness" "$td")"
run_payload "./-prefixed file_path to ops/state.md -> same scope, denies" 2 "$dot_payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

# --- Missing-core case: CLAUDE_PLUGIN_ROOT_CORE points at a nonexistent
# path with no ../../core fallback reachable — the gate must fail closed
# (exit 2), not silently allow (issue-39 mandatory case).
td="$(mktemp -d)"
mkdir -p "$td/ops"
printf '%s' "$exhausted" > "$td/ops/state.md"
payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":sys.argv[1]},"cwd":sys.argv[2]}))' "$to_readiness" "$td")"
run_payload "missing core (CLAUDE_PLUGIN_ROOT_CORE unreachable, no ../../core fallback) -> deny (exit 2)" 2 "$payload" CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$td/does-not-exist-core"
rm -rf "$td"

# --- Bash-bypass case: a Bash command reaching ops/state.md while the
# budget is exhausted must be caught, not silently pass through the
# PreToolUse gate because it used a shell instead of Write/Edit/MultiEdit
# (issue-39 mandatory case; matches the deny verdict of the first Write
# fixture above).
td="$(mktemp -d)"
mkdir -p "$td/ops"
printf '%s' "$exhausted" > "$td/ops/state.md"
bash_payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"cd ../.. && echo x >> ops/state.md"},"cwd":sys.argv[1]}))' "$td")"
run_payload "Bash write to ops/state.md while budget exhausted -> denies" 2 "$bash_payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

exit "$fail"
