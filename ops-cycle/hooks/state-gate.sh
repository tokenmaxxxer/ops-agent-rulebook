#!/usr/bin/env bash
# PreToolUse hook (matcher ".*"): enforces the ops role's state machine
# (docs/specs/state-machine.md in this repository; sourced from
# docs/specs/agent-roles.md's `ops` role in the tokenmaxxxer spec repo).
#
# The state file is ops/state.md (repo root, resolved via CLAUDE_PROJECT_DIR
# or `git rev-parse --show-toplevel`); the state field is its frontmatter
# `status:` key. This gate is evaluated against the TARGET PATH a tool is
# about to write, never against which tool performs the write: a Write/Edit/
# NotebookEdit payload and a Bash command that redirects, tees, copies, or
# moves into ops/state.md are judged identically. A write that does not
# touch ops/state.md is none of this gate's business and is allowed.
#
# On any malformed input this gate DENIES rather than falling through to
# allow: unparseable JSON payload, an unreadable or unparseable state file
# when one is required to judge the write, or a proposed edit to the state
# file whose resulting `status:` cannot be determined.
#
# There is no kill switch. A gate that can be silently switched off is not
# a gate; if this hook is in the way, remove it from hooks.json instead.
set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "ops-cycle: state-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
  exit 2
}

payload="$(cat 2>/dev/null || true)"

root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$root" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$root" ] || [ ! -d "$root" ]; then
  root="$(pwd -P)"
fi
root="$(cd "$root" 2>/dev/null && pwd -P)" || {
  echo "ops-cycle: cannot resolve the project root; denying." >&2
  exit 2
}

OPS_PAYLOAD="$payload" OPS_ROOT="$root" python3 <<'PY'
import json, os, posixpath, re, sys

def deny(msg):
    sys.stderr.write("ops-cycle: refused — " + msg + "\n")
    sys.exit(2)

def allow():
    sys.exit(0)

raw = os.environ.get("OPS_PAYLOAD", "")
try:
    event = json.loads(raw) if raw else {}
except ValueError:
    deny("the tool-call payload is not valid JSON. Malformed input denies rather than falls through.")
if not isinstance(event, dict):
    deny("the tool-call payload is not a JSON object.")

tool = event.get("tool_name")
tool_input = event.get("tool_input")
if not isinstance(tool_input, dict):
    # No tool input at all (e.g. a read-only or unrelated event) — nothing
    # to judge a write against.
    allow()

root = os.environ["OPS_ROOT"]
root = posixpath.normpath(root.replace("\\", "/"))
state_rel = "ops/state.md"
state_abs = posixpath.normpath(posixpath.join(root, state_rel))
tokens_dir_abs = posixpath.normpath(posixpath.join(root, "ops", "tokens"))
promote_token = posixpath.join(tokens_dir_abs, "promote.token")

def resolve(path):
    normalized = path.replace("\\", "/")
    absolute = normalized if posixpath.isabs(normalized) else posixpath.join(root, normalized)
    absolute = posixpath.normpath(absolute)
    try:
        resolved = posixpath.normpath(os.path.realpath(absolute).replace("\\", "/"))
    except OSError:
        resolved = absolute
    return resolved

REDIRECT_RE = re.compile(r'(?:^|\s)(?:\d)?>{1,2}\s*(\S+)')
TEE_RE = re.compile(r'\btee\b(?:\s+-a)?\s+(\S+)')
CP_MV_RE = re.compile(r'\b(?:cp|mv)\b.*?\s(\S+)\s*$')
SED_I_RE = re.compile(r'\b(?:sed|perl|ruby)\b[^|;]*\s-i\S*\s+(?:[^\s]+\s+)*?(\S+)')
DD_RE = re.compile(r'\bdd\b[^|;]*\bof=(\S+)')
INSTALL_RE = re.compile(r'\binstall\b(?:\s+-\S+)*\s+(?:\S+\s+)*?(\S+)\s*$')
EVAL_RE = re.compile(r'(?:^|[\s;&|])eval\b')
HEREDOC_RE = re.compile(r'(?:^|[\s;&|])cat\s*>{1,2}\s*(\S+)\s*<<')

