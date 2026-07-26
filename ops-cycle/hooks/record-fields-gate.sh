#!/usr/bin/env bash
# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit): enforces contract §20's
# per-role record minimum content on writes reaching THIS role's own record,
# docs/reports/records/<subject>/ops.md.
#
# This is a peer check to state-gate.sh, NOT a replacement: state-gate.sh
# validates the ops/state.md transition table; this gate validates that the
# ops record a next reader will pick up cold carries the §20-required
# sections. It reads the SAME proposed content state-gate.sh already reads
# (Write content, or an Edit/MultiEdit reconstructed against the current
# file), adding a second, content-level field check on a different target.
#
# §20 requires, at minimum, on every ops record:
#   1. what was done      2. why      3. the concrete basis to continue
#      (upstream: + loop_state: in the frontmatter)
# and additionally, whenever the record leaves work open (loop_state is not a
# settled/terminal ops state), a next-steps backlog and an open-finding
# resolution path.
#
# FAIL-CLOSED (modeled on state-gate.sh, never on the fail-open placement
# gate): missing python3, unparseable payload, non-dict event/tool_input, a
# reconstruction it cannot perform, or a record whose loop_state it cannot
# read all DENY (exit 2) -- never a silent exit 0. Writes that do not reach an
# ops record pass through untouched.
set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "ops-cycle: refused -- record-fields-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
  exit 2
}

payload="$(cat 2>/dev/null || true)"

root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ] \
   && { [ -e "$CLAUDE_PROJECT_DIR/.git" ] || [ -f "$CLAUDE_PROJECT_DIR/docs/specs/role-handoff-contract.md" ]; }; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
if [ -z "$root" ]; then
  root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$root" ]; then
  echo "ops-cycle: refused -- no project root could be determined (CLAUDE_PROJECT_DIR unset or invalid, and no git top-level for cwd); the record-fields gate fails closed rather than guess a root." >&2
  exit 2
fi

rc=0
OPS_PAYLOAD="$payload" OPS_ROOT="$root" python3 <<'PY' || rc=$?
import json, os, posixpath, re, sys

# fail-closed layer 2 (python): any uncaught exception in the judge -- e.g.
# os.path.realpath on a null-byte/undecodable path raising ValueError -- becomes
# a DENY (exit 2), never an uncaught exit 1 (fail-open). deny()/allow() use
# sys.exit (SystemExit), which bypasses the excepthook, so verdicts are exact.
def _ops_fail_closed(_t, _e, _tb):
    try:
        sys.stderr.write("ops-cycle: fail-closed: internal error (%s: %s)\n" % (getattr(_t, "__name__", _t), _e))
        sys.stderr.flush()
    except Exception:
        pass
    os._exit(2)
sys.excepthook = _ops_fail_closed

def deny(msg):
    sys.stderr.write("ops-cycle: refused -- " + msg + "\n")
    sys.exit(2)

def allow():
    sys.exit(0)

raw = os.environ.get("OPS_PAYLOAD", "")
try:
    event = json.loads(raw) if raw else {}
except ValueError:
    deny("the tool-call payload is not valid JSON; the record-fields gate cannot judge a write it cannot parse.")
if not isinstance(event, dict):
    deny("the tool-call payload is not a JSON object; the record-fields gate cannot judge a write it cannot parse.")

tool = event.get("tool_name")
tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    deny("tool_input is missing or not a JSON object; the record-fields gate cannot judge a write it cannot parse.")

root = posixpath.normpath(os.environ["OPS_ROOT"].replace("\\", "/"))

def resolve(path):
    normalized = path.replace("\\", "/")
    absolute = normalized if posixpath.isabs(normalized) else posixpath.join(root, normalized)
    absolute = posixpath.normpath(absolute)
    try:
        return posixpath.normpath(os.path.realpath(absolute).replace("\\", "/"))
    except OSError:
        return absolute

path = None
if tool in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    path = tool_input.get("file_path") or tool_input.get("notebook_path")
if not isinstance(path, str) or not path:
    allow()

resolved = resolve(path)
if not (resolved == root or resolved.startswith(root + "/")):
    allow()
rel = resolved[len(root):].lstrip("/")

RECORD_RE = re.compile(r'^docs/reports/records/([^/]+)/ops\.md$')
if not RECORD_RE.match(rel):
    allow()

current_text = None
if os.path.isfile(resolved):
    try:
        with open(resolved, encoding="utf-8-sig") as fh:
            current_text = fh.read(1 << 20)
    except OSError:
        current_text = None

new_text = None
if tool == "Write":
    content = tool_input.get("content")
    if isinstance(content, str):
        new_text = content
elif tool == "Edit":
    o, n = tool_input.get("old_string"), tool_input.get("new_string")
    if isinstance(o, str) and isinstance(n, str) and current_text is not None and o in current_text:
        new_text = current_text.replace(o, n, 1)
elif tool == "MultiEdit":
    edits = tool_input.get("edits")
    text = current_text
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
        "this write targets the ops record %s but the record-fields gate could not "
        "reconstruct the resulting content from the tool input (tool=%r). Write the full "
        "record with Write, or use an Edit whose old_string matches the current file, so "
        "the required sections can be checked. The gate fails closed rather than pass an "
        "unverifiable record." % (rel, tool)
    )

missing = []
if not re.search(r'(?im)^\s*#{1,6}\s*what\s+was\s+done\b', new_text):
    missing.append("a 'What was done' section")
if not re.search(r'(?im)^\s*#{1,6}\s*why\b', new_text):
    missing.append("a 'Why' section")

fm = ""
if new_text.startswith("---"):
    end = new_text.find("\n---", 3)
    if end != -1:
        fm = new_text[3:end]
if not fm.strip():
    deny(
        "the ops record %s has no YAML frontmatter block; the concrete basis (upstream: and "
        "loop_state:) a next reader continues from lives in the frontmatter. The gate fails "
        "closed on a record with no frontmatter." % rel
    )
if not re.search(r'(?im)^\s*upstream\s*:', fm):
    missing.append("an 'upstream:' basis in the frontmatter")
loop_m = re.search(r'(?im)^\s*loop_state\s*:\s*([^\r\n#]*?)\s*(?:#.*)?$', fm)
if not loop_m:
    missing.append("a 'loop_state:' field in the frontmatter")
    loop_state = None
else:
    loop_state = loop_m.group(1).strip().lower()

TERMINAL = {"steady", "idle"}
is_open = (loop_state is None) or (loop_state not in TERMINAL)
if is_open:
    if not re.search(r'(?im)^\s*#{1,6}\s*next[-\s]?steps\b', new_text):
        missing.append("a 'Next steps' section (record leaves work open)")
    if not re.search(r'(?im)^\s*#{1,6}\s*.*(open[-\s]?finding|finding\s+resolution|resolution\s+path)', new_text):
        missing.append("an open-finding resolution-path section (record leaves work open)")

if missing:
    deny(
        "the ops record %s is missing required section(s): %s. Per contract §20 every role "
        "record must state what was done, why, and the concrete upstream basis (upstream: + "
        "loop_state:); a record that leaves work open must additionally give a next-steps "
        "backlog and an open-finding resolution path so a zero-context reader can continue."
        % (rel, "; ".join(missing))
    )

allow()
PY
# fail-closed layer 1 (shell): map ANY judge exit that is neither 0 nor 2 to a
# DENY; the `|| rc=$?` guard keeps set -e from aborting on a bare non-2 code.
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "ops-cycle: fail-closed: internal error (record-fields-gate.sh judge exited $rc); denying." >&2
  exit 2
fi
exit "$rc"
