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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# Root resolution (frozen contract:
# docs/proposals/2026-07-26-gate-root-from-project-dir.md): candidate root =
# CLAUDE_PROJECT_DIR when set, but only trusted once validated — (a) the
# tool call's actual target resolves inside it, and (b) it looks like a real
# project root (git work-tree top-level, or docs/specs/role-handoff-contract.md
# present). An unset or invalid candidate falls back to the git top-level of
# the tool call's target path, then the git top-level of cwd. A root that
# remains indeterminate is refused outright — never silently allowed,
# including for writes into the owned record tree.
_gate_target="$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    e = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
ti = e.get("tool_input") if isinstance(e, dict) else None
if isinstance(ti, dict):
    fp = ti.get("file_path")
    if isinstance(fp, str) and fp:
        print(fp)
' 2>/dev/null || true)"

_gate_is_plausible_root() {
  [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }
}

_gate_target_under_root() {
  [ -z "$2" ] && return 0
  python3 -c '
import os, posixpath, sys
root, target = sys.argv[1], sys.argv[2]
try:
    root_real = posixpath.normpath(os.path.realpath(root).replace("\\", "/"))
except Exception:
    sys.exit(1)
norm = target.replace("\\", "/")
absu = norm if posixpath.isabs(norm) else posixpath.join(root_real, norm)
absu = posixpath.normpath(absu)
real = posixpath.normpath(os.path.realpath(absu).replace("\\", "/"))
sys.exit(0 if (real == root_real or real.startswith(root_real + "/")) else 1)
' "$1" "$2"
}

root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _gate_is_plausible_root "$CLAUDE_PROJECT_DIR" && _gate_target_under_root "$CLAUDE_PROJECT_DIR" "$_gate_target"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
if [ -z "$root" ]; then
  _gate_fallback_dir="$_gate_target"
  [ -n "$_gate_fallback_dir" ] || _gate_fallback_dir="$(pwd -P)"
  [ -d "$_gate_fallback_dir" ] || _gate_fallback_dir="$(dirname "$_gate_fallback_dir")"
  root="$(git -C "$_gate_fallback_dir" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$root" ]; then
  root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$root" ]; then
  echo "ops-cycle: refused — no project root could be determined (CLAUDE_PROJECT_DIR unset or failed validation, and no git top-level found for the tool call's target or for cwd); no transition may be made until this is fixed." >&2
  exit 2
fi

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
    # Malformed/absent tool_input: this gate cannot establish what the
    # event is even asking, so it FAILS CLOSED — never allow() on input it
    # cannot understand. Matches the five sibling gates and this header's
    # own stated fail-closed behavior.
    deny_rules_unloaded("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse")

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
# write-through-another-tool: e.g. `python3 -c "open(path,
# 'w').write(...)"`. Judged by RESOLVED TARGET PATH like every other idiom
# above, not by which tool performs the write.
PY_OPEN_WRITE_RE = re.compile(r'\bopen\s*\([^)]*,\s*[\'"][wxa][^\'"]*[\'"]')
PY_OPEN_LITERAL_RE = re.compile(r"\bopen\s*\(\s*['\"]([^'\"]*)['\"]\s*,\s*['\"][wxa]")

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
    for rx in (REDIRECT_RE, TEE_RE, CP_MV_RE, SED_I_RE, DD_RE, INSTALL_RE, HEREDOC_RE, PY_OPEN_LITERAL_RE):
        for m in rx.finditer(command):
            raw = m.group(1).strip()
            stripped = raw.strip("'\"")
            targets.append((raw, stripped))
    return targets

# --- §11 subject-scoped owned-path check -------------------------------
# Under contract-v2 the blackboard lives at
# docs/reports/records/<subject>/<role>.md. This role (ops) owns only its
# own <subject>/ops.md file; writing another role's file under the same
# subject is refused, citing §11 — mirroring the qa/product gates' shape.
RECORDS_RE = re.compile(r'^docs/reports/records/([^/]+)/([^/]+\.md)$')
OWN_ROLE_FILE = "ops.md"

