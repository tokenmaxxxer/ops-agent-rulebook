#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse gate (Write|Edit|MultiEdit) — issue-33.
#
# On a write whose resolved target is ops/state.md, if the resulting content
# sets `status: rollout`, require every `## Checklist` line to resolve
# yes/no, and every `yes` item to carry a non-empty `artifact:` pointer.
# "We have monitoring" with nothing to link is a FAIL, not a pass with a
# caveat (skill: readiness-checklist). Any other status value, or a write
# that does not touch status, is not this gate's business.
#
# Kill switch: export READINESS_FIELDS_GATE_OFF=1
set -uo pipefail

deny() { echo "readiness-fields-gate: refused — $1" >&2; exit 2; }

case "${READINESS_FIELDS_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || deny "requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "empty tool-use payload on stdin; cannot evaluate the readiness-fields gate."

RF_PAYLOAD="$payload" python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("readiness-fields-gate: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("RF_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge readiness fields on an unparseable write.")
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
            "from the tool input (tool=%r). Write the full state file with Write, or use an "
            "Edit/MultiEdit whose old_string matches, so the readiness checklist can be "
            "checked." % (rel, tool)
        )

    m_status = re.search(r'(?m)^status:\s*(\S+)', new_text)
    status = m_status.group(1).strip().lower() if m_status else ""
    if status != "rollout":
        sys.exit(0)  # not a transition into rollout — not this gate's business

    items = re.findall(r'(?m)^\s*-\s*item:.*$', new_text)
    if not items:
        deny(
            "status is being set to rollout but ops/state.md has no `## Checklist` "
            "items at all — the seven-dimension PRR must be worked before this "
            "transition (skill: readiness-checklist)."
        )

    bad = []
    for line in items:
        m_stat = re.search(r'status:\s*(\S+)', line)
        item_status = m_stat.group(1).strip().lower() if m_stat else None
        if item_status not in ("yes", "no"):
            bad.append((line.strip(), "status must be exactly yes or no"))
            continue
        if item_status == "yes":
            m_art = re.search(r'artifact:[ \t]*(.*)$', line)
            artifact = m_art.group(1).strip() if m_art else ""
            if not artifact:
                bad.append((line.strip(), "status: yes with an empty artifact — this is a FAIL, not a pass with a caveat"))

    if bad:
        details = "; ".join("%r: %s" % b for b in bad)
        deny(
            "readiness -> rollout is refused — %s. Per skill: readiness-checklist, "
            "every checklist item must resolve yes/no and every yes needs a real, "
            "pointable artifact before status may flip to rollout." % details
        )

    sys.exit(0)
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("readiness-fields-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "readiness-fields-gate: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
