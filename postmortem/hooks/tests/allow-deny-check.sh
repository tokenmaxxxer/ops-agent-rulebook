#!/usr/bin/env bash
# Allow/deny fixture for postmortem-review-gate.sh (issue-33, extended
# for issue-39's mandatory 7-case list: Edit reconstruction, MultiEdit
# replace_all, malformed JSON x3 shapes, kill-switch unrecognized-value,
# absolute/./-prefixed path parity, missing-core deny, plus the
# Bash-bypass fixture).
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
gate="$here/../postmortem-review-gate.sh"
fail=0

run() {
  local label="$1" expect="$2" pm_content="$3" pm_path="$4"
  td="$(mktemp -d)"
  mkdir -p "$td/ops"
  printf '%s\n' '---
status: incident
---
' > "$td/ops/state.md"
  if [ -n "$pm_content" ]; then
    printf '%s' "$pm_content" > "$td/$pm_path"
  fi
  new_content="$(printf '%s\n' "---
status: steady
postmortem: $pm_path
---
")"
  payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":sys.argv[1]},"cwd":sys.argv[2]}))' "$new_content" "$td")"
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

empty_reviewer='## Review
- Reviewed by:
- Reviewer satisfied with document and action items: yes'

filled_reviewer='## Review
- Reviewed by: Jiwon Jung
- Reviewer satisfied with document and action items: yes'

run "postmortem file with empty Reviewed by -> deny" 2 "$empty_reviewer" "ops/postmortem-x.md"
run "postmortem file with populated reviewer -> allow" 0 "$filled_reviewer" "ops/postmortem-x.md"

# --- Edit case: current record is incident with no postmortem field; an
# Edit that flips status to steady while adding a postmortem: pointer to
# a reviewed file -> allow; to an empty pointer -> deny (issue-39
# mandatory case).
td="$(mktemp -d)"
mkdir -p "$td/ops"
printf '%s' '---
status: incident
postmortem:
---
' > "$td/ops/state.md"
printf '%s' "$filled_reviewer" > "$td/ops/postmortem-x.md"
payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":"ops/state.md","old_string":"status: incident\npostmortem:","new_string":"status: steady\npostmortem: ops/postmortem-x.md"},"cwd":sys.argv[1]}))' "$td")"
run_payload "Edit: incident -> steady with reviewed postmortem -> allow" 0 "$payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

td="$(mktemp -d)"
mkdir -p "$td/ops"
printf '%s' '---
status: incident
postmortem:
---
' > "$td/ops/state.md"
payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":"ops/state.md","old_string":"status: incident","new_string":"status: steady"},"cwd":sys.argv[1]}))' "$td")"
run_payload "Edit: incident -> steady with empty postmortem field -> deny" 2 "$payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

# --- MultiEdit case: mix of replace_all true/false in one call.
td="$(mktemp -d)"
mkdir -p "$td/ops"
printf '%s' '---
status: incident
postmortem: PENDING
---
' > "$td/ops/state.md"
printf '%s' "$filled_reviewer" > "$td/ops/postmortem-x.md"
payload="$(python3 -c '
import json, sys
edits = [
    {"old_string": "status: incident", "new_string": "status: steady", "replace_all": False},
    {"old_string": "postmortem: PENDING", "new_string": "postmortem: ops/postmortem-x.md", "replace_all": True},
]
print(json.dumps({"tool_name": "MultiEdit", "tool_input": {"file_path": "ops/state.md", "edits": edits}, "cwd": sys.argv[1]}))
' "$td")"
run_payload "MultiEdit: replace_all fills postmortem pointer, status steady -> allow" 0 "$payload" CLAUDE_PROJECT_DIR="$td"
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
printf '%s' '---
status: incident
postmortem:
---
' > "$td/ops/state.md"
payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: steady\npostmortem:\n---\n"},"cwd":sys.argv[1]}))' "$td")"
run_payload "kill switch = 'disabled' (unrecognized) -> gate stays active, denies" 2 "$payload" CLAUDE_PROJECT_DIR="$td" POSTMORTEM_REVIEW_GATE_OFF=disabled
run_payload "kill switch = '1' (recognized on) -> gate disabled, allows" 0 "$payload" CLAUDE_PROJECT_DIR="$td" POSTMORTEM_REVIEW_GATE_OFF=1
rm -rf "$td"

# --- Absolute-path / ./-prefixed case: the same target reached via an
# absolute file_path and a ./-prefixed variant match the same scope a
# relative-path fixture already matches (issue-39 mandatory case).
td="$(mktemp -d)"
mkdir -p "$td/ops"
printf '%s' '---
status: incident
postmortem:
---
' > "$td/ops/state.md"
abs_payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1]+"/ops/state.md","content":"---\nstatus: steady\npostmortem:\n---\n"},"cwd":sys.argv[1]}))' "$td")"
run_payload "absolute file_path to ops/state.md -> same scope, denies" 2 "$abs_payload" CLAUDE_PROJECT_DIR="$td"
dot_payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"./ops/state.md","content":"---\nstatus: steady\npostmortem:\n---\n"},"cwd":sys.argv[1]}))' "$td")"
run_payload "./-prefixed file_path to ops/state.md -> same scope, denies" 2 "$dot_payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

# --- Missing-core case: CLAUDE_PLUGIN_ROOT_CORE points at a nonexistent
# path with no ../../core fallback reachable — the gate must fail closed
# (exit 2), not silently allow (issue-39 mandatory case).
td="$(mktemp -d)"
mkdir -p "$td/ops"
printf '%s' '---
status: incident
postmortem:
---
' > "$td/ops/state.md"
payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: steady\npostmortem:\n---\n"},"cwd":sys.argv[1]}))' "$td")"
run_payload "missing core (CLAUDE_PLUGIN_ROOT_CORE unreachable, no ../../core fallback) -> deny (exit 2)" 2 "$payload" CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$td/does-not-exist-core"
rm -rf "$td"

# --- Bash-bypass case: a Bash command reaching ops/state.md while an
# incident is open must be caught, not silently pass through the
# PreToolUse gate because it used a shell instead of Write/Edit/MultiEdit
# (issue-39 mandatory case; matches the deny verdict of the empty-postmortem
# Write fixture above).
td="$(mktemp -d)"
mkdir -p "$td/ops"
printf '%s' '---
status: incident
postmortem:
---
' > "$td/ops/state.md"
bash_payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"cd ../.. && echo x >> ops/state.md"},"cwd":sys.argv[1]}))' "$td")"
run_payload "Bash write to ops/state.md during open incident -> denies" 2 "$bash_payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

exit "$fail"