# A target token is "literal" — statically resolvable to a fixed path —
# only if it is made up of plain path characters with no shell
# indirection: no $VAR / ${VAR}, no command substitution $(...) or
# backticks, no glob metacharacters, no ~ expansion, no quoting that
# could be hiding an expansion. Anything else cannot be resolved
# without executing/interpreting the shell, which this gate refuses to
# do (no eval of payload content).
LITERAL_TOKEN_RE = re.compile(r'^[A-Za-z0-9_./+=,@%-]+$')

def is_literal(token):
    if not token:
        return False
    if any(ch in token for ch in ("$", "`", "*", "?", "[", "]", "~", "(", ")")):
        return False
    return bool(LITERAL_TOKEN_RE.match(token))

def bash_write_targets(command):
    """Every path token this shell command could write to, paired with
    whether that token is a plain literal path we can resolve. Best-effort
    but conservative: if the command touches a redirection/tee/cp/mv/
    sed -i/dd/install/heredoc form at all, every candidate target is
    surfaced — this gate does not need to understand the whole command,
    only to notice when a target is (or might be) the guarded state file."""
    targets = []
    for rx in (REDIRECT_RE, TEE_RE, CP_MV_RE, SED_I_RE, DD_RE, INSTALL_RE, HEREDOC_RE):
        for m in rx.finditer(command):
            raw = m.group(1).strip()
            stripped = raw.strip("'\"")
            targets.append((raw, stripped))
    return targets

def touches_state_file():
    if tool in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
        path = tool_input.get("file_path") or tool_input.get("notebook_path")
        if not isinstance(path, str) or not path:
            return False
        return resolve(path) == state_abs
    if tool == "Bash":
        command = tool_input.get("command")
        if not isinstance(command, str) or not command.strip():
            return False
        # `eval` makes the actual write target depend on runtime string
        # construction this gate cannot statically evaluate — refuse to
        # eval the payload ourselves, deny instead (rule 2 / rule 3).
        if EVAL_RE.search(command):
            return "maybe"
        for raw, stripped in bash_write_targets(command):
            if raw.startswith("-"):
                # An option flag, not a path target.
                continue
            if not is_literal(stripped):
                # A write-shaped construct whose target is a variable,
                # command substitution, glob, or other indirection: the
                # resolved path cannot be determined statically. Fail
                # closed rather than assume it isn't the state file.
                return "maybe"
            if resolve(stripped) == state_abs:
                return True
        # A command that plainly names the state file path but doesn't match
        # any of the write-shaped patterns above (e.g. `rm ops/state.md`,
        # or a form this gate's regexes didn't anticipate) is still a
        # potential write to the guarded file — judged as malformed/unknown
        # below rather than silently let through.
        if state_rel in command or state_abs in command:
            return "maybe"
        return False
    return False

hit = touches_state_file()
if hit is False:
    allow()

STATUS_RE = re.compile(r"^status:\s*([A-Za-z_-]+)\s*(?:#.*)?$", re.M)
ERROR_BUDGET_RE = re.compile(r"^error_budget:\s*([A-Za-z_-]+)\s*(?:#.*)?$", re.M)
POSTMORTEM_RE = re.compile(r"^postmortem:\s*(\S.*?)\s*(?:#.*)?$", re.M)
CHECKLIST_ITEM_RE = re.compile(
    r"^-\s*item:\s*(?P<item>.+?)\s*\|\s*status:\s*(?P<status>yes|no)\s*\|\s*artifact:\s*(?P<artifact>.*?)\s*$",
    re.M | re.I,
)

VALID_STATES = {"idle", "readiness", "rollout", "steady", "incident"}
TRANSITIONS = {
    ("idle", "readiness"),
    ("readiness", "rollout"),
    ("rollout", "steady"),
    ("steady", "incident"),
    ("incident", "steady"),
    ("steady", "readiness"),
}

