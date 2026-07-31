#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse gate (Write|Edit|MultiEdit) — issue-27.
#
# On a write whose resolved target is docs/issue-<n>/proposals/*.md,
# require the RFC-shaped proposal sections adopted in
# docs/issue-27/proposals/2026-07-31-rulebook-maturation.md (a): scope /
# change description, risk (a named failure mode), rollback / back-out
# path, and at least one inline evidence citation (URL or repo path) for an
# adopted-methodology claim. Same shape/fail-closed discipline as core's
# record-fields-gate.sh, applied to this role's own proposal documents.
#
# Kill switch: export PROPOSAL_FIELDS_GATE_OFF=1
set -uo pipefail

deny() { echo "proposal-fields-gate: refused — $1" >&2; exit 2; }

case "${PROPOSAL_FIELDS_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || deny "requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "empty tool-use payload on stdin; cannot evaluate the proposal-fields gate."

PF_PAYLOAD="$payload" python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("proposal-fields-gate: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("PF_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge proposal fields on an unparseable write.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed.")

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse.")

    cwd = ev.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    root = None
    try:
        root = posixpath.normpath(os.path.realpath(cwd).replace("\\", "/"))
    except OSError:
        pass
    if not root:
        deny("no project root could be determined; failing closed.")

    PROPOSAL_RE = re.compile(r'^docs/issue-[0-9]+/proposals/.*\.md$')

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
    if not PROPOSAL_RE.match(rel):
        sys.exit(0)  # not a proposal document — not this gate's business

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
            "from the tool input (tool=%r). Write the full proposal with Write, or use an "
            "Edit/MultiEdit whose old_string matches, so the RFC-shaped sections can be "
            "checked." % (rel, tool)
        )

    low = new_text.lower()

    def has_any(*needles):
        return any(nd in low for nd in needles)

    missing = []
    if not has_any("scope", "change description"):
        missing.append("scope/change-description")
    if not has_any("## risk", "risk\n", "risk:"):
        missing.append("risk")
    if not has_any("rollback", "back-out", "back out"):
        missing.append("rollback/back-out-path")
    if not (re.search(r'https?://', new_text) or re.search(r'docs/[a-z0-9_./-]+', new_text)
            or re.search(r'`[a-z0-9_./-]+\.(md|sh)`', new_text)):
        missing.append("sourced-evidence-citation")

    if missing:
        deny(
            "proposal is missing required RFC-shaped section(s): %s. Per docs/issue-27/"
            "proposals/2026-07-31-rulebook-maturation.md (a), every release-engineering "
            "proposal must state scope/change description, a named risk, a rollback/"
            "back-out path, and cite at least one source (URL or repo path) for any "
            "adopted-methodology claim." % ", ".join(missing)
        )

    sys.exit(0)
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("proposal-fields-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "proposal-fields-gate: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
