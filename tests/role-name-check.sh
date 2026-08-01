#!/usr/bin/env bash
# Hard-fails if the old `ops` brand names regress back into README.md or
# any .claude-plugin manifest (issue-39: "옛 이름은 하드 에러"). Scoped
# strictly to the three literal old-brand tokens — `ops-agent`,
# `tokenmaxxxer-ops`, `ops-cycle` — never to the `ops/` directory name
# itself, `ops/state.md`-family paths, or generic prose use of "ops" as
# the SRE-domain word, all of which are legitimate and excluded by
# construction: this check only greps README.md and .claude-plugin's own
# JSON manifests, never the `ops/` directory's own file contents.
#
# Usage: role-name-check.sh
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
rc=0

targets=("$repo_root/README.md")
while IFS= read -r f; do
  targets+=("$f")
done < <(find "$repo_root/.claude-plugin" -type f -name '*.json' 2>/dev/null)

for t in "${targets[@]}"; do
  [ -f "$t" ] || continue
  hits="$(grep -noE 'ops-agent|tokenmaxxxer-ops|ops-cycle' "$t" 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    echo "role-name-check: FAIL — old-brand token found in $t:" >&2
    printf '%s\n' "$hits" >&2
    rc=1
  fi
done

if [ "$rc" = 0 ]; then
  echo "role-name-check: ok — no ops-agent/tokenmaxxxer-ops/ops-cycle tokens in README.md or .claude-plugin/**/*.json"
fi

exit "$rc"
