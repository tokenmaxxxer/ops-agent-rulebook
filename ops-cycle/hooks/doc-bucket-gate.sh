#!/usr/bin/env bash
# fail-closed trap: any abort with rc not in {0,2} is forced to DENY (exit 2).
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse hook (Write|Edit|MultiEdit|NotebookEdit): enforces contract §21's
# bucket half -- refuses any write under docs/ that would land outside the six
# doctrine buckets. Replicates coding-agent-rulebook's doctrine/placement-gate.sh
# shape (the only repo enforcing §21's bucket membership before this), relabeled
# for the ops role and hardened to state-gate.sh's fail-closed discipline.
#
# Scope is docs/ and nothing else. Outside docs/ the gate is silent, whatever
# the extension. Inside docs/ every file is governed: _assets/ is the bucket for
# images and attachments, so a loose PNG under docs/ is a violation like any
# other. Exceptions: docs/README.md, and a dot-directory or vendored tree that
# ALREADY exists on disk (doc-site tooling is left alone; new structure is not
# invented here).
#
# FAIL-CLOSED (modeled on state-gate.sh, NOT on the fail-open original): missing
# python3, unparseable payload, non-dict event/tool_input, or a missing path all
# DENY (exit 2). There is no kill switch: a gate that can be silently switched
# off is not a gate. Only a genuinely-determined out-of-scope write (outside the
# project, or under docs/ in a recognized bucket) allows.
set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "ops-cycle: refused -- doc-bucket-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
  exit 2
}

payload="$(cat 2>/dev/null || true)"

rc=0
OPS_PAYLOAD="$payload" python3 <<'PY' || rc=$?
import json, os, posixpath, sys

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

BUCKETS = ("decisions", "handbooks", "reports", "specs", "proposals", "_assets")
SKIP_DIRS = (
    "node_modules", "vendor", "dist", "build", "target", "out",
    "venv", ".venv", "site-packages", "coverage",
)

def allow():
    sys.exit(0)

def deny(msg):
    sys.stderr.write("ops-cycle: refused -- " + msg + "\n")
    sys.exit(2)

try:
    event = json.loads(os.environ.get("OPS_PAYLOAD", ""))
except ValueError:
    deny("the tool-call payload is not valid JSON; the bucket gate cannot judge a write it cannot parse.")
if not isinstance(event, dict):
    deny("the tool-call payload is not a JSON object; the bucket gate cannot judge a write it cannot parse.")

tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    deny("tool_input is missing or not a JSON object; the bucket gate cannot judge a write it cannot parse.")

path = tool_input.get("file_path") or tool_input.get("notebook_path")
if not isinstance(path, str) or not path:
    # A tool call with no path-shaped target (e.g. Bash) is not this gate's
    # business; direct file writes are all that carry a file_path.
    allow()

normalized = path.replace("\\", "/")

root = (os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()).replace("\\", "/")
absolute = posixpath.normpath(
    normalized if posixpath.isabs(normalized) else posixpath.join(root, normalized)
)
root = posixpath.normpath(root)

if absolute != root and not absolute.startswith(root + "/"):
    allow()

resolved = posixpath.normpath(os.path.realpath(absolute).replace("\\", "/"))
real_root = posixpath.normpath(os.path.realpath(root).replace("\\", "/"))
if absolute != resolved:
    if resolved != real_root and not resolved.startswith(real_root + "/"):
        allow()
    absolute, root = resolved, real_root

relative = absolute[len(root) + 1:]
segments = [s for s in relative.split("/") if s not in ("", ".")]
if not segments:
    allow()

directories, name = segments[:-1], segments[-1]

if "docs" not in directories:
    allow()

if directories[-1] == "docs" and name == "README.md":
    allow()

scaffolding = None
for i, directory in enumerate(directories):
    if directory == "docs" or "docs" not in directories[:i]:
        continue
    if directory in BUCKETS:
        allow()
    if directory in SKIP_DIRS or directory.startswith("."):
        if os.path.isdir(posixpath.join(root, *directories[:i + 1])):
            allow()
        scaffolding = "/".join(directories[:i + 1])
    break

buckets = ", ".join(b + "/" for b in BUCKETS)
if scaffolding:
    reason = (
        "`%s` would create `%s`, a new directory under docs/ that is not one of the six "
        "buckets. Doc-site tooling already on disk is left alone, but new structure under "
        "docs/ is not invented here." % (relative, scaffolding)
    )
else:
    reason = (
        "`%s` is under docs/ but not in one of the six buckets. Every file under docs/ "
        "belongs to a bucket -- images and attachments go in _assets/." % relative
    )

sys.stderr.write(
    "ops-cycle: refused -- %s\n"
    "The buckets are: %s.\n"
    "Classify by lifetime, not topic: undecided -> proposals/; invalidated by a code change -> specs/; "
    "kept current from now on -> handbooks/; why a hard-to-reverse choice was made -> decisions/; "
    "an observation fixed to a point in time -> reports/ (research under reports/research/).\n"
    "Create the bucket if it does not exist yet, then write there. Only docs/README.md may sit at the "
    "top of docs/.\n"
    % (reason, buckets)
)
sys.exit(2)
PY
# fail-closed layer 1 (shell): map ANY judge exit that is neither 0 nor 2 to a
# DENY; the `|| rc=$?` guard keeps set -e from aborting on a bare non-2 code.
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "ops-cycle: fail-closed: internal error (doc-bucket-gate.sh judge exited $rc); denying." >&2
  exit 2
fi
exit "$rc"
