---
status: landed
files:
  - product-agent-rulebook/product-cycle/hooks/transition-rules.md
  - product-agent-rulebook/product-cycle/hooks/state-gate.sh
  - product-agent-rulebook/product-cycle/hooks/inject-transition-rules.sh
  - feasibility-agent-rulebook/feasibility-cycle/hooks/transition-rules.md
  - feasibility-agent-rulebook/feasibility-cycle/hooks/state-gate.sh
  - feasibility-agent-rulebook/feasibility-cycle/hooks/inject-transition-rules.sh
  - review-agent-rulebook/review-cycle/hooks/transition-rules.md
  - review-agent-rulebook/review-cycle/hooks/state-gate.sh
  - review-agent-rulebook/review-cycle/hooks/inject-transition-rules.sh
  - ops-agent-rulebook/ops-cycle/hooks/transition-rules.md
  - ops-agent-rulebook/ops-cycle/hooks/state-gate.sh
  - ops-agent-rulebook/ops-cycle/hooks/inject-transition-rules.sh
  - docs/specs/agent-roles.md
---

# State-machine bootstrap: converge all four repos on `(none)` as the pre-existence state

## Intent

`docs/reports/2026-07-26-hunt-conversational-state-machine.md` reproduces a
permanent deadlock in `product-agent-rulebook` on a clean checkout: nothing
creates `product/state.md`; `transition-rules.md` has no row whose `from` is
the no-state-file case; `state-gate.sh` therefore refuses the very write that
would create the file; `inject-transition-rules.sh` refuses to say anything
but "rules could not be loaded" until the file already exists. The landed
proposal `docs/proposals/2026-07-26-conversational-state-machine.md` names
this in its "What did not work" section as affecting `product`, `review`, and
`ops` (`review` and `ops` only avoid triggering it today because their state
files happen to already exist in the working copy) and records that
`feasibility-agent-rulebook` is the one repo that already handles this, via a
synthetic state. This proposal fixes the other three and renames
`feasibility`'s literal so all four repos converge on one bootstrap
convention instead of running two.

## Constraints that change what gets built

