#!/usr/bin/env bash
# Test harness for state-gate.sh. Feeds hook JSON on stdin to the gate and
# asserts exit code / deny output. Exits non-zero if any case fails.
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
gate="$script_dir/state-gate.sh"

tmp_root="$(mktemp -d)"

# state-gate.sh resolves its repo root by walking UP from its own on-disk
# location to the nearest enclosing .git — it never consults
# CLAUDE_PROJECT_DIR or the process cwd (see state-gate.sh's own header
# comment). That means a per-case tmp_root/ops/state.md is never actually
# read by the gate: any case that depends on a specific ops/state.md
# CONTENT must stage that content at THIS repo's own real ops/state.md,
# invoke the gate, then restore whatever was there before. tmp_root is
# still used for cases that don't depend on state-file content (e.g. the
# malformed-JSON and empty-stdin cases below, and as a scratch CWD for
# case (l)'s outside-repo probe).
repo_root="$(cd "$script_dir/../.." && pwd -P)"
real_state="$repo_root/ops/state.md"
state_backup="$tmp_root/state-backup.md"
had_state=0
if [ -f "$real_state" ]; then
  had_state=1
  cp "$real_state" "$state_backup"
fi
restore_real_state() {
  if [ "$had_state" -eq 1 ]; then
    mkdir -p "$(dirname "$real_state")"
    cp "$state_backup" "$real_state"
  else
    rm -f "$real_state"
  fi
}
trap 'restore_real_state; rm -rf "$tmp_root"' EXIT

fail=0
pass=0

# run_case NAME EXPECTED_EXIT STATE_CONTENT(or empty for none) JSON
#
# STATE_CONTENT is staged at this repo's own real ops/state.md (see note
# above), invoked against the gate, then the real file is restored to
# whatever it held before the suite ran.
run_case() {
  local name="$1" expected="$2" state_content="$3" json="$4"
  mkdir -p "$(dirname "$real_state")"
  if [ -n "$state_content" ]; then
    printf '%s' "$state_content" > "$real_state"
  else
    rm -f "$real_state"
  fi
  local out
  out="$(printf '%s' "$json" | bash "$gate" 2>&1)"
  local actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "PASS: $name (exit $actual)"
    pass=$((pass+1))
  else
    echo "FAIL: $name (expected exit $expected, got $actual)"
    echo "  output: $out"
    fail=$((fail+1))
  fi
}

# (a) same-state write to state file, state has NO self-loop row -> DENY
run_case "same-state-no-self-loop" 2 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: idle\n---\nnote: updated\n"}}'

# (b) same-state write, state DOES have self-loop row (rollout|rollout) -> ALLOW
run_case "same-state-with-self-loop" 0 \
$'---\nstatus: rollout\n---\n' \
'{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: rollout\n---\nnote: canary step 2\n"}}'

# (c) normal table-legal transition -> ALLOW
run_case "legal-transition" 0 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: readiness\n---\n"}}'

# (d) transition absent from table -> DENY
run_case "illegal-transition" 2 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: incident\n---\n"}}'

# (e) Bash write outside state file's directory -> ALLOW (fail-closed regression guard)
run_case "bash-write-outside-dir" 0 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Bash","tool_input":{"command":"curl -s https://example.com > /tmp/evidence-$(date +%s).json"}}'

# (f) malformed hook JSON -> DENY with visible output, never silent exit 0
malformed_out="$(cd "$tmp_root" && mkdir -p malformed/ops && printf 'not json{{{' | CLAUDE_PROJECT_DIR="$tmp_root/malformed" bash "$gate" 2>&1)"
malformed_exit=$?
if [ "$malformed_exit" -ne 0 ] && [ -n "$malformed_out" ]; then
  echo "PASS: malformed-json (exit $malformed_exit, output present)"
  pass=$((pass+1))
else
  echo "FAIL: malformed-json (exit $malformed_exit, output: '$malformed_out')"
  fail=$((fail+1))
fi

# (g) state file exists with value (none) -> DENY, rules-could-not-be-loaded
run_case "existing-none-sentinel" 2 \
$'---\nstatus: (none)\n---\n' \
'{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: idle\n---\n"}}'

# (h) state file exists with empty status value -> DENY likewise
run_case "existing-empty-status" 2 \
$'---\nstatus:\n---\n' \
'{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: idle\n---\n"}}'

# (i) state file exists with a value outside the known-state set -> DENY likewise
run_case "existing-out-of-set-status" 2 \
$'---\nstatus: bogus-typo-state\n---\n' \
'{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: idle\n---\n"}}'

# (j) state file exists with a valid value followed by trailing whitespace/CRLF
# -> treated as that valid state (not broken); a legal transition from it is ALLOWED
run_case "existing-valid-trailing-whitespace-crlf" 0 \
$'---\r\nstatus: idle   \r\n---\r\n' \
'{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: readiness\n---\n"}}'

# (k) state file genuinely absent -> the (none) -> X bootstrap row is still ALLOWED
run_case "genuinely-absent-bootstrap-allowed" 0 \
"" \
'{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: idle\n---\n"}}'

