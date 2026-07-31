#!/usr/bin/env bash
# Allow/deny fixture for readiness-fields-gate.sh (issue-33).
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
fail=0

run() {
  local label="$1" expect="$2" content="$3"
  td="$(mktemp -d)"
  payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":sys.argv[1]},"cwd":sys.argv[2]}))' "$content" "$td")"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" bash "$here/../readiness-fields-gate.sh" >/dev/null 2>&1
  rc=$?
  rm -rf "$td"
  if [ "$rc" = "$expect" ]; then
    echo "ok    $label (rc=$rc)"
  else
    echo "FAIL  $label — expected rc=$expect, got rc=$rc"
    fail=1
  fi
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

run "status: rollout, yes item with empty artifact -> deny" 2 "$no_artifact"
run "status: rollout, no Checklist items at all -> deny" 2 "$no_items"
run "status: rollout, items resolve with real artifacts -> allow" 0 "$complete"
run "status not rollout -> allow (not this gate's business)" 0 "$not_rollout"

exit "$fail"
