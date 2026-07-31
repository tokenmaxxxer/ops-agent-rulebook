#!/usr/bin/env bash
# Allow/deny fixture for postmortem-review-gate.sh (issue-33).
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
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
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" bash "$here/../postmortem-review-gate.sh" >/dev/null 2>&1
  rc=$?
  rm -rf "$td"
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

exit "$fail"