# (l) the gate follows the project, not its own location ------------------
# Where this hook sits on disk must not decide what it guards. Copy the whole
# hooks directory somewhere outside any project, run that copy with the
# project as cwd, and it must reach the same decision as the in-repo copy.
#
# Until 2026-07-26 root was the nearest `.git` ABOVE the hook itself. A
# rulebook loaded as a plugin from its own checkout — which is how an
# orchestrator swaps rulebooks per role — therefore guarded the rulebook's
# repo, and every write in the real project fell outside its owned paths and
# was allowed, silently, exit 0.
elsewhere="$(mktemp -d)"
cp -R "$script_dir" "$elsewhere/hooks"
payload_l='{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: idle\n---\n"}}'
out_in="$(cd "$repo_root" && env -u CLAUDE_PROJECT_DIR bash -c 'printf "%s" "$1" | "$2"' _ "$payload_l" "$gate" 2>&1)"
code_in=$?
out_out="$(cd "$repo_root" && env -u CLAUDE_PROJECT_DIR bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload_l" "$elsewhere/hooks/state-gate.sh" 2>&1)"
code_out=$?
rm -rf "$elsewhere"
if [ "$code_in" -eq "$code_out" ]; then
  echo "PASS: gate-location-independence (out-of-tree copy exit $code_out matches in-repo exit $code_in)"
  pass=$((pass+1))
else
  echo "FAIL: gate-location-independence (in-repo exit $code_in, out-of-tree exit $code_out) — out: $out_out | in: $out_in"
  fail=$((fail+1))
fi

# (m) ops writing its own subject-scoped record -> ALLOW
run_case "own-record-write" 0 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Write","tool_input":{"file_path":"docs/reports/records/gate-fix/ops.md","content":"notes"}}'

# (n) ops attempting to write another role's subject-scoped record under the
# same subject -> DENY, citing §11
run_case "foreign-record-write" 2 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Write","tool_input":{"file_path":"docs/reports/records/gate-fix/qa.md","content":"notes"}}'

# (o) empty/malformed stdin -> DENY, never silent exit 0
empty_out="$(printf '' | CLAUDE_PROJECT_DIR="$tmp_root" bash "$gate" 2>&1)"
empty_exit=$?
if [ "$empty_exit" -ne 0 ]; then
  echo "PASS: empty-stdin (exit $empty_exit)"
  pass=$((pass+1))
else
  echo "FAIL: empty-stdin (expected non-zero exit, got $empty_exit) output: $empty_out"
  fail=$((fail+1))
fi

# --- write-detection bypass fix (docs/proposals/2026-07-26-fix-state-gate-writeop-bypass.md)
# write-through-another-tool (python3's open()) previously matched none of
# bash_write_targets' idioms, so a Bash write reaching a foreign record via
# `python3 -c "open(path,'w').write(...)"` bypassed check_owned_path
# entirely (touches_state_file() also returned False for it) and fell
# through to allow().

# (p) Bash python3-open write to a foreign role's record under the same
# subject -> DENY, citing §11.
run_case "bash-python-open-foreign-record-write" 2 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Bash","tool_input":{"command":"python3 -c \"open('"'"'docs/reports/records/gate-fix/qa.md'"'"','"'"'w'"'"').write('"'"'x'"'"')\""}}'

# (q) Bash python3-open write to ops' OWN subject-scoped record -> ALLOW
# (ownership check passes; this gate does not further verify Bash-mediated
# content against transition-rules.md the way it does for Write/Edit).
run_case "bash-python-open-own-record-write" 0 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Bash","tool_input":{"command":"python3 -c \"open('"'"'docs/reports/records/gate-fix/ops.md'"'"','"'"'w'"'"').write('"'"'x'"'"')\""}}'

# (r) Bash python3-open write whose target path is built from concatenation
# (not a clean literal), in a command that names the owned record tree ->
# DENY (default-deny on an indeterminate target).
run_case "bash-python-open-indeterminate-target-in-records-tree" 2 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Bash","tool_input":{"command":"python3 -c \"import sys; open('"'"'docs/reports/records/'"'"' + sys.argv[1] + '"'"'/qa.md'"'"','"'"'w'"'"').write('"'"'x'"'"')\" gate-fix"}}'

# --- path-reference default-deny (docs/proposals/2026-07-26-gate-nested-shell-default-deny.md)
# Each of these targets a FOREIGN role's record slot via a write idiom this
# gate never enumerated by name (write_text/write_bytes/os.write) or via a
# nested shell / command substitution wrapper around a plain write. The
# rule is not "match this idiom" — it is "default-deny any reference into
# the owned record tree this gate cannot prove is read-only" — so all must
# be refused regardless of idiom. Own-record writes via the same idioms
# stay ALLOWED.

run_case "prdd-write-text-foreign" 2 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Bash","tool_input":{"command":"python3 -c \"import pathlib; pathlib.Path('"'"'docs/reports/records/gate-fix/qa.md'"'"').write_text('"'"'x'"'"')\""}}'

run_case "prdd-write-bytes-foreign" 2 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Bash","tool_input":{"command":"python3 -c \"import pathlib; pathlib.Path('"'"'docs/reports/records/gate-fix/qa.md'"'"').write_bytes(b'"'"'x'"'"')\""}}'

run_case "prdd-os-write-foreign" 2 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Bash","tool_input":{"command":"python3 -c \"import os; fd = os.open('"'"'docs/reports/records/gate-fix/qa.md'"'"', os.O_WRONLY | os.O_CREAT); os.write(fd, b'"'"'x'"'"')\""}}'

run_case "prdd-sh-c-wrapped-foreign" 2 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Bash","tool_input":{"command":"sh -c \"echo x > docs/reports/records/gate-fix/qa.md\""}}'

run_case "prdd-cmd-subst-wrapped-foreign" 2 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Bash","tool_input":{"command":"echo x > $(echo docs/reports/records/gate-fix/qa.md)"}}'

run_case "prdd-write-text-own-allowed" 0 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Bash","tool_input":{"command":"python3 -c \"import pathlib; pathlib.Path('"'"'docs/reports/records/gate-fix/ops.md'"'"').write_text('"'"'x'"'"')\""}}'

echo
echo "Results: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
exit 0
