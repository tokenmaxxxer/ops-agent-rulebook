#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "proposal-fields-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
# PreToolUse gate (Write|Edit|MultiEdit|Bash) — issue-27, migrated to the
# gate-house standard (issue-39, core issue #72's shared gate-lib.sh/
# gate-lib.py).
#
# On a write whose resolved target is docs/issue-<n>/proposals/*.md,
# require the RFC-shaped proposal sections adopted in
# docs/issue-27/proposals/2026-07-31-rulebook-maturation.md (a): scope /
# change description, risk (a named failure mode), rollback / back-out
# path, and at least one inline evidence citation (URL or repo path) for an
# adopted-methodology claim. Same shape/fail-closed discipline as core's
# record-fields-gate.sh, applied to this role's own proposal documents.
#
# Kill switch: export PROPOSAL_FIELDS_GATE_OFF=1 (or true/yes/on). Any
# other value — including an unrecognized typo — leaves the gate active
# (gate_kill_switch_active's fixed default; see gate-lib.sh).
set -uo pipefail

deny() { echo "proposal-fields-gate: refused — $1" >&2; exit 2; }

gate_kill_switch_active "${PROPOSAL_FIELDS_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || deny "requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "empty tool-use payload on stdin; cannot evaluate the proposal-fields gate."

PF_PAYLOAD="$payload" python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import importlib.util, json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("proposal-fields-gate: refused — %s\n" % m); sys.exit(2)

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(gate_lib)

    raw = os.environ.get("PF_PAYLOAD", "")
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

    PROPOSAL_RE = re.compile(r'^docs/issue-[0-9]+/proposals/.*\.md$')

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
        if r is not None and PROPOSAL_RE.match(r):
            rel = r
            break
    if rel is None:
        sys.exit(0)  # not a proposal document — not this gate's business

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
        # gate can only see that a proposal document is being touched, not
        # what its resulting text will be. Fail closed rather than guess.
        deny(
            "this Bash command's target resolves to %s (a proposal document) but "
            "the gate cannot determine the resulting content from a shell command. "
            "Write the proposal with Write, or use an Edit/MultiEdit, so the "
            "RFC-shaped sections can be checked." % rel
        )

    new_text, ok = gate_lib.gate_reconstruct_write(tool, ti, current)
    if not ok or new_text is None:
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
