#!/usr/bin/env bash
# fail-closed trap: any abort with rc not in {0,2} is forced to DENY (exit 2).
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit): enforces contract §11's
# static, role-permanent path ownership for the ops role. Generalizes
# warrant/scope-gate.sh's write-set shape (a per-proposal freeze) to §11's
# fixed owned-path table: ops owns ONLY
#   docs/reports/records/<subject>/ops.md
#   docs/reports/records/<subject>/postmortems/**
# under the shared records tree. A write from this ops session into ANOTHER
# role's record slot under the same records tree is refused and reported --
# never overwritten or merged -- per §11's never-overwrite rule.
#
# Scope is the records tree only. Writes outside docs/reports/records/ (source,
# the §21 decisions/reports/specs a role authors, handbooks) are not this
# gate's business and pass through; the bucket gate and handbook gate own
# those. This gate settles exactly one claim: "is this records-tree path mine?"
#
# FAIL-CLOSED (modeled on state-gate.sh): missing python3, unparseable payload,
# non-dict event/tool_input, or a records-tree path whose owning role cannot be
# determined all DENY (exit 2) -- never a silent exit 0.
set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "ops-cycle: refused -- path-ownership-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
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
  echo "ops-cycle: refused -- no project root could be determined; the path-ownership gate fails closed rather than guess a root." >&2
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
    deny("the tool-call payload is not valid JSON; the path-ownership gate cannot judge a write it cannot parse.")
if not isinstance(event, dict):
    deny("the tool-call payload is not a JSON object; the path-ownership gate cannot judge a write it cannot parse.")

tool = event.get("tool_name")
tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    deny("tool_input is missing or not a JSON object; the path-ownership gate cannot judge a write it cannot parse.")

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

RECORDS_PREFIX = "docs/reports/records/"
if not rel.startswith(RECORDS_PREFIX):
    allow()  # outside the shared records tree -> not this gate's claim

tail = rel[len(RECORDS_PREFIX):]
parts = tail.split("/")
# Expect <subject>/<something...>. A records-tree path we cannot decompose into
# at least <subject>/<file-or-dir> is malformed -> fail closed.
if len(parts) < 2 or not parts[0] or not parts[1]:
    deny(
        "the write target %s is inside the records tree but does not resolve to a "
        "<subject>/<role-file> shape the ownership gate can judge; it fails closed rather "
        "than allow an unclassifiable records-tree write." % rel
    )

subject = parts[0]
second = parts[1]

OWN_FILE = "ops.md"
OWN_SUBDIR = "postmortems"
ROLE_FILE_RE = re.compile(r'^(product|coding|qa|feasibility|ux-design|review|verify|reflect|ops)\.md$')
# Known per-role subdirectories under a subject (section 11 / section 2).
ROLE_SUBDIR_OWNER = {
    "postmortems": "ops",
    "qa": "qa",
    "spikes": "feasibility",
}

# ops' own slots -> allow.
if second == OWN_FILE and len(parts) == 2:
    allow()
if second == OWN_SUBDIR:
    allow()

# Another role's record file directly under the subject -> refuse.
m = ROLE_FILE_RE.match(second) if len(parts) == 2 else None
if m:
    owner = m.group(1)
    deny(
        "'%s' is owned by role '%s' per contract §11, not 'ops'. A role finding another "
        "role's record slot must report the conflict; it does not overwrite or merge into "
        "another role's record." % (rel, owner)
    )

# Another role's known subdirectory -> refuse.
if second in ROLE_SUBDIR_OWNER:
    owner = ROLE_SUBDIR_OWNER[second]
    deny(
        "'%s' is under role '%s''s owned subdirectory (docs/reports/records/%s/%s/) per "
        "contract §11, not 'ops'. Report the conflict; do not write into another role's "
        "owned subtree." % (rel, owner, subject, second)
    )

# An unrecognized entry directly under a subject (neither a known role file nor
# a known role subdir). This is an unclassifiable records-tree write -> fail
# closed rather than silently allow a write whose ownership is unknown.
deny(
    "the write target %s sits directly in the records tree under subject '%s' but is "
    "neither ops' own owned slot (ops.md / postmortems/) nor a recognized role slot; the "
    "ownership gate fails closed on a records-tree path whose owner it cannot determine."
    % (rel, subject)
)
PY
# fail-closed layer 1 (shell): map ANY judge exit that is neither 0 nor 2 to a
# DENY; the `|| rc=$?` guard keeps set -e from aborting on a bare non-2 code.
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "ops-cycle: fail-closed: internal error (path-ownership-gate.sh judge exited $rc); denying." >&2
  exit 2
fi
exit "$rc"
