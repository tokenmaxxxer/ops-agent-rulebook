---
status: landed
files:
  - docs/specs/role-handoff-contract.md
  - ops-cycle/hooks/run-gate-tests.sh
---

## Intent

The gate's Rule 0 (contract-presence) refuses handoff-protocol actions unless `docs/specs/role-handoff-contract.md` exists inside the current repo's git root — this repo-local requirement was established in 2026-07-26-repo-local-contract.md. `ops-agent-rulebook` has never carried that file, so several gate test cases are red today: the subject-scoped ownership tests and the fail-closed tests cannot exercise their intended pass/refuse paths because Rule 0 refuses everything first, before those rules get a chance to run. This proposal gives the repo its own contract file so Rule 0 passes and the downstream test cases can actually test what they were written to test.

## Constraints

- The contract content must be sourced from an existing, already-agreed v2 handoff contract, not authored fresh, to avoid this repo silently diverging from the protocol the other rulebooks share.
- Only the contract file and the test harness may change; gate logic itself is out of scope (already being worked on branch gate-fix).
- No push, no merge, no cross-repo write.

## What will be done

- Create `docs/specs/role-handoff-contract.md` with content sourced via `git show v2-conformance:docs/specs/handoff-protocol.md` from `/home/jwjung/tokenmaxxxer/coding-agent-rulebook`, adapted only where paths/repo-name references require it to stand alone as this repo's own contract.
- Update `ops-cycle/hooks/run-gate-tests.sh` so the four currently-red contract-absent test cases reflect the new expected outcome (contract present, Rule 0 passes) instead of asserting refusal-by-absence.

## Out of scope

- Any other rulebook repo (coding, qa, feasibility, product, review) or the root `tokenmaxxxer` repo.
- Merging this branch or pushing anywhere.
- Gate logic changes (tracked separately on gate-fix).

## How you'll know it worked

- Rule 0 (contract-presence) no longer refuses when run from this repo's own working tree.
- A test invoking the gate against this repo's own `ops.md` handoff is allowed through.
- A test invoking the gate against a foreign/other-repo subject is still refused per §11 (subject-scoped ownership).
- A test feeding empty stdin is still denied (fail-closed behavior unchanged).
- The four previously-red contract-absent test cases in `ops-cycle/hooks/run-gate-tests.sh` flip green.

## What did not work

- First attempt: add `docs/specs/role-handoff-contract.md` and rerun the
  suite unchanged, expecting only the four contract-absent cases to flip.
  Instead 7 cases failed. Root cause: `state-gate.sh` resolves its repo
  root by walking up from its own on-disk script location to the nearest
  `.git` — it never reads `CLAUDE_PROJECT_DIR` or the process cwd (stated
  explicitly in the gate's own header comment). The test harness was
  staging each case's `ops/state.md` fixture under a per-case `tmp_root`
  and exporting `CLAUDE_PROJECT_DIR` to point at it, which the gate simply
  never consults — every case was actually being judged against this
  real repo's own (previously nonexistent) `ops/state.md`, i.e. always
  `(none)` as the current status, regardless of the fixture content.
  With no contract file, that mismatch was invisible: the missing-contract
  refusal fired first and happened to match several cases' expected exit
  code by coincidence. Once the contract file existed, the coincidence
  cleared and the harness's real bug (fixtures written to a location the
  gate never reads) showed up as failures unrelated to the four cases this
  proposal targeted.
- Fix: `run_gate-tests.sh` now stages each case's state-file content at
  this repo's own real `ops/state.md` (backing up and restoring whatever
  was there before the suite ran), matching where the gate actually looks.
  This was necessary to keep the harness honest, even though it was not
  named in the original write-set description of "test harness
  expectations" — the frozen file itself (`run-gate-tests.sh`) already
  covered this change; no additional file needed to be added to the
  write-set.
