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

# (l) CLAUDE_PROJECT_DIR unset: git-toplevel fallback ---------------------
# Per docs/proposals/2026-07-26-gate-root-from-project-dir.md §2(b): with
# CLAUDE_PROJECT_DIR unset, root falls back to the git top-level of the
# PreToolUse target path, else the git top-level of cwd.
outside_dir="$(mktemp -d)"
payload_l='{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: idle\n---\n"}}'
out_in="$(cd "$repo_root" && env -u CLAUDE_PROJECT_DIR bash -c 'printf "%s" "$1" | "$2"' _ "$payload_l" "$gate" 2>&1)"
code_in=$?
if [ "$code_in" -eq 0 ]; then
  echo "PASS: inside-repo-cwd-fallback (exit 0)"
  pass=$((pass+1))
else
  echo "FAIL: inside-repo-cwd-fallback (expected exit 0 via git-toplevel fallback, got $code_in) — $out_in"
  fail=$((fail+1))
fi

# (l2) CLAUDE_PROJECT_DIR unset, cwd AND target both outside any git
# work-tree -> root is indeterminate -> refused (never silently allowed).
out_out="$(cd "$outside_dir" && env -u CLAUDE_PROJECT_DIR bash -c 'printf "%s" "$1" | "$2"' _ "$payload_l" "$gate" 2>&1)"
code_out=$?
rm -rf "$outside_dir"
if [ "$code_out" -ne 0 ]; then
  echo "PASS: outside-repo-indeterminate-root-refused (exit $code_out)"
  pass=$((pass+1))
else
  echo "FAIL: outside-repo-indeterminate-root-refused (expected refused, got exit 0) — $out_out"
  fail=$((fail+1))
fi

# --- (q) target-repo-governance: CLAUDE_PROJECT_DIR pointed at an
# unrelated, empty (but plausible-looking, git-initialized) directory, and
# the Write targets an owned-tree path that is ALSO not inside any git
# work-tree -> root is genuinely indeterminate -> default-deny per §2(c),
# not silently allowed.
unrelated_dir="$(mktemp -d)"
git init -q "$unrelated_dir" >/dev/null 2>&1
non_git_target_dir="$(mktemp -d)"
scratch_subject_q="gateroot-unrelated-projectdir-test"
mkdir -p "$non_git_target_dir/docs/reports/records/$scratch_subject_q"
payload_q="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$non_git_target_dir/docs/reports/records/$scratch_subject_q/ops.md\",\"content\":\"notes\"}}"
out_q="$(cd "$non_git_target_dir" && env CLAUDE_PROJECT_DIR="$unrelated_dir" bash -c 'printf "%s" "$1" | "$2"' _ "$payload_q" "$gate" 2>&1)"
rc_q=$?
rm -rf "$unrelated_dir" "$non_git_target_dir"
if [ "$rc_q" -ne 0 ]; then
  echo "PASS: unrelated-project-dir-indeterminate-owned-tree-refused (exit $rc_q)"
  pass=$((pass+1))
else
  echo "FAIL: unrelated-project-dir-indeterminate-owned-tree-refused (expected refused, got exit 0) — $out_q"
  fail=$((fail+1))
fi

# --- (r) target-repo-governance: CLAUDE_PROJECT_DIR correctly set (target
# is under it, and it looks like a project root) -> §11 enforced normally
# against that SEPARATE target project, not against this rulebook repo.
target_repo_r="$(mktemp -d)"
git init -q "$target_repo_r" >/dev/null 2>&1
mkdir -p "$target_repo_r/docs/specs" "$target_repo_r/docs/reports/records/checkout-flow"
printf '# role-handoff-contract\n\n## 11. NEVER-OVERWRITE\n\nA role owns exactly its own docs/reports/records/<subject>/<role>.md slot.\n' \
  > "$target_repo_r/docs/specs/role-handoff-contract.md"
payload_r="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$target_repo_r/docs/reports/records/checkout-flow/qa.md\",\"content\":\"notes\"}}"
out_r="$(CLAUDE_PROJECT_DIR="$target_repo_r" bash "$gate" <<<"$payload_r" 2>&1)"
rc_r=$?
rm -rf "$target_repo_r"
if [ "$rc_r" -ne 0 ]; then
  echo "PASS: valid-project-dir-separate-target-project-foreign-record-refused (exit $rc_r)"
  pass=$((pass+1))
else
  echo "FAIL: valid-project-dir-separate-target-project-foreign-record-refused (expected refused, got exit 0) — $out_r"
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

# --- fail-closed-on-internal-error (docs/proposals/2026-07-26-gates-fail-closed-on-internal-error.md)
# A crash-inducing payload must resolve to a DENY (exit 2), never an
# uncaught exit 1 (which PreToolUse treats as fail-open).

# (s) null byte in file_path -> os.path.realpath raises ValueError in the
# judge -> the python excepthook / shell rc-map turn it into exit 2, not 1.
run_case "crash-null-byte-in-file-path-denies-2" 2 \
$'---\nstatus: idle\n---\n' \
'{"tool_name":"Write","tool_input":{"file_path":"ops/\u0000state.md","content":"---\nstatus: idle\n---\n"}}'

# --- fail-closed-trap-at-top (docs/proposals/2026-07-26-gates-fail-closed-trap-at-top.md)
# A gate that aborts BEFORE its verdict logic runs (a failed `source`, a
# `set -euo pipefail` abort, an unbound var, a syntax path) previously exited
# non-2, which PreToolUse treats as NON-BLOCKING (fail-OPEN). The trap-at-top
# installed as the first executable statement must convert any such abnormal
# exit (rc not in {0,2}) into DENY (exit 2).
#
# (t) pre-logic abort: a copy of the real gate with a guaranteed early command
# failure injected immediately after its `set -euo pipefail` (i.e. BEFORE any
# verdict logic) — under set -e this aborts with rc=1, exactly the class a
# missing/unreadable sourced file would produce — MUST be forced to exit 2 by
# the top-installed EXIT trap, not leak the raw rc.
trap_gate="$tmp_root/state-gate-prelogic-abort.sh"
awk '{print} /^set -euo pipefail/ && !done {print "false  # injected pre-logic abort (simulates failed source / early error)"; done=1}' \
  "$gate" > "$trap_gate"
chmod +x "$trap_gate"
prelogic_out="$(printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"ops/state.md","content":"---\nstatus: idle\n---\n"}}' | bash "$trap_gate" 2>&1)"
prelogic_exit=$?
if [ "$prelogic_exit" -eq 2 ]; then
  echo "PASS: prelogic-abort-forced-to-deny-2 (exit $prelogic_exit)"
  pass=$((pass+1))
else
  echo "FAIL: prelogic-abort-forced-to-deny-2 (expected exit 2, got $prelogic_exit) — $prelogic_out"
  fail=$((fail+1))
fi

echo
echo "Results: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
exit 0
