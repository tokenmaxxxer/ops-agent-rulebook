# Handbook — running this repo's checks

    /bin/bash tests/parse-check.sh
    /bin/bash tests/deny-only-check.sh
    /bin/bash tests/role-name-check.sh
    /bin/bash <core>/hooks/tests/stub-check.sh ops/hooks

`tests/parse-check.sh`'s no-arg default resolves to the repo root
(issue-39 fix — it previously defaulted to `ops/hooks` only, which
silently skipped the other five plugins' `hooks/*.sh` and
`hooks/tests/*.sh`), so the documented no-arg invocation above walks
every plugin's `hooks/` tree: 15 files as of this writing (run the
script to get the current count — it prints `parse-check: N file(s)
under ...` on every run, so this number is not meant to be kept
byte-for-byte in sync by hand).

The role-agnostic gates (trailer/record-fields/handbook-trigger) and their
tests now live in core canon (core issues #63/#66); `ops/hooks/` no
longer vendors copies or a local `tests/run-gate-tests.sh` (issue-28).
Verify those gates via core's own `stub-check.sh`/`run-role-gates-tests.sh`
against `ops/hooks`.
