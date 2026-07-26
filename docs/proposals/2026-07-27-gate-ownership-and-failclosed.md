---
status: approved
files:
  - ops-cycle/hooks/state-gate.sh
  - ops-cycle/hooks/run-gate-tests.sh
  - docs/proposals/2026-07-27-gate-ownership-and-failclosed.md
---

## Intent

Under contract-v2 the blackboard lives at `docs/reports/records/<subject>/<role>.md`; each role's gate must enforce §11 subject-scoped path-ownership (a role writes only its own `<role>.md`), and must FAIL CLOSED on malformed input (a gate that cannot understand its input denies, exit 2 — it never exits 0 silently). Two live defects in `ops-cycle/hooks/state-gate.sh` break both halves of that norm, surfaced by the relay-sim-v2 runs recorded in `docs/reports/2026-07-27-full-gate-relay-simulation.md` and `docs/reports/2026-07-27-hunt-full-gate-relay-simulation.md`. This proposal describes fixing both.

## Constraints

- The gate's subject-scoped ownership check must mirror the shape already used by the qa and product gates — no new mechanism invented for ops.
- The malformed-input branch must deny (exit 2), matching all five sibling gates and this gate's own header comment, which already claims fail-closed behavior it does not deliver.
- No change to the flat `ops/state.md` check already in place; the subject-scoped check is additive, not a replacement.
- No change to any of the other five rulebook repos or to relay-sim-v2.

## What will be done

- `ops-cycle/hooks/state-gate.sh`:
  - Add subject-scoped owned-path classification: recognize writes under `docs/reports/records/<subject>/<role>.md`, and for the ops role, allow only `.../ops.md` under any subject, refusing (exit 2, citing §11) any write to another role's file under the same subject — mirroring the qa/product gates' existing shape.
  - Change the malformed-input branch (`if not isinstance(tool_input, dict): allow()`) to deny (exit 2) instead of allow, so `echo '' | bash state-gate.sh` and other unparseable stdin refuse with no silent exit 0, matching the five sibling gates and the header's stated fail-closed behavior.
- `ops-cycle/hooks/run-gate-tests.sh`: add test cases covering (1) ops writing its own subject-scoped record, (2) ops attempting to write another role's subject-scoped record under the same subject, and (3) empty/malformed stdin.

## Out of scope

- The other five rulebook repos (coding, qa, feasibility, product, review).
- relay-sim-v2.

## How we know it worked

- `echo '' | bash ops-cycle/hooks/state-gate.sh` exits 2 with a stderr refusal, not a silent exit 0.
- A tool_input writing `docs/reports/records/<subject>/ops.md` for the ops role exits 0 (allowed).
- A tool_input where the ops role attempts to write `docs/reports/records/<subject>/qa.md` (or any other role's file) under the same subject exits 2, citing §11.
- `ops-cycle/hooks/run-gate-tests.sh` passes, including the three new cases above.

## What did not work

- Ran the full `run-gate-tests.sh` suite before and after this change and found 4 pre-existing failures (`same-state-with-self-loop`, `legal-transition`, `existing-valid-trailing-whitespace-crlf`, `genuinely-absent-bootstrap-allowed`), all failing with "this repo has no collaboration contract yet." — the test harness's temp working dirs never seed `docs/specs/role-handoff-contract.md`, so the gate's collaboration-contract check (added by an earlier, unrelated change) denies before reaching the transition-table logic. Confirmed via `git stash` that these 4 failures are identical on the pre-change file, so this is a pre-existing test-fixture gap, not a regression introduced by this proposal's write set. Left unfixed: it is outside this proposal's frozen files/scope (fixing it would mean changing the test harness's fixture setup beyond the three new cases specified here, or touching gate logic not named in the write set).
