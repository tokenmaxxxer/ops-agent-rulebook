#!/usr/bin/env bash
# Allow/deny fixture for readiness-fields-gate.sh (issue-33, extended for
# issue-36's mandatory cases: Edit, MultiEdit/replace_all, malformed-JSON,
# kill-switch unrecognized-value, absolute-path, section-scoping).
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
gate="$here/../readiness-fields-gate.sh"
fail=0

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

run_write() {
  local label="$1" expect="$2" content="$3" path="${4:-ops/state.md}"
  td="$(mktemp -d)"
  payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]},"cwd":sys.argv[3]}))' "$path" "$content" "$td")"
  run_payload "$label" "$expect" "$payload" CLAUDE_PROJECT_DIR="$td"
  rm -rf "$td"
}

missing_dim='---
status: rollout
---
## Checklist
- item: Service Levels | status: yes | artifact: https://dash/example'

no_artifact='---
status: rollout
---
## Checklist
- item: Service Levels | status: yes | artifact:
- item: Architecture Design Review | status: no | artifact:'

complete='---
status: rollout
---
## Checklist
- item: Service Levels | status: yes | artifact: https://dash/example
- item: Architecture Design Review | status: no | artifact:'

not_rollout='---
status: readiness
---
## Checklist
- item: Service Levels | status: yes | artifact:'

no_items=$'---\nstatus: rollout\n---\n'

run_write "status: rollout, yes item with empty artifact -> deny" 2 "$no_artifact"
run_write "status: rollout, no Checklist items at all -> deny" 2 "$no_items"
run_write "status: rollout, items resolve with real artifacts -> allow" 0 "$complete"
run_write "status not rollout -> allow (not this gate's business)" 0 "$not_rollout"

# --- Edit case: current content transitions status to rollout while a
# checklist item is a bare yes with no artifact; the gate must judge the
# reconstructed content, not just simulate the tool's own defaults
# (issue-36 mandatory case).
edit_current='---
status: draft
---
## Checklist
- item: Service Levels | status: yes | artifact:
- item: Architecture Design Review | status: no | artifact:'
td="$(mktemp -d)"
mkdir -p "$td/ops"
printf '%s' "$edit_current" > "$td/ops/state.md"
payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":"ops/state.md","old_string":"status: draft","new_string":"status: rollout"},"cwd":sys.argv[1]}))' "$td")"
run_payload "Edit: flips status to rollout, a yes item has no artifact -> deny" 2 "$payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

# --- MultiEdit case: mix of replace_all true/false in one call, honoring
# each edit's own flag independently (issue-36 mandatory case, direct fix
# for the replace_all-ignored defect).
multi_current='---
status: draft
---
## Checklist
- item: Service Levels | status: no | artifact:
- item: Architecture Design Review | status: no | artifact:
- item: Performance | status: no | artifact:'
td="$(mktemp -d)"
mkdir -p "$td/ops"
printf '%s' "$multi_current" > "$td/ops/state.md"
payload="$(python3 -c '
import json, sys
edits = [
    {"old_string": "status: draft", "new_string": "status: rollout", "replace_all": False},
    {"old_string": "status: no | artifact:", "new_string": "status: yes | artifact: https://dash/x", "replace_all": True},
]
print(json.dumps({"tool_name": "MultiEdit", "tool_input": {"file_path": "ops/state.md", "edits": edits}, "cwd": sys.argv[1]}))
' "$td")"
# replace_all: true on the item line replaces ALL three occurrences, so the
# gate must judge all three items resolved yes/with-artifact -> allow.
run_payload "MultiEdit: replace_all true replaces every occurrence -> allow" 0 "$payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

# --- Malformed-JSON cases: truncated JSON and a non-object top level both
# deny rather than proceed on a best-effort guess (issue-36 mandatory case).
run_payload "malformed JSON (truncated) -> deny" 2 '{"tool_name": "Write", "tool_inp' CLAUDE_PROJECT_DIR=/tmp
run_payload "malformed JSON (top-level array) -> deny" 2 '["not", "an", "object"]' CLAUDE_PROJECT_DIR=/tmp

# --- Kill-switch case: an unrecognized value must NOT disable the gate
# (issue-36 mandatory case — the fail-open bug this migration fixes).
td="$(mktemp -d)"
payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":sys.argv[1]},"cwd":sys.argv[2]}))' "$no_artifact" "$td")"
run_payload "kill switch = 'disabled' (unrecognized) -> gate stays active, denies" 2 "$payload" CLAUDE_PROJECT_DIR="$td" READINESS_FIELDS_GATE_OFF=disabled
run_payload "kill switch = '1' (recognized on) -> gate disabled, allows" 0 "$payload" CLAUDE_PROJECT_DIR="$td" READINESS_FIELDS_GATE_OFF=1
rm -rf "$td"

# --- Absolute-path case: the same target reached via an absolute
# file_path, and a ./-prefixed variant, both match the same scope a
# relative-path fixture already matches (issue-36 mandatory case).
td="$(mktemp -d)"
abs_payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1]+"/ops/state.md","content":sys.argv[2]},"cwd":sys.argv[1]}))' "$td" "$no_artifact")"
run_payload "absolute file_path to ops/state.md -> same scope, denies" 2 "$abs_payload" CLAUDE_PROJECT_DIR="$td"
dot_payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"./ops/state.md","content":sys.argv[1]},"cwd":sys.argv[2]}))' "$no_artifact" "$td")"
run_payload "./-prefixed file_path to ops/state.md -> same scope, denies" 2 "$dot_payload" CLAUDE_PROJECT_DIR="$td"
rm -rf "$td"

# --- Section-scoping case: a `- item:`-shaped line outside the
# `## Checklist` block must NOT be treated as a real checklist item
# (issue-36 mandatory case, this gate's own defect #3 fix).
outside_block='---
status: rollout
---
## Checklist
- item: Service Levels | status: yes | artifact: https://dash/example
- item: Architecture Design Review | status: no | artifact:

## Appendix
- item: Stray note that looks like a checklist row | status: yes | artifact:'
run_write "stray item-shaped line outside ## Checklist -> ignored, real items still resolve -> allow" 0 "$outside_block"

no_heading='---
status: rollout
---
## Notes
- item: This is not inside a Checklist section | status: yes | artifact:'
run_write "no ## Checklist heading at all, item-shaped line elsewhere -> deny (no real checklist)" 2 "$no_heading"

exit "$fail"
