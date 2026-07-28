#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse hook (Bash matching `git commit`): enforces contract §13's
# commit-trailer requirement. A commit that stages anything under an issue
# tree (docs/issue-<n>/**) must carry the machine-checkable trailer naming
# that subject:
#
#     Subject: issue-<n>
#
# and one commit belongs to one subject — staging two issues' trees in one
# commit is refused. Commits staging no issue-tree work pass through.
# Fail-closed: a commit whose message cannot be read statically while a unit
# is open is DENIED (use `git commit -m` so the trailer is verifiable).
# Kill switch: export OPS_CYCLE_OFF=1
set -uo pipefail

deny() { echo "ops: refused — $1" >&2; exit 2; }

case "${OPS_CYCLE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || deny "trailer-gate: python3 is required to evaluate the gate and is not on PATH."

payload="$(cat 2>/dev/null)"
[ -n "$payload" ] || deny "trailer-gate: empty tool-use payload on stdin; cannot evaluate the trailer gate."

OPS_PAYLOAD="$payload" \
OPS_CPD="${CLAUDE_PROJECT_DIR:-}" \
OPS_CWD="$(pwd -P 2>/dev/null || echo)" \
python3 <<'PY'
import json, os, posixpath, re, shlex, subprocess, sys

def deny(msg):
    sys.stderr.write("ops: refused — %s\n" % msg)
    sys.exit(2)

def allow():
    sys.exit(0)

# --- fail-closed on internal error (frozen contract) -----------------------
# Any uncaught exception in this judge (e.g. os.path.realpath on a null-byte
# or undecodable path raising ValueError) must become a DENY (exit 2), never
# an uncaught exit 1 that PreToolUse treats as non-blocking (fail-open).
def _ops_fail_closed(_t, _v, _tb):
    try:
        sys.stderr.write("ops: refused — fail-closed: internal error (%s: %s)\n" % (_t.__name__, _v))
    except Exception:
        pass
    os._exit(2)
sys.excepthook = _ops_fail_closed

raw = os.environ.get("OPS_PAYLOAD", "")
try:
    event = json.loads(raw)
except ValueError:
    deny("trailer-gate: the tool-use payload is not valid JSON.")
if not isinstance(event, dict):
    deny("trailer-gate: the tool-use payload is not a JSON object.")

tool = event.get("tool_name")
ti = event.get("tool_input")
if not isinstance(tool, str) or not tool:
    deny("trailer-gate: payload has no tool_name.")
if tool != "Bash":
    allow()
if not isinstance(ti, dict):
    deny("trailer-gate: payload has no tool_input object.")

command = ti.get("command")
if not isinstance(command, str) or not command.strip():
    deny("trailer-gate: Bash call has no usable command string.")

if not re.search(r'\bgit\b[^\n;&|]*\bcommit\b(?!-)', command):
    allow()

# --- root resolution -----------------------------------------------------
def git_toplevel(start):
    try:
        d = start if os.path.isdir(start) else os.path.dirname(start)
        if not d:
            return None
        out = subprocess.run(["git", "-C", d, "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, timeout=10)
        top = out.stdout.strip()
        return top or None
    except Exception:
        return None

def plausible_root(r):
    return bool(r) and os.path.isdir(r) and (
        os.path.exists(os.path.join(r, ".git"))
        or os.path.isfile(os.path.join(r, "docs/specs/role-handoff-contract.md")))

cpd = os.environ.get("OPS_CPD", "")
cwd = os.environ.get("OPS_CWD", "") or "."

root = None
if plausible_root(cpd):
    root = os.path.realpath(cpd)
if root is None:
    root = git_toplevel(cwd)
if not root:
    deny("trailer-gate: no project root could be determined for the commit; refusing rather than allowing an unverified commit.")

# --- does this commit stage issue-tree work? ------------------------------
try:
    out = subprocess.run(["git", "-C", root, "diff", "--cached", "--name-only"],
                         capture_output=True, text=True, timeout=10)
    staged = [l.strip() for l in out.stdout.splitlines() if l.strip()] if out.returncode == 0 else None
except Exception:
    staged = None
if staged is None:
    deny("trailer-gate: could not read the staged file list to decide whether this commit lands issue-tree work; refusing rather than allowing an unverified commit.")

issues = set()
for f in staged:
    im = re.match(r"^docs/(issue-[0-9]+)/", f)
    if im:
        issues.add(im.group(1))
if not issues:
    allow()  # no issue-tree work staged; the trailer requirement does not gate it
if len(issues) > 1:
    deny("trailer-gate: this commit stages work for multiple issues (%s); one commit belongs to one subject (contract s13). Split the commit." % ", ".join(sorted(issues)))
issue = sorted(issues)[0]

# --- unit in progress: require reflect's Subject: trailer ----------------
# Extract commit messages statically from -m/--message. If the commit
# supplies no inline message (editor or -F file), the trailer cannot be
# verified statically -> fail closed.
try:
    tokens = shlex.split(command)
except ValueError:
    deny("trailer-gate: the commit command could not be tokenized to verify its trailer; use `git commit -m` with the required `Subject:` trailer.")

messages = []
i = 0
uses_file_or_editor = False
while i < len(tokens):
    tok = tokens[i]
    if tok in ("-m", "--message"):
        if i + 1 < len(tokens):
            messages.append(tokens[i + 1])
            i += 2
            continue
    elif tok.startswith("--message="):
        messages.append(tok[len("--message="):])
    elif tok.startswith("-m") and len(tok) > 2:
        messages.append(tok[2:])
    elif tok in ("-F", "--file") or tok.startswith("--file=") or (tok.startswith("-F") and len(tok) > 2):
        uses_file_or_editor = True
    i += 1

joined = "\n".join(messages)

if not messages:
    if uses_file_or_editor:
        deny("trailer-gate: this commit stages %s work and supplies its message via a file/editor, so the required `Subject: %s` trailer (contract s13) cannot be verified statically. Pass the message with `git commit -m`." % (issue, issue))
    deny("trailer-gate: this commit stages %s work but carries no inline `-m` message, so its `Subject: %s` trailer (contract s13) cannot be verified. Use `git commit -m`." % (issue, issue))

if not re.search(r"(?im)^\s*Subject:\s*" + re.escape(issue) + r"\s*$", joined):
    deny("trailer-gate: this commit stages %s work but its message lacks the required `Subject: %s` trailer (contract s13). The trailer names the subject the staged record belongs to." % (issue, issue))

allow()
PY
rc=$?
# Fail-closed shell layer (frozen contract): the judge's exit code decides
# allow(0)/deny(2). ANY other exit code — a crash, an unguarded pipeline
# abort, a killed interpreter — maps to a DENY (exit 2), never passes through
# as a non-2 non-zero that PreToolUse would treat as non-blocking (fail-open).
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "ops: refused — fail-closed: internal error (gate judge exited $rc)" >&2
  exit 2
fi
exit "$rc"
