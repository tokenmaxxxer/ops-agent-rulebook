---
status: approved
files:
  - ops-cycle/hooks/state-gate.sh
  - ops-cycle/hooks/doc-bucket-gate.sh
  - ops-cycle/hooks/handbook-trigger-gate.sh
  - ops-cycle/hooks/path-ownership-gate.sh
  - ops-cycle/hooks/record-fields-gate.sh
  - ops-cycle/hooks/trailer-gate.sh
  - ops-cycle/hooks/run-gate-tests.sh
  - ops-cycle/hooks/run-procedure-gate-tests.sh
  - docs/proposals/2026-07-26-gates-fail-closed-on-internal-error.md
---

## Intent

Claude Code PreToolUse hooks BLOCK a guarded tool call only on exit 2. Every
other non-zero exit is treated as NON-BLOCKING (fail-open). So an internal
crash in a gate's judge — most dangerously an uncaught `ValueError` from
`os.path.realpath` on a null-byte or undecodable `file_path` (exit 1) — would
let the guarded write/commit through rather than deny it. This proposal hardens
every ops-cycle gate script so that ANY internal error resolves to exit 2
(DENY), while preserving each gate's exact allow(0)/deny(2) verdict on
well-formed input.

## Constraints

- No logic change to any gate's actual verdict. Only what happens on ERROR
  changes; the legitimate exit 0 (allow) and exit 2 (deny) decision paths are
  preserved exactly.
- Two layers per gate, matching the frozen contract:
  1. Shell layer: capture the judge's exit code and map anything that is not 0
     and not 2 to exit 2, printing a "fail-closed: internal error" message to
     stderr. `set -e` must not abort the script with a bare non-2 code — the
     heredoc invocation is guarded with `|| rc=$?` so the terminal exit is only
     ever 0 or 2. Missing `python3` already denies.
  2. Python layer: an uncaught exception in the judge becomes exit 2 via a
     `sys.excepthook` that writes a deny reason to stderr and calls
     `os._exit(2)`. `deny()`/`allow()` use `sys.exit` (SystemExit), which
     bypasses the excepthook, so verdicts are unaffected. This catches the
     `os.path.realpath` null-byte `ValueError` case specifically.

## What was done

- Added the shell rc-mapping wrapper (`rc=0` + `|| rc=$?` + terminal
  `if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then ... exit 2; fi; exit "$rc"`) and
  the python `sys.excepthook` fail-closed net to each of the six gate scripts:
  `state-gate.sh`, `doc-bucket-gate.sh`, `handbook-trigger-gate.sh`,
  `path-ownership-gate.sh`, `record-fields-gate.sh`, `trailer-gate.sh`.
- Added crash-payload test cases asserting exit 2 (DENY):
  - `run-gate-tests.sh`: a null-byte `file_path` case for `state-gate.sh`.
  - `run-procedure-gate-tests.sh`: null-byte `file_path` cases for
    `record-fields-gate.sh`, `path-ownership-gate.sh`, `doc-bucket-gate.sh`,
    and malformed-JSON crash cases for the commit-time gates
    `handbook-trigger-gate.sh` and `trailer-gate.sh`, each asserting exact
    exit 2.
- Ran both harnesses: all pre-existing allow/deny cases still pass and the new
  crash cases pass (28 + 28 = 56 passed, 0 failed).

## Out of scope

- The other rulebook repos (coding, qa, feasibility, product, review).
- Any change to a gate's verdict on well-formed input.
- `inject-transition-rules.sh` (a UserPromptSubmit injector, not a gate).