def check_owned_path(path_str):
    resolved = resolve(path_str)
    if not (resolved == root or resolved.startswith(root + "/")):
        return
    rel = resolved[len(root):].lstrip("/")
    m = RECORDS_RE.match(rel)
    if not m:
        return
    subject, role_file = m.group(1), m.group(2)
    if role_file != OWN_ROLE_FILE:
        deny(
            "this write targets %s, which under docs/reports/records/<subject>/ is "
            "another role's owned record file (ops owns only <subject>/%s). §11 "
            "subject-scoped ownership forbids one role writing another role's file."
            % (rel, OWN_ROLE_FILE)
        )

def owned_path_write_targets():
    targets = []
    if tool in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
        path = tool_input.get("file_path") or tool_input.get("notebook_path")
        if isinstance(path, str) and path:
            targets.append(path)
    elif tool == "Bash":
        command = tool_input.get("command")
        if isinstance(command, str) and command.strip():
            for raw, stripped in bash_write_targets(command):
                if raw.startswith("-"):
                    continue
                if is_literal(stripped):
                    targets.append(stripped)
    return targets

for _owned_target in owned_path_write_targets():
    check_owned_path(_owned_target)

# --- path-reference default-deny (frozen contract) --------------------
# docs/proposals/2026-07-26-gate-nested-shell-default-deny.md: for a Bash
# call, default-deny whenever the command TEXT references any path inside
# the owned record tree docs/reports/records/<subject>/ (own or another
# role's), unless the reference is PROVABLY READ-ONLY: only read-type
# commands touch it, no nested-shell invocation (sh -c/bash -c/eval/
# env ... sh/xargs), no command substitution ($( )/backticks), and no
# write idiom anywhere in the command (>, >>, tee, dd of=,
# open(...,'w'/'x'/'a', .write(, .write_text(, .write_bytes(, os.write().
# This does not depend on enumerating write idioms — failing the
# read-only proof is itself the denial trigger, so any un-enumerated
# idiom is still caught by the same rule. A single, sufficient exemption:
# every write-idiom target this gate can statically extract (plain
# redirect, literal open(...,'w'), literal
# Path(...).write_text/write_bytes) resolves to ops's OWN record, with no
# nested shell/command substitution/tee/dd/os.write — the "own-record
# legal write" case already governed by check_owned_path above and the
# transition-table check below.
if tool == "Bash":
    _prdd_cmd = tool_input.get("command")
    _PRDD_TREE_RE = re.compile(r'docs/reports/records/[^\s"\'`)]*')
    _PRDD_NESTED_SHELL_RE = re.compile(
        r'\b(?:sh|bash|zsh|ksh|dash)\s+-c\b|\beval\b|\bxargs\b|'
        r'\benv\b[^\n;&|]*\b(?:sh|bash|zsh|ksh|dash)\b'
    )
    _PRDD_CMD_SUBST_RE = re.compile(r'\$\(|`')
    _PRDD_WRITE_IDIOM_RE = re.compile(
        r'(?:^|[\s;&|])\d?>{1,2}(?!\&)|\btee\b|\bdd\b[^\n;&|]*\bof=|'
        r'\bopen\s*\([^)]*,\s*[\'"][wxa]|'
        r'\.write_text\s*\(|\.write_bytes\s*\(|\.write\s*\(|\bos\.write\s*\('
    )
    _PRDD_OPEN_ANY_RE = re.compile(r"\bopen\s*\([^)]*,\s*['\"][wxa]")
    _PRDD_OPEN_LITERAL_RE2 = re.compile(r"\bopen\s*\(\s*(['\"])(.*?)\1\s*,\s*(['\"])[wxa]")
    _PRDD_WT_ANY_RE = re.compile(r"\.\s*write_(?:text|bytes)\s*\(")
    _PRDD_WT_LITERAL_RE = re.compile(r"\(\s*(['\"])(.*?)\1\s*\)\s*\.\s*write_(?:text|bytes)\s*\(")
    _PRDD_REDIRECT_RE = re.compile(r"(?:^|[\s;&|])\d?(>>|>\|?)(?!\&)\s*(\S+)")
    _PRDD_READ_WHITELIST = {
        "cat", "grep", "egrep", "fgrep", "head", "tail", "test", "[", "ls",
        "wc", "find", "stat", "diff", "file", "less", "more", "readlink",
        "realpath", "md5sum", "sha1sum", "sha256sum", "basename", "dirname",
        "true", "echo", "pwd",
    }

    def _prdd_leading_tokens(cmd):
        leads = []
        for seg in re.split(r'[;&|\n]+', cmd):
            toks = seg.split()
            i = 0
            while i < len(toks) and (
                re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', toks[i]) or toks[i] in ("sudo", "env")
            ):
                i += 1
            if i < len(toks):
                leads.append(posixpath.basename(toks[i].strip("'\"")))
        return leads

    if isinstance(_prdd_cmd, str) and _prdd_cmd and _PRDD_TREE_RE.search(_prdd_cmd):
        _prdd_disqualified = (
            bool(_PRDD_NESTED_SHELL_RE.search(_prdd_cmd))
            or bool(_PRDD_CMD_SUBST_RE.search(_prdd_cmd))
            or bool(re.search(r'\btee\b|\bdd\b[^\n;&|]*\bof=|\bos\.write\s*\(', _prdd_cmd))
        )
        if _PRDD_OPEN_ANY_RE.search(_prdd_cmd) and not _PRDD_OPEN_LITERAL_RE2.search(_prdd_cmd):
            _prdd_disqualified = True
        if _PRDD_WT_ANY_RE.search(_prdd_cmd) and not _PRDD_WT_LITERAL_RE.search(_prdd_cmd):
            _prdd_disqualified = True

        _prdd_targets = []
        for _rm in _PRDD_REDIRECT_RE.finditer(_prdd_cmd):
            _tok = _rm.group(2)
            if len(_tok) >= 2 and _tok[0] == _tok[-1] and _tok[0] in "\"'":
                _tok = _tok[1:-1]
            if not _tok.startswith("&"):
                _prdd_targets.append(_tok)
        for _om in _PRDD_OPEN_LITERAL_RE2.finditer(_prdd_cmd):
            _prdd_targets.append(_om.group(2))
        for _wm in _PRDD_WT_LITERAL_RE.finditer(_prdd_cmd):
            _prdd_targets.append(_wm.group(2))

        _prdd_plain_own_redirect_only = False
        if _prdd_targets and not _prdd_disqualified:
            _prdd_ok = True
            for _tok in _prdd_targets:
                if not _tok or re.search(r"[$`*?\[\]{}~]", _tok):
                    _prdd_ok = False
                    break
                _resolved_tok = resolve(_tok)
                _rel_tok = None
                if _resolved_tok == root or _resolved_tok.startswith(root + "/"):
                    _rel_tok = _resolved_tok[len(root):].lstrip("/")
                _m_tok = RECORDS_RE.match(_rel_tok) if _rel_tok is not None else None
                _is_own = bool(_m_tok) and _m_tok.group(2) == OWN_ROLE_FILE
                if not _is_own:
                    _prdd_ok = False
                    break
            _prdd_plain_own_redirect_only = _prdd_ok

        if not _prdd_plain_own_redirect_only:
            _prdd_proven_read_only = (
                not _PRDD_NESTED_SHELL_RE.search(_prdd_cmd)
                and not _PRDD_CMD_SUBST_RE.search(_prdd_cmd)
                and not _PRDD_WRITE_IDIOM_RE.search(_prdd_cmd)
                and all(t in _PRDD_READ_WHITELIST for t in _prdd_leading_tokens(_prdd_cmd))
            )
            if not _prdd_proven_read_only:
                deny(
                    "path-reference default-deny: this Bash command references the owned "
                    "record tree (docs/reports/records/) and this gate could not prove the "
                    "reference is read-only (no nested shell, no command substitution, no "
                    "write idiom, only read-type commands touching the path). Per the frozen "
                    "path-reference default-deny contract "
                    "(docs/proposals/2026-07-26-gate-nested-shell-default-deny.md), an "
                    "unproven reference into the owned record tree is refused rather than "
                    "allowed through."
                )

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

# --- repo-local collaboration contract: this gate resolves exactly one --
# --- root — this repo's own git root — and reads
# --- docs/specs/role-handoff-contract.md inside it, and nowhere else. No
# --- parent/sibling-repo lookup, no SHA pin against any other repo's
# --- history: no external original exists for this contract to be pinned
# --- against, so the pin concept is void. Absence of the contract file is
# --- an honest refusal, not a silent pass. -------------------------------
contract_path = posixpath.join(root, "docs/specs/role-handoff-contract.md")
if not os.path.isfile(contract_path):
    deny("this repo has no collaboration contract yet.")

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
