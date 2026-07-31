#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse gate (Write|Edit|MultiEdit) — issue-27.
#
# On a write whose resolved target is ops/rollout-plan.md, require every
# metric inside a step block to carry a non-empty threshold: field before
# that step can be written with result: pass or result: fail. A step must
# not be marked resolved with an unset threshold — closing the "invent a
# threshold mid-rollout" failure mode the issue-27 scout brief flagged as
# rollout-plan's core discipline (skill: rollout-plan). result: pending (or
# any non-pass/fail value) is never gated — thresholds are only required at
# the moment a step is declared resolved.
#
# Kill switch: export ROLLOUT_PLAN_FIELDS_GATE_OFF=1
set -uo pipefail

deny() { echo "rollout-plan-fields-gate: refused — $1" >&2; exit 2; }

case "${ROLLOUT_PLAN_FIELDS_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || deny "requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "empty tool-use payload on stdin; cannot evaluate the rollout-plan-fields gate."

RP_PAYLOAD="$payload" python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("rollout-plan-fields-gate: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("RP_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge rollout-plan fields on an unparseable write.")
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
    if rel != "ops/rollout-plan.md":
        sys.exit(0)  # not the rollout plan — not this gate's business

    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed." % rel)

    new_text = None
    if tool == "Write":
        c = ti.get("content")
        if isinstance(c, str):
            new_text = c
    elif tool == "Edit":
        o, n = ti.get("old_string"), ti.get("new_string")
        if isinstance(o, str) and isinstance(n, str) and current is not None and o in current:
            new_text = current.replace(o, n, 1)
    elif tool == "MultiEdit":
        edits = ti.get("edits")
        text = current
        if isinstance(edits, list) and text is not None:
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
            "this write targets %s but the gate cannot determine the resulting content "
            "from the tool input (tool=%r). Write the full plan with Write, or use an "
            "Edit/MultiEdit whose old_string matches, so per-step thresholds can be "
            "checked." % (rel, tool)
        )

    # Split into step blocks on '## Step' headers.
    steps = re.split(r'(?m)^##\s*Step\b', new_text)[1:]
    bad_steps = []
    for idx, block in enumerate(steps, start=1):
        m_result = re.search(r'(?m)^\s*-?\s*result:\s*(\S+)', block)
        if not m_result:
            continue
        result = m_result.group(1).strip().lower()
        if result not in ("pass", "fail"):
            continue  # pending/other — not gated
        # Metric entries: '- name: <x>' up to the next '- name:' or block end.
        names = list(re.finditer(r'(?m)^\s*-\s*name:\s*\S+', block))
        if not names:
            bad_steps.append((idx, result, "no metrics declared"))
            continue
        for i, mn in enumerate(names):
            start = mn.end()
            end = names[i + 1].start() if i + 1 < len(names) else len(block)
            segment = block[start:end]
            m_th = re.search(r'(?m)^\s*threshold:\s*(\S.*)$', segment)
            if not m_th or not m_th.group(1).strip():
                bad_steps.append((idx, result, "metric %r has no non-empty threshold" % mn.group(0).strip()))

    if bad_steps:
        details = "; ".join("step %d (result: %s): %s" % b for b in bad_steps)
        deny(
            "a step is marked result: pass/fail with an unset threshold — %s. Per "
            "skill: rollout-plan, a step must not be resolved without a pre-declared "
            "per-metric threshold." % details
        )

    sys.exit(0)
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("rollout-plan-fields-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "rollout-plan-fields-gate: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
