#!/usr/bin/env bash
# PreToolUse hook: enforces the ops role's state machine by asking exactly
# two questions, in this order:
#
#   1. Does this write reach ops/state.md, judged by RESOLVED TARGET PATH —
#      never by a literal filename in the command string, never by tool
#      name. A write that does not reach ops/state.md is none of this
#      gate's business and passes through untouched.
#   2. If it reaches ops/state.md: is the resulting (from, to) transition
#      present as a row in transition-rules.md (the single source of truth,
#      read by this gate and by inject-transition-rules.sh)? Present ->
#      allow. Absent -> deny.
#
# This gate no longer consults approval tokens, checklists, or error
# budgets — those were removed with capture-approval.sh. The only
# enforcement left is table membership; the human-basis record is prose in
# the injected UserPromptSubmit block, not something this gate checks.
#
# Path-resolution regression fix: an unresolvable Bash write target (a
# variable, command substitution, glob, or eval) is only treated as
# "reaches ops/state.md" when it is ALSO write-shaped toward the state
# file's own directory (its resolvable literal prefix falls under
# ops/state.md's directory). An unresolvable target aimed anywhere else
# (e.g. `curl ... > /tmp/evidence-$(date +%s).json`) is not this gate's
# business and passes through — it never reaches ops/state.md.
#
# Two distinct denials, never conflated:
#   - "the transition rules could not be loaded" (transition-rules.md
#     missing/unreadable/empty/unparseable, or the state file's current
#     status cannot be read)
#   - "this transition is not in the table" (rules loaded fine, but
#     (from, to) is not a row)
#
# Malformed hook input (unparseable JSON, missing fields) denies with the
# rules-could-not-be-loaded message — never exits 0 silently on it.
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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

OPS_PAYLOAD="$payload" OPS_ROOT="$root" OPS_RULES_FILE="$script_dir/transition-rules.md" python3 <<'PY'
import json, os, posixpath, re, sys

def deny(msg):
    sys.stderr.write("ops-cycle: refused — " + msg + "\n")
    sys.exit(2)

def deny_rules_unloaded(reason):
    deny("the transition rules could not be loaded (%s); no transition may be made until this is fixed." % reason)

def allow():
    sys.exit(0)

raw = os.environ.get("OPS_PAYLOAD", "")
try:
    event = json.loads(raw) if raw else {}
except ValueError:
    deny_rules_unloaded("the tool-call payload is not valid JSON")
if not isinstance(event, dict):
    deny_rules_unloaded("the tool-call payload is not a JSON object")

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
state_dir = posixpath.dirname(state_abs)

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
# backticks, no glob metacharacters, no ~ expansion. Anything else cannot
# be resolved without executing/interpreting the shell, which this gate
# refuses to do (no eval of payload content).
LITERAL_TOKEN_RE = re.compile(r'^[A-Za-z0-9_./+=,@%-]+$')

def is_literal(token):
    if not token:
        return False
    if any(ch in token for ch in ("$", "`", "*", "?", "[", "]", "~", "(", ")")):
        return False
    return bool(LITERAL_TOKEN_RE.match(token))

LITERAL_PREFIX_RE = re.compile(r'^[A-Za-z0-9_./+=,@%-]*')

def aimed_at_state_dir(token):
    """True only when the resolvable literal PREFIX of an otherwise
    unresolvable token places it under ops/state.md's own directory. A
    token with no literal prefix at all (e.g. a bare $VAR) carries no
    evidence either way and is NOT treated as aimed at the state file —
    this is the regression fix: unresolvable targets elsewhere (e.g.
    /tmp/evidence-$(date +%s).json) are not this gate's business."""
    prefix = LITERAL_PREFIX_RE.match(token).group(0)
    if not prefix:
        return False
    joined = prefix if posixpath.isabs(prefix) else posixpath.join(root, prefix)
    norm = posixpath.normpath(joined)
    return norm == state_abs or norm == state_dir or norm.startswith(state_dir + "/")

def bash_write_targets(command):
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

        for raw, stripped in bash_write_targets(command):
            if raw.startswith("-"):
                continue
            if is_literal(stripped):
                if resolve(stripped) == state_abs:
                    return True
                continue
            # Unresolvable target: only the gate's business if it is
            # write-shaped toward the state file's own directory.
            if aimed_at_state_dir(stripped):
                return "maybe"

        # `eval` makes the actual write target depend on runtime string
        # construction this gate cannot statically evaluate. Only escalate
        # to "maybe" if the command's literal text otherwise names the
        # state file/directory — an eval unrelated to ops/state.md is not
        # this gate's business.
        if EVAL_RE.search(command) and (state_rel in command or state_abs in command):
            return "maybe"

        # A command that plainly names the state file path but doesn't match
        # any write-shaped pattern above (e.g. `rm ops/state.md`) is still a
        # potential write to the guarded file.
        if state_rel in command or state_abs in command:
            return "maybe"

        return False
    return False

hit = touches_state_file()
if hit is False:
    allow()

STATUS_RE = re.compile(r"^status:\s*([^\r\n#]*?)\s*(?:#.*)?$", re.M)

