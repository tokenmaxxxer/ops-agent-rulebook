#!/usr/bin/env bash
# Allow/deny fixture for rollout-plan-fields-gate.sh (issue-33).
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
fail=0

run() {
  local label="$1" expect="$2" content="$3"
  td="$(mktemp -d)"
  payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":"ops/rollout-plan.md","content":sys.argv[1]},"cwd":sys.argv[2]}))' "$content" "$td")"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" bash "$here/../rollout-plan-fields-gate.sh" >/dev/null 2>&1
  rc=$?
  rm -rf "$td"
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

exit "$fail"
