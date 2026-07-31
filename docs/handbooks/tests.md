# Handbook — running this repo's checks

    /bin/bash tests/parse-check.sh
    /bin/bash tests/deny-only-check.sh
    /bin/bash <core>/hooks/tests/stub-check.sh ops/hooks

The role-agnostic gates (trailer/record-fields/handbook-trigger) and their
tests now live in core canon (core issues #63/#66); `ops/hooks/` no
longer vendors copies or a local `tests/run-gate-tests.sh` (issue-28).
Verify those gates via core's own `stub-check.sh`/`run-role-gates-tests.sh`
against `ops/hooks`.
