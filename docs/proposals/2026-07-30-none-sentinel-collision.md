---
status: landed
files:
  - product-agent-rulebook/product-cycle/hooks/state-gate.sh
  - product-agent-rulebook/product-cycle/hooks/run-gate-tests.sh
  - product-agent-rulebook/product-cycle/hooks/inject-transition-rules.sh
  - feasibility-agent-rulebook/feasibility-cycle/hooks/state-gate.sh
  - feasibility-agent-rulebook/feasibility-cycle/hooks/run-gate-tests.sh
  - feasibility-agent-rulebook/feasibility-cycle/hooks/inject-transition-rules.sh
  - review-agent-rulebook/review-cycle/hooks/state-gate.sh
  - review-agent-rulebook/review-cycle/hooks/run-gate-tests.sh
  - review-agent-rulebook/review-cycle/hooks/inject-transition-rules.sh
  - ops-agent-rulebook/ops-cycle/hooks/state-gate.sh
  - ops-agent-rulebook/ops-cycle/hooks/run-gate-tests.sh
  - ops-agent-rulebook/ops-cycle/hooks/inject-transition-rules.sh
  - docs/specs/agent-roles.md
---

# `(none)`-sentinel collision in all four state gates

## Intent

`docs/reports/2026-07-29-hunt-same-state-gate-and-state-file-policy.md`'s
before-landing hunt (stance 2) reproduced, against
`product-agent-rulebook/product-cycle/hooks/state-gate.sh`, that a state file
which *exists* but whose `stage`/`status` value is the literal string
`(none)` — the gate's own synthetic sentinel meaning "the file does not
exist" — is silently indistinguishable from a genuinely missing file once
parsed. A `Write` moving `stage: (none)` to `stage: idle` matched the
`(none) | idle` bootstrap row and passed with exit 0 and no output, even
though the file was present and its recorded stage was not a member of the
real state set (`idle, scoping, researching, hypothesis-registered,
measuring, decided`). Reading all four gates for this proposal confirms the
pattern is structural, not particular to `product`:

- **product** (`state-gate.sh` line 248-257): `NONE_STATE = "(none)"` is used
  both as the default assigned when the file is absent and as whatever
  `parse_stage` returns when the file exists — nothing rejects `(none)` (or
  any other unrecognized string) as a parsed value from an *existing* file.
- **feasibility**: `known_states` is computed from `transition-rules.md` and
  explicitly discards `"(none)"` (line 245-248), and the *new* status is
  checked against it — but the *old* status, read at line 251-266 from an
  existing file, is never checked against `known_states` at all. An existing
  file with `status: (none)` or any other garbage value sails through
  unexamined as the "current" state.
- **review**: `current_status()` (line 352-365) only denies when the
  `status` field is missing; a present-but-`(none)`-or-garbage value is
  returned as-is and used as `cur_status` for the row lookup.
- **ops**: line 203-208's helper returns the literal `"(none)"` for a missing
  file, and nothing downstream re-validates a value read from an existing
  file against the known-state set before the `(frm, to) not in rules` check
  at line 329.

All four already draw the distinction between the two denial messages
("the transition rules could not be loaded" for a gate that cannot establish
its own input, vs. "this transition is not in the table" for a table that
refuses a well-formed transition) — the fix is to route the
exists-but-unrecognized case into the first message instead of letting it
fall through as if the file were absent.

## Constraints that change what gets built

- Every repo is self-contained: each of the four implements the fix in its
  own copy of `state-gate.sh` and its own `run-gate-tests.sh`. No shared
  file, no cross-repo import.
- `coding-agent-rulebook` and `qa-agent-rulebook` are out of bounds and are
  not touched by this proposal.
- The frozen resolved-path rule is unchanged: the gate judges the resolved
  target path of a write, never a tool name, never a literal filename in a
  command string; an unresolvable `Bash` write target aimed at the state
  file's own directory still fails closed exactly as before.
- The same-state rule that just landed (`2026-07-29-same-state-gate-and-
  state-file-policy`) is unchanged: a write whose resulting state equals the
  current state is judged by the table and allowed only if a `from == to`
  row exists with a satisfied actor/precondition.
- `(none)` remains the synthetic bootstrap state in all four tables; it is
  never a legal `to` value, and this proposal does not add, remove, or
  reorder any transition row.
- Artifact writes (one-pagers, spike reports, finding records, rollout
  plans, postmortems) stay ungated; only the role's own state file is gated,
  in every repo.
- The two denial messages stay distinct and keep their existing wording
  conventions per repo: "the transition rules could not be loaded" (or that
  repo's equivalent phrasing already in use) for a gate that cannot
  establish its own input, versus "this transition is not in the table" (or
  equivalent) for a transition the table refuses.

## What will be done

The following is the frozen contract for the build; the implementer follows
it verbatim in each of the four repos independently.

- **Derive "no state file" from file existence alone**, as a separate
  boolean computed before any parsing, and never by comparing a parsed state
  value against the `(none)` string. Only a genuinely absent state file
  yields the synthetic `(none)` old state used for bootstrap-row matching.
- **If the state file exists**, its parsed state value must be a member of
  that role's own known-state set (read from `transition-rules.md`'s `from`/
  `to` columns, minus `(none)`, exactly as feasibility's existing
  `known_states` computation already does for the *new* value — this fix
  extends the same check to the *old* value in all four repos, and
  introduces the computation in product/review/ops where it doesn't yet
  exist for either value). `(none)` appearing as the on-disk value, an empty
  value, a missing state field, and any value outside the known-state set
  are all the same case: the gate cannot establish its own input, so it
  denies with that repo's existing "rules could not be loaded" message —
  never with the "transition not in the table" message, because the table
  is not the thing that failed.