- **One literal, `(none)`, across all four repos.** `feasibility` today uses
  the bare word `none` (no parentheses) as its synthetic pre-existence
  status, in `transition-rules.md`'s two `none | idle | ...` / `none |
  scoped | ...` rows, in `state-gate.sh`'s `old_status = "none"` default and
  its `known_states.discard("none")` line, and in `inject-transition-rules.sh`'s
  `status = "none"` default. `product` (in `state-gate.sh`'s deny-message
  formatting, `old_stage or "(none)"`) and this proposal's own frozen
  decision both already write it parenthesized. `(none)` wins; `feasibility`'s
  three files are edited to rename `none` to `(none)` everywhere it appears
  as the synthetic value, not just added to alongside it.
- **Absence is a state, not an error, in the gate.** `product`'s
  `state-gate.sh` today computes `old_stage = ""` when `product/state.md`
  does not exist and never matches any table row with that empty string, so
  even a bootstrap row would not fire. `review`'s and `ops`'s gates go
  further and misclassify absence outright: `review`'s `read_state_file()`
  returns `None` on a missing file and the caller immediately refuses with
  "the transition rules could not be loaded ... could not be read (missing
  or unreadable)"; `ops`'s `read_current_status()` does the opposite wrong
  thing — it silently treats a missing file as already-`idle`, so a
  bootstrap write is never checked against the table at all and the write
  succeeds regardless of what row exists. All three must instead compute the
  current state as the literal string `(none)` when the state file does not
  exist, and treat that exactly like any other current state: look up
  `(none) -> <target>` in the parsed rows, allow if present, deny with the
  ordinary "not in the table" message if not.
- **Absence is a state, not an error, in the injector.** `product`'s
  `inject-transition-rules.sh` calls `fail()` — the "transition rules could
  not be loaded" block — the instant `product/state.md` can't be opened.
  `review`'s injector does the same (`fail("state file %s could not be read
  (missing or unreadable)")`). `ops`'s injector does too
  (`read_status()` returns `(None, "ops/state.md does not exist")`, which
  `fail()`s). All three must instead render the normal "current state: ..."
  block with current state `(none)` and list whichever rows have `from =
  (none)`, exactly as they already do for any other named state. The
  fail/error block stays reserved for what it already correctly covers in
  each repo: `transition-rules.md` missing/empty/unparseable, or a state
  file that exists but whose state field is absent, duplicated, or itself
  unparseable (`product`'s multiple-`stage:`-fields case, `review`'s
  duplicated-`status:` case, `ops`'s no-frontmatter/no-closing-`---`/no-
  `status:` cases all stay errors — only "the file does not exist at all"
  moves from error to `(none)`).
- **`(none)` is never a `to`.** No row in any repo's `transition-rules.md`
  may have `(none)` in the `to` column; deleting a state file is not a
  transition this state machine models, and no gate logic added here creates
  a path back into `(none)`.
- **Per-repo independence holds.** Each of the four repos gets its own edit
  to its own three files; nothing is shared or imported across repos.
  `coding-agent-rulebook` and `qa-agent-rulebook` are not read or touched.
- **`docs/specs/agent-roles.md` does not yet document this.** Part 3's
  mechanism paragraph says only "If the table or the state file cannot be
  read, that hook still emits a block saying so" — it does not distinguish
  "does not exist yet" from "exists but is broken," which is exactly the
  conflation this proposal removes from the four rulebooks' code. The spec
  moves in the same unit so it stays accurate.

## What will be done (per repo)

**`product-agent-rulebook`** (`product-cycle/hooks/`) — all three files,
because today none of them has a bootstrap path at all:
- `transition-rules.md`: add one row, `(none) | idle | agent | product/state.md
  does not yet exist; the first write creates it with stage: idle`.
- `state-gate.sh`: change `old_stage = ""` (the "file does not yet exist"
  default, currently never matched against any row) to `old_stage =
  "(none)"`, so the existing `(old_stage, new_stage) in rows` check can
  actually allow the bootstrap row once it exists; the deny message already
  renders `old_stage or "(none)"` and needs no further change there.
- `inject-transition-rules.sh`: replace the `except OSError` branch that
  calls `fail("product/state.md is missing or unreadable ...")` with logic
  that instead sets `current_stage = "(none)"` and falls through to the
  normal "current state" rendering path; the empty-content and multiple-
  `stage:`-fields branches are untouched (those stay errors).

**`feasibility-agent-rulebook`** (`feasibility-cycle/hooks/`) — all three
files, to rename its existing synthetic state rather than add a second one:
- `transition-rules.md`: `none | idle | agent | ...` and `none | scoped |
  agent | ...` become `(none) | idle | ...` and `(none) | scoped | ...`.
- `state-gate.sh`: `old_status = "none"` (default when
  `feasibility-record.md` doesn't exist) becomes `old_status = "(none)"`;
  `known_states.discard("none")` becomes `known_states.discard("(none)")`.
- `inject-transition-rules.sh`: `status = "none"` (the else-branch default
  when the record file doesn't exist) becomes `status = "(none)"`.

**`review-agent-rulebook`** (`review-cycle/hooks/`) — all three files,
because today it has no bootstrap row and both hooks treat a missing state
file as an error:
- `transition-rules.md`: add `(none) | idle | agent | review-record.md does
  not yet exist; the first write creates it with status: idle`.
- `state-gate.sh`: `read_state_file()` currently returns `None` on a missing
  file, which its caller turns into a hard refuse; change the caller so a
  `None` return specifically for "file does not exist" (distinct from a
  caught `OSError`/`UnicodeDecodeError` on an existing-but-broken file) sets
  `cur_status = "(none)"` instead of refusing, then proceeds to the normal
  `(cur_status, attempted_status) in rows` check.
- `inject-transition-rules.sh`: the Python block's
  `except OSError as e: fail("state file %s could not be read (%s)" % ...)`
  is changed to distinguish "does not exist" (`FileNotFoundError`, or an
  `os.path.isfile` check before opening) from other `OSError`s; the former
  sets `status = "(none)"` and continues to the normal `OK` output path
  instead of calling `fail()`.

**`ops-agent-rulebook`** (`ops-cycle/hooks/`) — all three files, because
today it has no bootstrap row and its gate and injector actively disagree
with each other about a missing file (gate silently treats it as `idle` and
never checks the table; injector treats it as a hard error):
- `transition-rules.md`: add `(none) | idle | agent | ops/state.md does not
  yet exist; the first write creates it with status: idle`.
- `state-gate.sh`: `read_current_status()`'s `if not os.path.isfile(state_abs):
  return "idle"` becomes `return "(none)"`, so the bootstrap write is
  actually checked against `transition-rules.md` like every other write
  instead of being silently exempted.
- `inject-transition-rules.sh`: `read_status()`'s `if not
  os.path.isfile(state_abs): return None, "ops/state.md does not exist"`
  becomes `return "(none)", None` (no error), so the caller's `if rules_err
  or status_err` branch is not taken for this case and the normal "Current
  state: `(none)`" block renders instead of the "COULD NOT BE LOADED" block.

**`docs/specs/agent-roles.md`** — Part 3's mechanism paragraph ("If the
table or the state file cannot be read, that hook still emits a block saying
so and forbidding transitions until it is fixed — it never exits silently.")
gets one clause added: a state file that does not exist yet is not this
error condition; its current state is the literal `(none)`, every role's
`transition-rules.md` carries at least one row with `from = (none)` naming
its legal initial state, and `(none)` is never reachable as a `to`. The
error-block wording stays reserved for `transition-rules.md` itself being
missing/unparseable, or a state file that exists but whose state field is
absent, duplicated, or unparseable.

## Out of scope

- `coding-agent-rulebook` and `qa-agent-rulebook`: not read, not edited.
- Any change to what counts as an error condition beyond "file does not
  exist" moving to `(none)` — every other existing error path (missing
  `transition-rules.md`, empty/unparseable rules, a state file that exists
  but has a missing/duplicated/unparseable state field) is untouched.
- Any change to the shape or content of the non-bootstrap rows already in
  each repo's `transition-rules.md`.
- Any change to `hooks.json`, `.gitignore`, or any file already finished by
  `docs/proposals/2026-07-26-conversational-state-machine.md`.
- Actually creating a state file, running a role, or any other live-data
  bootstrapping — this proposal changes the mechanism, not any project's
  current on-disk state.

## How we will know it worked

On a clean checkout of each of the four repos (no `product/state.md`,
`feasibility-record.md`, `review-record.md`, or `ops/state.md` present):

1. Running that repo's `inject-transition-rules.sh` with empty stdin prints
   a normal-looking block naming current state `(none)` and listing the
   `(none)` row(s) — not a "rules could not be loaded" block.
2. Feeding that repo's `state-gate.sh` a `Write` tool-call payload that
   creates the state file with the `(none)` row's named initial state (e.g.
   `stage: idle` / `status: idle`) exits 0 (allowed).
3. Feeding the same gate a `Write` payload that creates the state file with
   any state *not* named in a `(none)` row exits 2, denied with "this
   transition is not in the table," not a "rules could not be loaded"
   message.
4. `grep -rn '(none)' */hooks/transition-rules.md` (workspace-relative,
   across the four rulebooks) shows exactly one bootstrap row per repo, and
   `grep -rn '"to": *"(none)"\|to.*(none)' */hooks/transition-rules.md`
   finds none — `(none)` never appears in a `to` column.
5. `docs/specs/agent-roles.md` Part 3's mechanism paragraph states the
   `(none)` convention in the terms above.

## What did not work

- Expected the bootstrap transition's output to be an ordinary tracked file; in ops-agent-rulebook and feasibility-agent-rulebook the state file the `(none)` transition creates is already listed in that repo's own `.gitignore`, so the first bootstrap write never reaches git. `.gitignore` was not in this proposal's write set. Reproduced by the before-landing hunter; see docs/reports/2026-07-27-hunt-state-machine-bootstrap.md.
- The four repos disagree on whether the role's state file is a tracked artifact or a runtime artifact — product and review track it, ops and feasibility ignore it — and no document states which is correct. The bootstrap change made that unstated disagreement load-bearing.
