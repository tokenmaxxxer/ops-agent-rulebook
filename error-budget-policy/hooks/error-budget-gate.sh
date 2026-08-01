#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "error-budget-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
# PreToolUse gate (Write|Edit|MultiEdit|Bash) — issue-33, migrated to the
# gate-house standard (issue-39, core issue #72's shared gate-lib.sh/
# gate-lib.py).
#
# On a write whose resolved target is ops/state.md, if the CURRENT record's
# error_budget field reads exhausted and the write's resulting content sets
# `status: readiness`, refuse outright — a release cycle may not be picked
# back up while the error budget is spent, regardless of readiness
# (skill: error-budget-policy). This is a hard stop, not a discretionary
# judgment call, so it does not read the new content's error_budget value —
# only the record's state at the moment the transition is attempted.
#
# Kill switch: export ERROR_BUDGET_GATE_OFF=1 (or true/yes/on). Any other
# value — including an unrecognized typo — leaves the gate active
# (gate_kill_switch_active's fixed default; see gate-lib.sh).
set -uo pipefail

deny() { echo "error-budget-gate: refused — $1" >&2; exit 2; }

gate_kill_switch_active "${ERROR_BUDGET_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || deny "requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "empty tool-use payload on stdin; cannot evaluate the error-budget gate."

EB_PAYLOAD="$payload" python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import importlib.util, json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("error-budget-gate: refused — %s\n" % m); sys.exit(2)

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(gate_lib)

    raw = os.environ.get("EB_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse.")

    cwd = ev.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    try:
        root = posixpath.normpath(os.path.realpath(cwd).replace("\\", "/"))
    except OSError:
        root = None
    if not root:
        deny("no project root could be determined; failing closed.")

    candidates = []
    if tool in ("Write", "Edit", "MultiEdit"):
        p = ti.get("file_path")
        if isinstance(p, str) and p:
            candidates.append(p)
    elif tool == "Bash":
        cmd = ti.get("command")
        if isinstance(cmd, str) and cmd:
            candidates.extend(gate_lib.gate_bash_write_targets(cmd))

    if not candidates:
        sys.exit(0)

    rel = None
    for c in candidates:
        r = gate_lib.gate_normalize_path(root, c)
        if r == "ops/state.md":
            rel = r
            break
    if rel is None:
        sys.exit(0)  # not the state file — not this gate's business

    r = posixpath.join(root, rel)
    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed." % rel)

    if current is None:
        sys.exit(0)  # no prior record — nothing to refuse a transition away from

    m_budget = re.search(r'(?m)^error_budget:\s*(\S+)', current)
    budget = m_budget.group(1).strip().lower() if m_budget else ""
    if budget != "exhausted":
        sys.exit(0)  # budget not exhausted — this gate has nothing to refuse

    if tool == "Bash":
        # A Bash write target has no reconstructible content shape; the
        # gate can only see that the state file is being touched while the
        # budget is exhausted, not what its resulting status will be. Fail
        # closed rather than guess.
        deny(
            "the record's error_budget field currently reads exhausted, and this "
            "Bash command's target resolves to %s, but the gate cannot determine the "
            "resulting content from a shell command — failing closed rather than "
            "letting an unreadable transition through while the budget is spent." % rel
        )

    new_text, ok = gate_lib.gate_reconstruct_write(tool, ti, current)
    if not ok or new_text is None:
        deny(
            "the record's error_budget field currently reads exhausted, and this write "
            "targets %s, but the gate cannot determine the resulting content from the "
            "tool input (tool=%r) — failing closed rather than letting an unreadable "
            "transition through while the budget is spent." % (rel, tool)
        )

    m_status = re.search(r'(?m)^status:\s*(\S+)', new_text)
    new_status = m_status.group(1).strip().lower() if m_status else ""
    if new_status != "readiness":
        sys.exit(0)

    deny(
        "steady -> readiness is refused — error_budget reads exhausted. Per "
        "skill: error-budget-policy, only P0/security-fix work proceeds while the "
        "budget is spent, and that exception routes through the user as an explicit "
        "conversation, never a silent status/error_budget edit."
    )
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("error-budget-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "error-budget-gate: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
