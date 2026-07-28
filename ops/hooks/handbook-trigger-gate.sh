#!/usr/bin/env bash
# fail-closed trap: any abort with rc not in {0,2} is forced to DENY (exit 2).
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse hook (Bash matching 'git commit'): enforces contract §21's
# handbook half. When a commit's staged changed-file set introduces or changes
# an operational surface -- an environment variable file, a config key, a
# dependency manifest, a migration, or a run/setup/deploy script -- but the
# same commit does NOT also touch any docs/handbooks/<component>.md, the commit
# is refused. §21 requires the surface-changer to update the component's
# handbook in the SAME unit of work (same-turn-sync).
#
# Fires at commit time (not on Write) because it needs the whole staged
# changed-file set at once. The operational-surface path heuristics below are
# this repo's own declared list, per §21 ("each repo's own hook config declares
# its own list").
#
# FAIL-CLOSED (modeled on state-gate.sh): missing python3, unparseable payload,
# non-dict tool_input, an indeterminate root, or a git command whose staged set
# cannot be read all DENY (exit 2). A Bash call that is not a git commit passes
# through untouched.
set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "ops-cycle: refused -- handbook-trigger-gate.sh requires python3, which is not on PATH; denying rather than guessing." >&2
  exit 2
}
command -v git >/dev/null 2>&1 || {
  echo "ops-cycle: refused -- handbook-trigger-gate.sh requires git, which is not on PATH; denying rather than guessing." >&2
  exit 2
}

payload="$(cat 2>/dev/null || true)"

# Extract the Bash command; if this is not a `git commit`, pass through.
command_str="$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    e = json.loads(sys.stdin.read())
except Exception:
    print("__OPS_MALFORMED__"); sys.exit(0)
if not isinstance(e, dict):
    print("__OPS_MALFORMED__"); sys.exit(0)
ti = e.get("tool_input")
if not isinstance(ti, dict):
    print("__OPS_MALFORMED__"); sys.exit(0)
cmd = ti.get("command")
print(cmd if isinstance(cmd, str) else "")
' 2>/dev/null || printf '__OPS_MALFORMED__')"

if [ "$command_str" = "__OPS_MALFORMED__" ]; then
  echo "ops-cycle: refused -- handbook-trigger-gate.sh could not parse the tool-call payload; it fails closed rather than let an unparseable commit through." >&2
  exit 2
fi

# Only a git commit is this gate's business.
printf '%s' "$command_str" | grep -Eq '(^|[[:space:]&|;(])git([[:space:]]+-[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)' || exit 0

root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "$CLAUDE_PROJECT_DIR" ] \
   && { [ -e "$CLAUDE_PROJECT_DIR/.git" ] || [ -f "$CLAUDE_PROJECT_DIR/docs/specs/role-handoff-contract.md" ]; }; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
if [ -z "$root" ]; then
  root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$root" ]; then
  echo "ops-cycle: refused -- no project root could be determined; the handbook-trigger gate fails closed rather than guess a root for the staged set." >&2
  exit 2
fi

# Read the staged changed-file set. A git error here fails closed.
if ! staged="$(git -C "$root" diff --cached --name-only 2>/dev/null)"; then
  echo "ops-cycle: refused -- could not read the staged changed-file set (git -C '$root' diff --cached failed); the handbook-trigger gate fails closed rather than judge a commit whose contents it cannot see." >&2
  exit 2
fi

rc=0
OPS_STAGED="$staged" python3 <<'PY' || rc=$?
import os, posixpath, re, sys

# fail-closed layer 2 (python): any uncaught exception in the judge becomes a
# DENY (exit 2), never an uncaught exit 1 (fail-open). deny()/allow() use
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

staged = os.environ.get("OPS_STAGED", "")
files = [ln.strip() for ln in staged.splitlines() if ln.strip()]
if not files:
    # Nothing staged: no operational surface change to guard. (An empty commit
    # or a commit staging nothing is not this gate's concern.)
    allow()

# Operational-surface heuristics (this repo's declared list, §21).
MANIFEST_BASENAMES = {
    "package.json", "pyproject.toml", "requirements.txt", "pipfile", "pipfile.lock",
    "go.mod", "go.sum", "cargo.toml", "cargo.lock", "gemfile", "gemfile.lock",
    "pom.xml", "build.gradle", "dockerfile", "package-lock.json", "yarn.lock",
    "poetry.lock",
}
ENV_RE = re.compile(r'(^|/)\.?env(\.[^/]*)?$|\.env(\.example|\.sample|\.template)?$', re.I)
COMPOSE_RE = re.compile(r'(^|/)docker-compose[^/]*\.ya?ml$', re.I)
DEPLOY_SCRIPT_RE = re.compile(r'(^|/)(deploy|setup|install|run|entrypoint|start|bootstrap)[^/]*\.(sh|ps1|bat)$', re.I)
MIGRATION_DIR_RE = re.compile(r'(^|/)(migrations?|migrate|alembic|db/migrate)(/|$)', re.I)
CI_WORKFLOW_RE = re.compile(r'(^|/)\.github/workflows/[^/]+\.ya?ml$', re.I)
K8S_RE = re.compile(r'(^|/)(k8s|kubernetes|helm|charts|deploy)/[^/]+\.(ya?ml|tpl)$', re.I)

def is_operational(p):
    base = posixpath.basename(p).lower()
    if base in MANIFEST_BASENAMES:
        return "dependency-manifest"
    if base == "dockerfile" or base.startswith("dockerfile."):
        return "container-build"
    if ENV_RE.search(p):
        return "environment-variable file"
    if COMPOSE_RE.search(p):
        return "compose/service config"
    if DEPLOY_SCRIPT_RE.search(p):
        return "run/setup/deploy script"
    if MIGRATION_DIR_RE.search(p):
        return "migration"
    if CI_WORKFLOW_RE.search(p):
        return "CI/deploy workflow"
    if K8S_RE.search(p):
        return "deploy manifest"
    return None

op_hits = []
for p in files:
    kind = is_operational(p)
    if kind:
        op_hits.append((p, kind))

if not op_hits:
    allow()

touches_handbook = any(
    p == "docs/handbooks" or p.startswith("docs/handbooks/")
    for p in files
)
if touches_handbook:
    allow()

p, kind = op_hits[0]
deny(
    "this commit changes %s (operational surface: %s) but does not touch any "
    "docs/handbooks/<component>.md. Per contract §21, the role that changes a component's "
    "operational surface must create or update that component's handbook in the same unit "
    "of work (what it is, what it defaults to, what breaks without it, and the commands to "
    "install, run, and operate it). Derive <component> from the surface's owning module/"
    "service and update its handbook in this same commit." % (p, kind)
)
PY
# fail-closed layer 1 (shell): map ANY judge exit that is neither 0 nor 2 to a
# DENY; the `|| rc=$?` guard keeps set -e from aborting on a bare non-2 code.
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  echo "ops-cycle: fail-closed: internal error (handbook-trigger-gate.sh judge exited $rc); denying." >&2
  exit 2
fi
exit "$rc"