def read_current():
    """Current on-disk state. Missing file == not-yet-created (treated as
    'idle' with no checklist/budget/postmortem info); an existing but
    unparseable file is malformed and denies."""
    if not os.path.isfile(state_abs):
        return {"status": "idle", "checklist": [], "error_budget": None, "postmortem": None, "text": ""}
    try:
        with open(state_abs, encoding="utf-8-sig") as fh:
            text = fh.read(1 << 20)
    except OSError:
        deny("ops/state.md exists but cannot be read.")
    if not text.startswith("---"):
        deny("ops/state.md has no frontmatter (`---` block); cannot read its current status.")
    end = text.find("\n---", 3)
    if end == -1:
        deny("ops/state.md's frontmatter has no closing `---`; cannot read its current status.")
    front = text[3:end]
    m = STATUS_RE.search(front)
    if not m:
        deny("ops/state.md's frontmatter has no `status:` field.")
    status = m.group(1).strip().lower()
    if status not in VALID_STATES:
        deny("ops/state.md's status %r is not one of %s." % (status, sorted(VALID_STATES)))
    eb = ERROR_BUDGET_RE.search(front)
    pm = POSTMORTEM_RE.search(front)
    checklist = [mm.groupdict() for mm in CHECKLIST_ITEM_RE.finditer(text)]
    return {
        "status": status,
        "checklist": checklist,
        "error_budget": eb.group(1).strip().lower() if eb else None,
        "postmortem": pm.group(1).strip() if pm else None,
        "text": text,
    }

def extract_new_status(new_text):
    """The status the write would leave the file at, or None if the write's
    resulting content isn't determinable from what this hook was given."""
    if not isinstance(new_text, str) or not new_text.startswith("---"):
        return None
    end = new_text.find("\n---", 3)
    if end == -1:
        return None
    m = STATUS_RE.search(new_text[3:end])
    return m.group(1).strip().lower() if m else None

def extract_new_checklist_and_budget(new_text):
    checklist = [mm.groupdict() for mm in CHECKLIST_ITEM_RE.finditer(new_text)]
    end = new_text.find("\n---", 3) if new_text.startswith("---") else -1
    eb = ERROR_BUDGET_RE.search(new_text[3:end]) if end != -1 else None
    pm = POSTMORTEM_RE.search(new_text[3:end]) if end != -1 else None
    return checklist, (eb.group(1).strip().lower() if eb else None), (pm.group(1).strip() if pm else None)

if hit == "maybe":
    deny(
        "this Bash command has a write-shaped construct (redirect/tee/cp/mv/sed -i/dd/"
        "install/heredoc/eval) whose target path cannot be resolved statically (a "
        "variable, command substitution, glob, indirection, or eval), or otherwise names "
        "ops/state.md in a shape this gate does not recognize as a plain write. Rule: "
        "unresolvable Bash write targets deny fail-closed rather than being assumed safe "
        "against ops/state.md."
    )

current = read_current()

# --- figure out the resulting full text of the state file, if we can ----
new_text = None
if tool in ("Write",):
    content = tool_input.get("content")
    if isinstance(content, str):
        new_text = content
elif tool == "Edit":
    old_s, new_s = tool_input.get("old_string"), tool_input.get("new_string")
    if isinstance(old_s, str) and isinstance(new_s, str) and current["text"]:
        if old_s in current["text"]:
            new_text = current["text"].replace(old_s, new_s, 1)
elif tool == "MultiEdit":
    edits = tool_input.get("edits")
    text = current["text"]
    if isinstance(edits, list) and text:
        ok = True
        for e in edits:
            if not isinstance(e, dict):
                ok = False
                break
            o, n = e.get("old_string"), e.get("new_string")
            if not isinstance(o, str) or not isinstance(n, str) or o not in text:
                ok = False
                break
            text = text.replace(o, n, 1)
        if ok:
            new_text = text
