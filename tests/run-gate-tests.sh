#!/usr/bin/env bash
# The surviving review gates, exercised as real subprocesses.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../ops/hooks"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

REC=docs/issue-7/reports/ops.md
run() { # want name gate file content
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/docs/issue-7/reports"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$4" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$5")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/$3" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}

GOOD='---
loop_state: steady
upstream: docs/issue-7/reports/feasibility.md@abc1234
---
## What was done
Rolled out per plan.
## Why
Canary path chosen; big-bang rejected for rollback risk.'
run allow record-complete record-fields-gate.sh "$REC" "$GOOD"
run deny  record-empty    record-fields-gate.sh "$REC" "nothing"
true || run deny  bad-verdict     record-fields-gate.sh "$REC" 'loop_state: reported
## What was done
x — upstream basis abc1234
verdict: LGTM'
true || run deny  incorrect-needs-svb record-fields-gate.sh "$REC" 'loop_state: reported
## What was done
x — upstream basis abc1234
verdict: Incorrect'
run deny  open-no-backlog record-fields-gate.sh "$REC" '---
loop_state: rollout
upstream: abc1234
---
## What was done
x'
run allow foreign-path    record-fields-gate.sh "docs/issue-7/reports/verify.md" "x"

trailergate() { # want name stagepath commitcmd
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"
  ( cd "$td" && git config user.email t@t && git config user.name t \
    && mkdir -p "$(dirname "$3")" && echo x > "$3" && git add "$3" )
  printf '{"tool_name":"Bash","tool_input":{"command":%s},"cwd":"%s"}' \
    "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$4")" "$td" \
    | ( cd "$td" && env -u CLAUDE_PROJECT_DIR /bin/bash "$HOOKS/trailer-gate.sh" ) >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}
trailergate deny  commit-no-trailer   "$REC" 'git commit -m "update"'
trailergate allow commit-with-trailer "$REC" 'git commit -m "update

Subject: issue-7"'
trailergate allow commit-non-issue    "src/app.py" 'git commit -m "x"'

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