- **Trailing whitespace and CRLF are stripped** before the membership check;
  a value that is only whitespace after stripping counts as empty and takes
  the same denial path.
- **Extend each repo's `run-gate-tests.sh`** with the cases that would have
  caught this, keeping every existing case unchanged:
  1. state file exists with value `(none)` → denied with the "rules could
     not be loaded" message (the hunter's exact reproduction, adapted to
     that repo's carrying artifact and field name).
  2. state file exists with an empty state value → denied likewise.
  3. state file exists with a value not in the known-state set (e.g. a
     typo'd or stale state name) → denied likewise.
  4. state file genuinely absent → the existing `(none) -> X` bootstrap row
     is still allowed (regression guard: confirms the fix didn't collapse
     the legitimate bootstrap path along with the bug).

- **Each role's `inject-transition-rules.sh` follows the same rule as its
  gate**: it derives "no state file" from file existence alone, and never by
  comparing the parsed state value against the `(none)` string. If the state
  file exists, its parsed state value must be a member of that role's
  known-state set (per the same computation the gate uses). An existing
  state file whose state value is `(none)`, empty, missing, or outside the
  known-state set is a broken input for the injector exactly as it is for
  the gate — the injector emits its existing visible failure block (the one
  already reserved for a broken `transition-rules.md` table or a broken/
  absent state field), and it never renders `(none)` or any other
  out-of-set value as if it were the current state to inject a prompt
  about. The injector and the gate must agree on what counts as unloadable:
  a state the gate refuses to leave must never be a state the injector
  proceeds from as though it were legitimate.

**`docs/specs/agent-roles.md`** — included in the write set, amended, not
left alone. Its "Bootstrap convention" paragraph already draws part of the
distinction this proposal needs — it says the `UserPromptSubmit` injector
treats a missing state file as *not* a failure, and separately says it
"emits the 'rules could not be loaded' failure block only for a missing or
unparseable `transition-rules.md`, or a state file that exists but whose
state field is absent, duplicated, or unparseable." That sentence covers
"absent" and "unparseable" but does not say, in terms an implementer can't
misread, that `(none)` itself — or any string outside the role's declared
state list — read from an *existing* file counts as "unparseable" for this
purpose, and it scopes the sentence to the `UserPromptSubmit` injector only,
leaving the `PreToolUse` gate's own parallel obligation (stated two
paragraphs earlier: "it never exits silently") without the same explicit
carve-out. Left as-is, a future implementer reading only the spec (not the
hunt report) has no textual basis for treating `(none)`-as-value as a
failure rather than as the bootstrap sentinel it also is. The amendment adds
one sentence to the Bootstrap convention paragraph, applying to both the
injector and the `PreToolUse` gate: a state file that exists is checked
against the role's declared state list regardless of what value it holds,
`(none)` included, and any value outside that list — `(none)` or otherwise —
is treated identically to "unparseable," never merged with the true-absent
case. No other line in that document changes.

## Out of scope

- `coding-agent-rulebook` and `qa-agent-rulebook`.
- Any change to the artifact-producing skills — their writes are ungated
  today and remain ungated.
- The resolved-path binding rule itself.
- The same-state/self-loop mechanism landed by the prior proposal — no row
  in any `transition-rules.md` is added, removed, or reordered here.
- The state-file gitignore policy (already settled by the prior proposal).
- Any rewording of `agent-roles.md` beyond the single sentence identified
  above.

## How we will know it worked

- In all four repos, the four new denial cases (existing-`(none)`,
  existing-empty, existing-out-of-set, genuinely-absent-bootstrap-still-
  allowed) pass in `run-gate-tests.sh`.
- The hunter's exact reproduction — a `product/state.md` that exists with
  `stage: (none)`, targeted by a `Write` to `stage: idle` — is denied with
  the "rules could not be loaded" message instead of silently allowed.
- The genuine-bootstrap case (state file absent, `Write` creating it with a
  legal initial state) still passes in all four repos, confirming nothing
  that worked before this fix is now blocked.
- Every pre-existing gate-test case in all four repos still passes
  unchanged.
- The injector and the gate reach the same verdict on the same broken state
  file, so no prompt is ever injected describing a state the gate would
  refuse to leave.

## What did not work

- 게이트만 고치면 규칙이 성립한다고 보고 injector를 쓰기 집합에서 뺐는데, after-proposal 헌터가 스펙 수정문은 injector까지 약속하면서 빌드 계약은 injector를 건드리지 않는 불일치를 재현했다. 네 `inject-transition-rules.sh`를 쓰기 집합에 넣고 동일 규칙을 계약에 추가했다.
