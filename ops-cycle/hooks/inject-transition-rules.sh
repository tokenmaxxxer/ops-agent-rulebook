#!/usr/bin/env bash
# UserPromptSubmit hook: injects the ops role's current state and its legal
# next transitions (read from transition-rules.md, the same single source
# of truth state-gate.sh enforces) into context on every user turn.
#
# THE CRITICAL RULE: this hook must NEVER exit silently with no output. If
# transition-rules.md is missing/unreadable/empty/unparseable, or the state
# file is missing/unparseable, it still emits a block — one that says
# plainly the rules could not be loaded and why, and that no transition may
# be made until that is fixed. Always exit 0 (never block the prompt), but
# never exit empty.
set -uo pipefail

root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$root" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$root" ] || [ ! -d "$root" ]; then
  root="$(pwd -P)"
fi
root="$(cd "$root" 2>/dev/null && pwd -P)" || root="$(pwd -P)"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if ! command -v python3 >/dev/null 2>&1; then
  cat <<'EOF'
## ops-cycle transition rules — COULD NOT BE LOADED

python3 is not on PATH, so this hook cannot parse transition-rules.md or
ops/state.md. No transition may be made until this is fixed.
EOF
  exit 0
fi

OPS_ROOT="$root" OPS_RULES_FILE="$script_dir/transition-rules.md" python3 <<'PY'
import os, posixpath, re

root = os.environ["OPS_ROOT"]
rules_path = os.environ.get("OPS_RULES_FILE", "")
state_abs = posixpath.normpath(posixpath.join(root.replace("\\", "/"), "ops", "state.md"))

STATUS_RE = re.compile(r"^status:\s*([^\r\n#]*?)\s*(?:#.*)?$", re.M)

def fail(reason):
    print("## ops-cycle transition rules — COULD NOT BE LOADED")
    print()
    print("Reason: %s." % reason)
    print()
    print("No transition may be made until this is fixed.")

def load_rules(path):
    if not path or not os.path.isfile(path):
        return None, "transition-rules.md not found at %r" % path
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read(1 << 20)
    except OSError as e:
        return None, "transition-rules.md could not be read (%s)" % e
    rows = []
    for line in text.splitlines():
        line = line.strip()
        if "|" not in line:
            continue
        if line.lower().startswith("from") or set(line.replace("|", "").strip()) <= {"-"}:
            continue
        parts = [p.strip() for p in line.strip("|").split("|")]
        if len(parts) < 4:
            continue
        frm, to, actor, precond = parts[0], parts[1], parts[2], parts[3]
        if not frm or not to:
            continue
        rows.append((frm, to, actor, precond))
    if not rows:
        return None, "transition-rules.md has no parseable rows"
    return rows, None

def read_status(known_states):
    """Current state, derived from FILE EXISTENCE ALONE — never by comparing
    the parsed value against the `(none)` string. A missing state file is
    the synthetic state `(none)` — a normal, renderable state, NOT the
    "rules could not be loaded" condition.

    If the file EXISTS, its status must be a member of `known_states`
    (trailing whitespace/CRLF stripped; whitespace-only counts as empty).
    `(none)` as the on-disk value, an empty value, a missing/duplicated
    `status:` field, and any value outside `known_states` are all the same
    broken-input case — this is the failure block already reserved for a
    broken table or broken state field, and it must agree with the gate: a
    state the gate refuses to leave is never rendered here as legitimate."""
    if not os.path.isfile(state_abs):
        return "(none)", None
    try:
        with open(state_abs, encoding="utf-8-sig") as fh:
            text = fh.read(1 << 20)
    except OSError as e:
        return None, "ops/state.md could not be read (%s)" % e
    if not text.startswith("---"):
        return None, "ops/state.md has no frontmatter (`---` block)"
    end = text.find("\n---", 3)
    if end == -1:
        return None, "ops/state.md's frontmatter has no closing `---`"
    front = text[3:end]
    matches = STATUS_RE.findall(front)
    if not matches:
        return None, "ops/state.md's frontmatter has no `status:` field"
    if len(matches) > 1:
        return None, "ops/state.md's frontmatter has a duplicated `status:` field"
    value = matches[0].strip("\r\n \t").strip().lower()
    if not value or value not in known_states:
        return None, (
            "ops/state.md's `status:` value (%r) is `(none)`, empty, or not a member "
            "of this role's known-state set" % value
        )
    return value, None

rows, rules_err = load_rules(rules_path)
known_states = {r[0].lower() for r in (rows or [])} | {r[1].lower() for r in (rows or [])}
known_states.discard("(none)")
status, status_err = read_status(known_states)

if rules_err or status_err:
    reasons = [r for r in (rules_err, status_err) if r]
    fail("; and ".join(reasons))
else:
    applicable = [r for r in rows if r[0].lower() == status.lower()]
    print("## ops-cycle transition rules")
    print()
    print("Current state: `%s`" % status)
    print()
    if not applicable:
        print("No legal transitions out of `%s` are listed in transition-rules.md." % status)
    else:
        print("| condition (precondition) | allowed transition | actor |")
        print("|---|---|---|")
        for frm, to, actor, precond in applicable:
            print("| %s | %s -> %s | %s |" % (precond, frm, to, actor))
    print()
    print(
        "A row with actor `user` may only be taken if the user has actually said "
        "something in this conversation establishing its precondition — the model must "
        "record, as a line appended to ops/state.md, the user utterance it read as the "
        "basis for that transition. This is not enforced by the gate; it is the model's "
        "obligation."
    )
PY
