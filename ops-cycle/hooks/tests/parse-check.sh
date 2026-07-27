#!/usr/bin/env bash
# Parses every shell hook under a directory with bash 3.2 — the /bin/bash that
# every macOS ships, and therefore the interpreter these hooks actually run
# under for most users.
#
# Guards one specific failure. A quoted-delimiter heredoc nested inside
# `$( … )` is NOT literal to bash 3.2's parser: it keeps tracking quotes and
# parentheses inside the body while it looks for the closing paren. One
# apostrophe in an English possessive — "the gate's own sentinel" — or one
# unbalanced `(` in a comment is enough to make the whole file fail to parse.
#
# The consequence depends on the hook's event, and neither shape announces
# itself:
#   UserPromptSubmit  every prompt for this role is blocked
#   PreToolUse        the gate cannot run; whether that fails open or closed
#                     depends on an exit code the shell never reaches
#   SessionStart      the hook never runs and says nothing, which is
#                     indistinguishable from "nothing to report"
#
# Measured twice. review found it in 2026-07-26 and fixed it. verify carried
# the same broken shape until 2026-07-27, when a session answered
# `UserPromptSubmit operation blocked by hook` and nothing else — the verify
# role had been unusable on macOS, silently, because the regression test lived
# in only one of the two repositories. That is why this file is distributed to
# every rulebook the way deny-only-check.sh is.
#
# bash 5 (Homebrew, most Linux CI) parses all of it happily, which is why this
# pins /bin/bash rather than using $BASH: run under bash 5 it still passes
# every file and simply cannot see the defect.
#
# Usage: parse-check.sh [hooks-dir]
set -uo pipefail

BASH32="${PARSE_CHECK_BASH:-/bin/bash}"
dir="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P)}"
[ -d "$dir" ] || { echo "parse-check: no such directory: $dir" >&2; exit 2; }
[ -x "$BASH32" ] || { echo "parse-check: $BASH32 is not executable" >&2; exit 2; }
"$BASH32" --version | head -1

fail=0
found=0
# Recursive: core keeps hooks in hooks/, a rulebook keeps them in
# <plugin>/hooks/, and both keep test harnesses one level deeper.
while IFS= read -r f; do
  found=$((found + 1))
  if err="$("$BASH32" -n "$f" 2>&1)"; then
    printf 'ok    %s\n' "${f#"$dir"/}"
  else
    printf 'FAIL  %s\n%s\n' "${f#"$dir"/}" "$err"
    fail=1
  fi
done < <(find "$dir" -name '*.sh' -type f | sort)

if [ "$found" = 0 ]; then
  echo "parse-check: no shell files under $dir — nothing was checked" >&2
  exit 2
fi
printf '\nparse-check: %d file(s) under %s\n' "$found" "$BASH32"
exit "$fail"
