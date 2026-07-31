#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse gate (Write|Edit|MultiEdit) — issue-33.
#
# On a write whose resolved target is ops/state.md, if the CURRENT record's
# error_budget field reads exhausted and the write's resulting content sets
# `status: readiness`, refuse outright — a release cycle may not be picked
# back up while the error budget is spent, regardless of readiness
# (skill: error-budget-policy). This is a hard stop, not a discretionary
# judgment call, so it does not read the new content's error_budget value —
# only the record's state at the moment the transition is attempted.
#
# Kill switch: export ERROR_BUDGET_GATE_OFF=1
set -uo pipefail

deny() { echo "error-budget-gate: refused — $1" >&2; exit 2; }

case "${ERROR_BUDGET_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || deny "requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "empty tool-use payload on stdin; cannot evaluate the error-budget gate."

EB_PAYLOAD="$payload" python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("error-budget-gate: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("EB_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge the error-budget field on an unparseable write.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed.")

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

    def resolve(p):
        n = p.replace("\\", "/")
        a = n if posixpath.isabs(n) else posixpath.join(root, n)
        a = posixpath.normpath(a)
        try:
            return posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
        except OSError:
            return a

    path = None
    if tool in ("Write", "Edit", "MultiEdit"):
        p = ti.get("file_path")
        if isinstance(p, str) and p:
            path = p
    if path is None:
        sys.exit(0)

    r = resolve(path)
    if not r.startswith(root + "/"):
        sys.exit(0)
    rel = r[len(root):].lstrip("/")
    if rel != "ops/state.md":
        sys.exit(0)  # not the state file — not this gate's business

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

    new_text = None
    if tool == "Write":
        c = ti.get("content")
        if isinstance(c, str):
            new_text = c
    elif tool == "Edit":
        o, n = ti.get("old_string"), ti.get("new_string")
        if isinstance(o, str) and isinstance(n, str) and o in current:
            new_text = current.replace(o, n, 1)
    elif tool == "MultiEdit":
        edits = ti.get("edits")
        text = current
        if isinstance(edits, list):
            ok = True
            for e in edits:
                if not isinstance(e, dict):
                    ok = False; break
                o, n = e.get("old_string"), e.get("new_string")
                if not isinstance(o, str) or not isinstance(n, str) or o not in text:
                    ok = False; break
                text = text.replace(o, n, 1)
            if ok:
                new_text = text

    if new_text is None:
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
