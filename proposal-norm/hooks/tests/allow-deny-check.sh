#!/usr/bin/env bash
# Allow/deny fixture for proposal-fields-gate.sh (issue-33). Same
# substance-probe pattern as this repo's tests/deny-only-check.sh: a
# synthetic PreToolUse Write payload on stdin, asserting the gate's exit
# code. Run standalone: hooks/tests/allow-deny-check.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
gate="$here/../proposal-fields-gate.sh"
[ -x "$gate" ] || gate="/bin/bash $gate" # fallback if exec bit not set in checkout
fail=0

run() {
  # $1=label $2=expect_rc $3=file_path $4=content
  local label="$1" expect="$2" fp="$3" content="$4"
  td="$(mktemp -d)"
  mkdir -p "$td/docs/issue-999/proposals"
  payload="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]},"cwd":sys.argv[3]}))' "$fp" "$content" "$td")"
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" bash "$here/../proposal-fields-gate.sh" >/dev/null 2>&1
  rc=$?
  rm -rf "$td"
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

exit "$fail"
