#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "readiness-fields-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
# PreToolUse gate (Write|Edit|MultiEdit) — issue-33, migrated to the
# gate-house standard (issue-36, core issue #72's shared gate-lib.sh/
# gate-lib.py).
#
# On a write whose resolved target is ops/state.md, if the resulting
# content sets `status: rollout`, require every `- item:` line inside the
# `## Checklist` section (only) to resolve yes/no, and every `yes` item to
# carry a non-empty `artifact:` pointer. "We have monitoring" with nothing
# to link is a FAIL, not a pass with a caveat (skill: readiness-checklist).
# Any other status value, or a write that does not touch status, is not
# this gate's business.
#
# Kill switch: export READINESS_FIELDS_GATE_OFF=1 (or true/yes/on). Any
# other value — including an unrecognized typo — leaves the gate active
# (gate_kill_switch_active's fixed default; see gate-lib.sh).
set -uo pipefail

deny() { echo "readiness-fields-gate: refused — $1" >&2; exit 2; }

gate_kill_switch_active "${READINESS_FIELDS_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || deny "requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "empty tool-use payload on stdin; cannot evaluate the readiness-fields gate."

RF_PAYLOAD="$payload" python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import importlib.util, json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("readiness-fields-gate: refused — %s\n" % m); sys.exit(2)

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(gate_lib)

    raw = os.environ.get("RF_PAYLOAD", "")
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

    if tool == "Bash":
        # A Bash write target has no reconstructible content shape; the
        # gate can only see that the state file is being touched, not what
        # its resulting status/checklist will be. Fail closed rather than
        # guess.
        deny(
            "this Bash command's target resolves to %s (the readiness state file) but "
            "the gate cannot determine the resulting content from a shell command. "
            "Write the file with Write, or use an Edit/MultiEdit, so the checklist "
            "can be checked." % rel
        )

    new_text, ok = gate_lib.gate_reconstruct_write(tool, ti, current)
    if not ok or new_text is None:
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

    # Section-scoped: only `- item:` lines inside the `## Checklist` block
    # (from its heading to the next `##` heading or end-of-file) count as
    # real checklist items — a line outside that block, even if it matches
    # the same shape, is not admitted (issue-36 defect #3).
    m_section = re.search(r'(?m)^##\s*Checklist\s*$', new_text)
    if not m_section:
        deny(
            "status is being set to rollout but ops/state.md has no `## Checklist` "
            "section at all — the seven-dimension PRR must be worked before this "
            "transition (skill: readiness-checklist)."
        )
    section_start = m_section.end()
    m_next = re.search(r'(?m)^##\s', new_text[section_start:])
    section_end = section_start + m_next.start() if m_next else len(new_text)
    section_text = new_text[section_start:section_end]

    items = re.findall(r'(?m)^\s*-\s*item:.*$', section_text)
    if not items:
        deny(
            "status is being set to rollout but the `## Checklist` section has no "
            "`- item:` lines — the seven-dimension PRR must be worked before this "
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
