#!/usr/bin/env bash
# Allow/deny fixture for proposal-fields-gate.sh (issue-27, extended for
# issue-39's mandatory 7-case list: Edit reconstruction, MultiEdit
# replace_all, malformed JSON x3 shapes, kill-switch unrecognized-value,
# absolute/./-prefixed path parity, missing-core deny, plus the
# Bash-bypass fixture). Same substance-probe pattern as this repo's
# tests/deny-only-check.sh: a synthetic PreToolUse Write payload on
# stdin, asserting the gate's exit code. Run standalone:
# hooks/tests/allow-deny-check.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
gate="$here/../proposal-fields-gate.sh"
fail=0

run() {
  # $1=label $2=expect_rc $3=file_path $4=content
  local label="$1" expect="$2" fp="$3" content="$4"
  td="$(mktemp -d)"
  mkdir -p "$td/docs/issue-999/proposals"
  payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]},"cwd":sys.argv[3]}))' "$fp" "$content" "$td")"
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

full='## Scope / change description
x
## Risk
named failure mode
## Rollback / back-out path
git revert
See https://example.com/evidence for this claim.'

run "missing all four sections -> deny" 2 "docs/issue-999/proposals/x.md" "nothing here"
run "missing risk section -> deny" 2 "docs/issue-999/proposals/x.md" "## Scope\nx\n## Rollback\ngit revert\nhttps://example.com"
run "complete proposal -> allow" 0 "docs/issue-999/proposals/x.md" "$full"
run "non-proposal path -> allow (not this gate's business)" 0 "ops/state.md" "nothing here"

# --- Edit case: an Edit whose reconstructed content is complete -> allow;
# still missing risk after the edit -> deny (issue-39 mandatory case).
td="$(mktemp -d)"
mkdir -p "$td/docs/issue-999/proposals"
printf '%s' '## Scope / change description
x
## Rollback / back-out path
git revert
See https://example.com/evidence for this claim.' > "$td/docs/issue-999/proposals/x.md"
payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":"docs/issue-999/proposals/x.md","old_string":"git revert","new_string":"git revert\n## Risk\nnamed failure mode"},"cwd":sys.argv[1]}))' "$td")"
run_payload "Edit: adds Risk section, all four present -> allow" 0 "$payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

td="$(mktemp -d)"
mkdir -p "$td/docs/issue-999/proposals"
printf '%s' '## Scope / change description
x
## Rollback / back-out path
git revert
See https://example.com/evidence for this claim.' > "$td/docs/issue-999/proposals/x.md"
payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":"docs/issue-999/proposals/x.md","old_string":"git revert","new_string":"git rollback only"},"cwd":sys.argv[1]}))' "$td")"
run_payload "Edit: still missing risk -> deny" 2 "$payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

# --- MultiEdit case: mix of replace_all true/false in one call.
td="$(mktemp -d)"
mkdir -p "$td/docs/issue-999/proposals"
printf '%s' 'DRAFT DRAFT
## Rollback / back-out path
git revert
See https://example.com/evidence for this claim.' > "$td/docs/issue-999/proposals/x.md"
payload="$(python3 -c '
import json, sys
edits = [
    {"old_string": "DRAFT DRAFT", "new_string": "## Scope / change description\nx\n## Risk\nnamed failure mode", "replace_all": False},
]
print(json.dumps({"tool_name": "MultiEdit", "tool_input": {"file_path": "docs/issue-999/proposals/x.md", "edits": edits}, "cwd": sys.argv[1]}))
' "$td")"
run_payload "MultiEdit: single replace fills scope+risk, all four present -> allow" 0 "$payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

td="$(mktemp -d)"
mkdir -p "$td/docs/issue-999/proposals"
printf '%s' 'x x x
## Rollback / back-out path
git revert
See https://example.com/evidence for this claim.' > "$td/docs/issue-999/proposals/x.md"
payload="$(python3 -c '
import json, sys
edits = [
    {"old_string": "x x x", "new_string": "## Scope / change description\ny", "replace_all": True},
]
print(json.dumps({"tool_name": "MultiEdit", "tool_input": {"file_path": "docs/issue-999/proposals/x.md", "edits": edits}, "cwd": sys.argv[1]}))
' "$td")"
run_payload "MultiEdit: replace_all true, still no risk section -> deny" 2 "$payload" CLAUDE_PROJECT_DIR="$td"
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
mkdir -p "$td/docs/issue-999/proposals"
payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"docs/issue-999/proposals/x.md","content":"nothing here"},"cwd":sys.argv[1]}))' "$td")"
run_payload "kill switch = 'disabled' (unrecognized) -> gate stays active, denies" 2 "$payload" CLAUDE_PROJECT_DIR="$td" PROPOSAL_FIELDS_GATE_OFF=disabled
run_payload "kill switch = '1' (recognized on) -> gate disabled, allows" 0 "$payload" CLAUDE_PROJECT_DIR="$td" PROPOSAL_FIELDS_GATE_OFF=1
rm -rf "$td"

# --- Absolute-path / ./-prefixed case: the same target reached via an
# absolute file_path and a ./-prefixed variant match the same scope a
# relative-path fixture already matches (issue-39 mandatory case).
td="$(mktemp -d)"
mkdir -p "$td/docs/issue-999/proposals"
abs_payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1]+"/docs/issue-999/proposals/x.md","content":"nothing here"},"cwd":sys.argv[1]}))' "$td")"
run_payload "absolute file_path to proposals/x.md -> same scope, denies" 2 "$abs_payload" CLAUDE_PROJECT_DIR="$td"
dot_payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"./docs/issue-999/proposals/x.md","content":"nothing here"},"cwd":sys.argv[1]}))' "$td")"
run_payload "./-prefixed file_path to proposals/x.md -> same scope, denies" 2 "$dot_payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

# --- Missing-core case: CLAUDE_PLUGIN_ROOT_CORE points at a nonexistent
# path with no ../../core fallback reachable — the gate must fail closed
# (exit 2), not silently allow (issue-39 mandatory case).
td="$(mktemp -d)"
mkdir -p "$td/docs/issue-999/proposals"
payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"docs/issue-999/proposals/x.md","content":"nothing here"},"cwd":sys.argv[1]}))' "$td")"
run_payload "missing core (CLAUDE_PLUGIN_ROOT_CORE unreachable, no ../../core fallback) -> deny (exit 2)" 2 "$payload" CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$td/does-not-exist-core"
rm -rf "$td"

# --- Bash-bypass case: a Bash command reaching the same protected target
# as an existing deny-verdict Write fixture ("missing all four sections")
# must be caught, not silently pass through the PreToolUse gate because it
# used a shell instead of Write/Edit/MultiEdit (issue-39 mandatory case).
td="$(mktemp -d)"
mkdir -p "$td/docs/issue-999/proposals"
bash_payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"cd ../.. && echo x >> docs/issue-999/proposals/x.md"},"cwd":sys.argv[1]}))' "$td")"
run_payload "Bash write to docs/issue-999/proposals/x.md -> same verdict as Write fixture, denies" 2 "$bash_payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

exit "$fail"