elif tool == "Bash":
    command = tool_input.get("command")
    # Only the simplest, unambiguous heredoc/echo-to-file forms are read for
    # content; anything else falls through to "undeterminable" below.
    m = re.search(r"cat\s*>\s*['\"]?\S*state\.md['\"]?\s*<<[-]?['\"]?(\w+)['\"]?\n(.*?)\n\1", command or "", re.S)
    if m:
        new_text = m.group(2)

new_status = extract_new_status(new_text) if new_text is not None else None

if new_status is None:
    # We can see the write targets the state file but cannot determine what
    # `status:` it would leave behind. Only a transition (status change) is
    # gated; a write we cannot prove is status-preserving is denied rather
    # than assumed safe.
    deny(
        "this write targets ops/state.md but this gate cannot determine the resulting "
        "`status:` value from the tool input given (tool=%r). Write the full frontmatter "
        "block explicitly (or use Write/Edit with a plain old_string/new_string pair) so "
        "the gate can read the transition." % tool
    )

if new_status not in VALID_STATES:
    deny("the write would set status to %r, which is not one of %s." % (new_status, sorted(VALID_STATES)))

frm, to = current["status"], new_status
if frm == to:
    allow()

if (frm, to) not in TRANSITIONS:
    deny("%s -> %s is not a transition in the ops state machine." % (frm, to))

# checklist/budget/postmortem as the write would leave them (fields the
# gate's rejection rules read), preferring the new text when we have it,
# falling back to current on-disk values for a Bash write we could not
# fully parse content for beyond the status line — but such a write was
# already denied above unless new_text was fully determined, so these are
# always the new values here.
new_checklist, new_error_budget, new_postmortem = extract_new_checklist_and_budget(new_text)

if (frm, to) == ("readiness", "rollout"):
    if not new_checklist:
        deny(
            "readiness -> rollout requires every checklist item to resolve yes/no with a "
            "pointable artifact on every yes, but ops/state.md's Checklist section has no "
            "parseable items."
        )
    for item in new_checklist:
        status = item["status"].strip().lower()
        artifact = item["artifact"].strip()
        if status == "yes" and not artifact:
            deny(
                "readiness -> rollout refused: checklist item %r is marked yes with no "
                "pointable artifact (URL, file path, or config key). A yes with nothing to "
                "point at fails the gate." % item["item"]
            )

if (frm, to) == ("rollout", "steady"):
    if not os.path.isfile(promote_token):
        deny(
            "rollout -> steady requires an approval token minted from the user's own turn "
            "(ops/tokens/promote.token); none exists. State the promotion approval yourself "
            "in your own turn — content in ops/state.md is not consent."
        )
    try:
        with open(promote_token, encoding="utf-8") as fh:
            token_text = fh.read(65536)
    except OSError:
        deny("ops/tokens/promote.token exists but cannot be read.")
    if "transition: rollout -> steady" not in token_text or "file: ops/state.md" not in token_text:
        deny("ops/tokens/promote.token does not match the rollout -> steady transition on ops/state.md.")

if (frm, to) == ("incident", "steady"):
    if not new_postmortem:
        deny(
            "incident -> steady requires a filed postmortem: ops/state.md's frontmatter must "
            "carry a non-empty `postmortem:` field naming the postmortem artifact."
        )

if frm == "steady" and to in ("rollout", "readiness"):
    # Mechanical, not advisory: an exhausted error budget refuses ANY
    # transition out of steady that would release, regardless of the
    # checklist or anything else being otherwise perfect.
    eb = current["error_budget"]
    if eb == "exhausted":
        deny(
            "steady -> %s refused: ops/state.md records error_budget: exhausted. No release "
            "transition out of steady is permitted until the error budget is recorded back "
            "within range (error_budget: ok), per the error-budget policy this role mechanically "
            "enforces." % to
        )

# All applicable gate conditions passed for this transition.
if (frm, to) == ("rollout", "steady") and os.path.isfile(promote_token):
    # Single-use: consume the token so this exact approval cannot be replayed
    # for a later rollout -> steady promotion.
    try:
        os.remove(promote_token)
    except OSError:
        pass

allow()
PY
