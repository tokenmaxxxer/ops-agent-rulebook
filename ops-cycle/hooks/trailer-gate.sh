#!/usr/bin/env bash
# PreToolUse hook (Bash matching 'git commit'): enforces contract §13's commit
# trailer requirement for the ops role. When a unit is in progress for ops --
# i.e. some ops record (docs/reports/records/<subject>/ops.md) carries a
# non-terminal loop_state -- a commit must carry ops-cycle's declared trailer
# keys identifying the record it belongs to:
#     Subject: <subject>
#     Kind: ops-record
# A commit made while a unit is in progress that lacks either trailer is
# refused. (These are ops-cycle's own declared trailer keys, stated here in the
# rulebook per §13's "stated in the rulebook's own docs, not left implicit.")
#
# Fires at commit time because it inspects the commit message. It reads the ops
# record set to decide whether any unit is in progress; when none is, the gate
# is silent.
#
# FAIL-CLOSED (modeled on state-gate.sh): missing python3/git, unparseable
# payload, an indeterminate root, an ops record whose loop_state cannot be read,
# or a commit whose message cannot be determined while a unit is in progress all
# DENY (exit 2). A Bash call that is not a git commit passes through untouched.
set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "ops-cycle: refused -- trailer-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
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
  root="$(pwd -P)"
fi
[ -n "$root" ] || {
  echo "ops-cycle: refused -- no project root could be determined; the trailer gate fails closed." >&2
  exit 2
}

OPS_PAYLOAD="$payload" OPS_ROOT="$root" python3 <<'PY'
import json, os, posixpath, re, shlex, sys, glob

def deny(msg):
    sys.stderr.write("ops-cycle: refused -- " + msg + "\n")
    sys.exit(2)

def allow():
    sys.exit(0)

raw = os.environ.get("OPS_PAYLOAD", "")
try:
    event = json.loads(raw) if raw else {}
except ValueError:
    deny("the tool-call payload is not valid JSON; the trailer gate cannot judge a commit it cannot parse.")
if not isinstance(event, dict):
    deny("the tool-call payload is not a JSON object; the trailer gate cannot judge a commit it cannot parse.")

tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    deny("tool_input is missing or not a JSON object; the trailer gate cannot judge a commit it cannot parse.")

command = tool_input.get("command")
if not isinstance(command, str) or not command.strip():
    # No command to inspect. If this Bash event has no command it is not a git
    # commit we can judge; but an event that reached here with a non-string
    # command is malformed -> fail closed only if command key present-but-bad.
    if command is None:
        allow()
    deny("the Bash command is not a usable string; the trailer gate fails closed.")

# Is this a git commit at all?
if not re.search(r'(?:^|[\s&|;(])git(?:\s+-\S+)*\s+commit(?:\s|$)', command):
    allow()

root = posixpath.normpath(os.environ["OPS_ROOT"].replace("\\", "/"))

# --- is any ops unit in progress? --------------------------------------
# Non-terminal ops record states leave work open; a settled record (steady) or
# an un-started one (idle) is not an in-progress unit.
TERMINAL = {"steady", "idle"}
in_progress = False
records_glob = posixpath.join(root, "docs/reports/records/*/ops.md")
for rec in glob.glob(records_glob):
    try:
        with open(rec, encoding="utf-8-sig") as fh:
            text = fh.read(1 << 20)
    except OSError:
        deny("an ops record (%s) exists but cannot be read; the trailer gate fails closed rather "
             "than assume no unit is in progress." % rec)
    fm = ""
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            fm = text[3:end]
    m = re.search(r'(?im)^\s*loop_state\s*:\s*([^\r\n#]*?)\s*(?:#.*)?$', fm)
    if not m:
        deny("the ops record %s has no readable loop_state; the trailer gate fails closed rather "
             "than guess whether a unit is in progress." % rec)
    state = m.group(1).strip().lower()
    if state and state not in TERMINAL:
        in_progress = True
        break

if not in_progress:
    allow()

# --- a unit is in progress: the commit MUST carry the trailers ----------
# Recover the commit message from the command. Support -m/--message (possibly
# repeated) and -F/--file <path>. If the message cannot be determined, fail
# closed -- an in-progress unit may not commit without a checkable trailer.
try:
    tokens = shlex.split(command)
except ValueError:
    deny("the git commit command could not be tokenized; the trailer gate fails closed while a "
         "unit is in progress rather than let an unchecked commit through.")

messages = []
i = 0
uses_file = None
saw_commit = False
while i < len(tokens):
    t = tokens[i]
    if t == "commit":
        saw_commit = True
    if t in ("-m", "--message"):
        if i + 1 < len(tokens):
            messages.append(tokens[i + 1]); i += 2; continue
    elif t.startswith("--message="):
        messages.append(t[len("--message="):]); i += 1; continue
    elif t.startswith("-m") and len(t) > 2:
        messages.append(t[2:]); i += 1; continue
    elif t in ("-F", "--file"):
        if i + 1 < len(tokens):
            uses_file = tokens[i + 1]; i += 2; continue
    elif t.startswith("--file="):
        uses_file = t[len("--file="):]; i += 1; continue
    i += 1

msg_text = None
if messages:
    msg_text = "\n".join(messages)
elif uses_file is not None:
    fpath = uses_file if posixpath.isabs(uses_file) else posixpath.join(root, uses_file)
    try:
        with open(fpath, encoding="utf-8") as fh:
            msg_text = fh.read(1 << 20)
    except OSError:
        deny("the commit message file %r could not be read; the trailer gate fails closed while a "
             "unit is in progress." % uses_file)

if msg_text is None:
    deny(
        "a unit is in progress but this commit provides no inspectable message (no -m/--message "
        "and no -F/--file), so the required §13 trailer cannot be verified. Provide the message "
        "inline with -m so the gate can check for the 'Subject:' and 'Kind:' trailers; the gate "
        "fails closed rather than allow an unverifiable commit."
    )

has_subject = bool(re.search(r'(?im)^\s*Subject\s*:\s*\S', msg_text))
has_kind = bool(re.search(r'(?im)^\s*Kind\s*:\s*\S', msg_text))
if not (has_subject and has_kind):
    miss = []
    if not has_subject: miss.append("Subject:")
    if not has_kind: miss.append("Kind:")
    deny(
        "a unit is in progress (an ops record with a non-terminal loop_state) but this commit "
        "is missing the required §13 trailer key(s): %s. ops-cycle's declared trailer identifies "
        "the record a commit belongs to with `Subject: <subject>` and `Kind: ops-record`. Add "
        "the missing trailer line(s)." % ", ".join(miss)
    )

allow()
PY
