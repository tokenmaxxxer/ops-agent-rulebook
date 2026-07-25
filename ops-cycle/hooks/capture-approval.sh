#!/usr/bin/env bash
# UserPromptSubmit hook: mints a single-use approval token for the one
# human-gated transition in the ops role's state machine that requires the
# user's own promotion approval: `rollout -> steady`
# (docs/specs/agent-roles.md, ops: "requires the user's promotion approval,
# in their own turn").
#
# Mirrors qa-agent-rulebook/signoff/hooks/capture-verdict.sh's discipline:
# reads only the literal text of the user's own turn, never a file, issue,
# PR, comment, or tool output; rejects bare assent ("ok", "sounds good");
# never blocks the turn — malformed input, no state file, wrong current
# state, or an ambiguous prompt all mean: mint nothing, exit 0.
#
# Kill switch: export OPS_CAPTURE_DISABLE=1
set -euo pipefail

case "${OPS_CAPTURE_DISABLE:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || exit 0

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

# --- resolve the project root the same way state-gate.sh does -----------
root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$root" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -n "$root" ] || exit 0
[ -d "$root" ] || exit 0
root="$(cd "$root" 2>/dev/null && pwd -P)" || exit 0

state_file="$root/ops/state.md"
[ -f "$state_file" ] || exit 0

tokens_dir="$root/ops/tokens"
mkdir -p "$tokens_dir" 2>/dev/null || exit 0
tokens_dir_real="$(cd "$tokens_dir" 2>/dev/null && pwd -P)" || exit 0
case "$tokens_dir_real" in
  "$root"/ops/tokens) ;;
  *) exit 0 ;;
esac

OPS_PAYLOAD="$payload" OPS_STATE_FILE="$state_file" OPS_TOKENS_DIR="$tokens_dir_real" \
  python3 <<'PY' || true
import json, os, re, sys

try:
    event = json.loads(os.environ.get("OPS_PAYLOAD", ""))
except ValueError:
    sys.exit(0)
if not isinstance(event, dict):
    sys.exit(0)

prompt = event.get("prompt")
if not isinstance(prompt, str) or not prompt.strip():
    sys.exit(0)

state_file = os.environ["OPS_STATE_FILE"]
tokens_dir = os.environ["OPS_TOKENS_DIR"]

STATUS_RE = re.compile(r"^status:\s*([A-Za-z]+)\s*(?:#.*)?$", re.M)

try:
    with open(state_file, encoding="utf-8-sig") as fh:
        text = fh.read(1 << 20)
except OSError:
    sys.exit(0)

if not text.startswith("---"):
    sys.exit(0)
end = text.find("\n---", 3)
if end == -1:
    sys.exit(0)
front = text[3:end]
m = STATUS_RE.search(front)
if not m:
    sys.exit(0)
status = m.group(1).strip().lower()

# Only one human-gated approval this hook mints: rollout -> steady.
if status != "rollout":
    sys.exit(0)

# Reject bare assent, even if a keyword coincidentally appears.
if re.match(r'^\s*(ok|okay|sure|sounds good|yep|yes|k|👍|fine)\s*[.!]?\s*$', prompt, re.I):
    sys.exit(0)

# Require an explicit, unambiguous promotion-approval statement: an
# approval/promotion verb tied explicitly to "steady" (or the equivalent
# "production" / "steady state" wording). A bare "approved" with no target,
# or "approved" applied to something else in the same turn, does not count.
APPROVE_RE = re.compile(
    r'\b(approve|approved|approving|promote|promoting|ship it|go live)\b'
    r'.{0,60}\b(steady( state)?|production|rollout is (done|complete|finished))\b',
    re.I,
)
if not APPROVE_RE.search(prompt):
    ALT_RE = re.compile(
        r'\b(steady( state)?|production)\b.{0,60}\b(approve|approved|approving|promote|promoting)\b',
        re.I,
    )
    if not ALT_RE.search(prompt):
        sys.exit(0)

phrase = prompt.strip().replace("\r", "")[:300]
if re.search(
    r'(api[_-]?key|secret|password|passwd|token=|bearer |authorization:|-----BEGIN |'
    r'https?://[^ ]*@|https?://(localhost|127\.|10\.|192\.168\.|internal[.-]|intranet[.-]))',
    phrase, re.I,
):
    sys.stderr.write(
        "ops-cycle: the wording carrying this approval looks sensitive "
        "(credential/key/internal-URL shaped); minting no token.\n"
    )
    sys.exit(0)

token_path = os.path.join(tokens_dir, "promote.token")
real_tokens_dir = os.path.realpath(tokens_dir)
if os.path.realpath(os.path.dirname(token_path)) != real_tokens_dir:
    sys.exit(0)

tmp = token_path + ".tmp"
esc = phrase.replace("'", "''")
with open(tmp, "w", encoding="utf-8") as fh:
    fh.write("file: ops/state.md\n")
    fh.write("transition: rollout -> steady\n")
    fh.write("phrase: '%s'\n" % esc)
os.replace(tmp, token_path)
sys.exit(0)
PY

exit 0