def read_current_status(known_states):
    """Current on-disk status, derived from FILE EXISTENCE ALONE — never
    from comparing a parsed value against the `(none)` string. Only a
    genuinely absent file yields the synthetic `(none)` old state used for
    bootstrap-row matching.

    If the file EXISTS, its parsed status must be a member of
    `known_states` (trailing whitespace/CRLF stripped first; whitespace-only
    counts as empty). `(none)` as the on-disk value, an empty value, a
    missing `status:` field, and any value outside `known_states` are all
    the same case: the gate cannot establish its own input, so this denies
    with the rules-could-not-be-loaded message — never with the
    transition-not-in-the-table message."""
    if not os.path.isfile(state_abs):
        return "(none)"
    try:
        with open(state_abs, encoding="utf-8-sig") as fh:
            text = fh.read(1 << 20)
    except OSError:
        deny_rules_unloaded("ops/state.md exists but cannot be read")
    if not text.startswith("---"):
        deny_rules_unloaded("ops/state.md has no frontmatter (`---` block)")
    end = text.find("\n---", 3)
    if end == -1:
        deny_rules_unloaded("ops/state.md's frontmatter has no closing `---`")
    m = STATUS_RE.search(text[3:end])
    if not m:
        deny_rules_unloaded("ops/state.md's frontmatter has no `status:` field")
    value = m.group(1).strip("\r\n \t").strip().lower()
    if not value or value not in known_states:
        deny_rules_unloaded(
            "ops/state.md's `status:` value (%r) is `(none)`, empty, or not a member of "
            "this role's known-state set — the gate cannot establish its own input" % value
        )
    return value

def extract_new_status(new_text):
    if not isinstance(new_text, str) or not new_text.startswith("---"):
        return None
    end = new_text.find("\n---", 3)
    if end == -1:
        return None
    m = STATUS_RE.search(new_text[3:end])
    return m.group(1).strip().lower() if m else None

if hit == "maybe":
    deny(
        "this Bash command has a write-shaped construct (redirect/tee/cp/mv/sed -i/dd/"
        "install/heredoc/eval) whose target cannot be resolved statically but is aimed "
        "at ops/state.md's own directory, or otherwise names ops/state.md in a shape "
        "this gate does not recognize as a plain write. Rule: an unresolvable Bash write "
        "target aimed at the state file's directory denies fail-closed rather than being "
        "assumed safe."
    )

# --- load transition-rules.md: the single source of truth for legality --
rules_path = os.environ.get("OPS_RULES_FILE", "")

def load_rules(path):
    if not path or not os.path.isfile(path):
        return None
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read(1 << 20)
    except OSError:
        return None
    rows = set()
    for line in text.splitlines():
        line = line.strip()
        if "|" not in line:
            continue
        if line.lower().startswith("from") or set(line.replace("|", "").strip()) <= {"-"}:
            continue
        parts = [p.strip() for p in line.strip("|").split("|")]
        if len(parts) < 2:
            continue
        f, t = parts[0].lower(), parts[1].lower()
        if not f or not t:
            continue
        rows.add((f, t))
    return rows if rows else None

rules = load_rules(rules_path)
if rules is None:
    deny_rules_unloaded("transition-rules.md at %r is missing, unreadable, empty, or has no parseable rows" % rules_path)

# Known-state set: every `from`/`to` value appearing in the table, minus the
# synthetic `(none)` bootstrap sentinel. Used to validate an EXISTING state
# file's status value (never used to invent a status for an absent file).
known_states = {s for pair in rules for s in pair if s != "(none)"}

current_status = read_current_status(known_states)

# --- figure out the resulting full text of the state file, if we can ----
new_text = None
current_text = None
if os.path.isfile(state_abs):
    try:
        with open(state_abs, encoding="utf-8-sig") as fh:
            current_text = fh.read(1 << 20)
    except OSError:
        current_text = None

if tool == "Write":
    content = tool_input.get("content")
    if isinstance(content, str):
        new_text = content
elif tool == "Edit":
    old_s, new_s = tool_input.get("old_string"), tool_input.get("new_string")
    if isinstance(old_s, str) and isinstance(new_s, str) and current_text:
        if old_s in current_text:
            new_text = current_text.replace(old_s, new_s, 1)
elif tool == "MultiEdit":
    edits = tool_input.get("edits")
    text = current_text
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
    m = re.search(r"cat\s*>\s*['\"]?\S*state\.md['\"]?\s*<<[-]?['\"]?(\w+)['\"]?\n(.*?)\n\1", command or "", re.S)
    if m:
        new_text = m.group(2)

new_status = extract_new_status(new_text) if new_text is not None else None

if new_status is None:
    deny(
        "this write targets ops/state.md but this gate cannot determine the resulting "
        "`status:` value from the tool input given (tool=%r). Write the full frontmatter "
        "block explicitly (or use Write/Edit with a plain old_string/new_string pair) so "
        "the gate can read the transition." % tool
    )

frm, to = current_status, new_status

if (frm, to) not in rules:
    deny("%s -> %s is not a row in transition-rules.md (this transition is not in the table)." % (frm, to))

allow()
PY
