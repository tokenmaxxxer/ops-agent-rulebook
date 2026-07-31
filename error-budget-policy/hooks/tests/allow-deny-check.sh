#!/usr/bin/env bash
# Allow/deny fixture for error-budget-gate.sh (issue-33).
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
fail=0

run() {
  local label="$1" expect="$2" current="$3" new="$4"
  td="$(mktemp -d)"
  mkdir -p "$td/ops"
  if [ -n "$current" ]; then
    printf '%s' "$current" > "$td/ops/state.md"
  fi
  payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":sys.argv[1]},"cwd":sys.argv[2]}))' "$new" "$td")"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" bash "$here/../error-budget-gate.sh" >/dev/null 2>&1
  rc=$?
  rm -rf "$td"
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

exit "$fail"
