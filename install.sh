#!/usr/bin/env bash
# One-shot installer for the tokenmaxxxer ops stack.
# Registers ONLY the tokenmaxxxer-ops marketplace, installs ONLY this
# repository's plugins (ops) plus its bundle (ops), at
# user scope. Names no other repository or marketplace.
#
# Installs for your account only (user scope). Uses a real `claude` CLI
# (standalone, or the binary bundled inside the VSCode extension) at
# --scope user, or falls back to writing ~/.claude/settings.json directly.
# Applies on every machine-local session but does NOT travel with any repo.
set -euo pipefail

MARKET="tokenmaxxxer-ops"
BUNDLE="ops"
GITHUB_REPO="tokenmaxxxer/ops-agent-rulebook"

usage() {
  cat <<'USAGE'
Usage: install.sh

  Installs the tokenmaxxxer ops stack for your account only. Applies to
  every machine-local session but does not travel with any repo, and does
  not reach Claude Code on the web / Slack cloud sessions.
  -h, --help  Show this help.

Environment:
  TOKENMAXXXER_SETTINGS_ONLY=1      Skip the CLI and write settings directly.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    *) echo "install.sh: unknown argument '$1'" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

MARKET_SOURCE="$GITHUB_REPO"
SETTINGS_SOURCE_JSON="{\"source\": \"github\", \"repo\": \"$GITHUB_REPO\"}"

# Merge extraKnownMarketplaces + enabledPlugins into a settings.json at $1,
# preserving any existing content. Used for the CLI-less fallback.
write_settings() {
  python3 - "$MARKET" "$BUNDLE" "$SETTINGS_SOURCE_JSON" "$1" <<'PY'
import json, os, shutil, sys

market, bundle, source_json, path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
key = f"{bundle}@{market}"
path = os.path.expanduser(path)

home = os.path.realpath(os.path.expanduser("~"))
target_dir = os.path.realpath(os.path.dirname(path) or ".")
if target_dir != home and not target_dir.startswith(home + os.sep):
    sys.exit(f"ERROR: refusing to write outside $HOME: {path}")

os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
# A dotfiles setup often symlinks this file. os.replace() below would swap the
# link for a regular file and quietly detach the user's real settings, so write
# through to whatever it points at.
if os.path.islink(path):
    path = os.path.realpath(path)
    print(f"    settings.json is a symlink; writing through to {path}")

settings = {}
if os.path.exists(path):
    with open(path) as f:
        try:
            settings = json.load(f)
        except ValueError:
            sys.exit(f"ERROR: {path} is not valid JSON — fix it and re-run. Nothing was written.")
    shutil.copy2(path, path + ".bak")
    print(f"    backup written to {path}.bak")

settings.setdefault("extraKnownMarketplaces", {})[market] = {
    "source": json.loads(source_json)
}

# enabledPlugins is a record ({"plugin@market": true}), not an array.
enabled = settings.get("enabledPlugins")
if isinstance(enabled, list):
    enabled = {k: True for k in enabled}
elif not isinstance(enabled, dict):
    enabled = {}
enabled[key] = True
settings["enabledPlugins"] = enabled

tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, path)
print(f"    updated {path}")
PY
}

find_cli() {
  if command -v claude >/dev/null 2>&1; then
    command -v claude
    return
  fi
  # The VSCode extension bundles a full CLI; pick the newest version.
  ls -1d "$HOME"/.vscode-server/extensions/anthropic.claude-code-*/resources/native-binary/claude \
         "$HOME"/.vscode/extensions/anthropic.claude-code-*/resources/native-binary/claude \
         2>/dev/null | sort -V | tail -1
}

CLI=""
[ -z "${TOKENMAXXXER_SETTINGS_ONLY:-}" ] && CLI="$(find_cli)"

if [ -n "$CLI" ] && [ -x "$CLI" ]; then
  echo "==> installing via CLI: $CLI"
  # Run the CLI from a scratch dir, never the invoking repo. `claude plugin
  # marketplace add` keys its write scope on the current directory, so run
  # inside a repo that declares the marketplace it would pin entries into that
  # repo's tracked .claude/settings.json. A neutral cwd keeps every write at
  # user scope. (The write_settings fallback below uses an absolute $HOME
  # path and is unaffected by cwd.)
  cd "$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}")" 2>/dev/null || cd / || true
  if "$CLI" plugin marketplace list 2>/dev/null | grep -q "$MARKET"; then
    echo "    marketplace '$MARKET' already registered"
  else
    "$CLI" plugin marketplace add "$MARKET_SOURCE"
  fi
  "$CLI" plugin marketplace update "$MARKET" >/dev/null 2>&1 || true
  # Install this repository's role plugin explicitly, then the bundle. The
  # CLI does not auto-install a dependency ADDED to an already-installed
  # bundle, so relying on bundle-side resolution breaks upgrades; explicit
  # installs are idempotent and make "re-run the installer" the fix for
  # every dependency error.
  install_failed=""
  for plugin in ops; do
    "$CLI" plugin install "$plugin@$MARKET" --scope user || install_failed="$install_failed $plugin"
  done
  "$CLI" plugin install "$BUNDLE@$MARKET" --scope user || install_failed="$install_failed $BUNDLE"
  # Then update each to the marketplace's latest. `install` on an already-present
  # plugin may no-op, so after the marketplace refresh an explicit `update` is
  # what actually pulls a newer version.
  for plugin in ops; do
    "$CLI" plugin update "$plugin@$MARKET" || true
  done
  "$CLI" plugin update "$BUNDLE@$MARKET" || true
  if [ -n "$install_failed" ]; then
    echo "==> FAILED to install:$install_failed"
    echo "    The rest of the stack is installed. Re-run this script — it is idempotent —"
    echo "    or install the failures individually with: $CLI plugin install <name>@$MARKET --scope user"
  else
    echo "==> installed $BUNDLE@$MARKET and the ops stack."
  fi
else
  echo "==> no claude CLI found (standalone or bundled): writing user settings directly"
  # Fail loudly rather than falling through to the "done" banner: write_settings
  # exits non-zero when ~/.claude/settings.json exists but is not valid JSON, and
  # nothing was written in that case.
  if ! write_settings "$HOME/.claude/settings.json"; then
    echo "==> FAILED to write ~/.claude/settings.json (see the error above); nothing was installed." >&2
    exit 1
  fi
  echo "    the bundle and its dependency install on next session start"
fi

cat <<'MSG'
==> done (user scope). Start (or reload) a Claude Code session, then:
    - verify with /plugins
    - RECOMMENDED: open /plugin -> marketplaces -> tokenmaxxxer-ops and enable
      auto-update, so future stack additions arrive automatically. There is
      no CLI/config switch for this toggle; it is a one-time interactive step.
    - without auto-update, refresh manually anytime:
      claude plugin update ops@tokenmaxxxer-ops
MSG
