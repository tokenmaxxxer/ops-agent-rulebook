---
status: approved
files:
  - README.md
  - ops-cycle/hooks/state-gate.sh
  - ops-cycle/hooks/run-gate-tests.sh
---

# Bring ops-agent-rulebook onto contract v2 (blackboard/event model)

## Background

`docs/specs/role-handoff-contract.md` landed at commit `b240ec4` in the root
`tokenmaxxxer` repo, replacing the v1 one-shot parcel-handoff model
(ACCEPTS/refuse a whole kind at a fixed moment) with a shared blackboard
each role reads, writes its own record onto, and wakes from. This
rulebook's own "Handoff protocol" section in `README.md` (lines 55-111,
landed by `docs/proposals/2026-07-26-role-protocol-section.md` and later
trimmed by `docs/proposals/2026-07-26-repo-local-contract.md`) still speaks
v1: an `### ACCEPTS` heading with an accept/refuse list, a `### PRODUCES`
list, and a `### STOPS` list. None of section 3's WAKES-ON language, section
4's READ/DEPENDS-ON split, section 5's finding back-edge, or section 6's
loop-termination rule appears anywhere in this repo. This proposal
commissions rewriting the README section and auditing the gate script
against the new contract. It is a proposal, not the change itself — no file
listed above is edited by this document.

## What was found

**README.md "Handoff protocol" (lines 55-111).** Current shape:

- `### ACCEPTS` (lines 64-71): "`build-proposal` — what merged.",
  "`hypothesis` or `feasibility-record` — the measurement design.", and
  "Refuses `qa-state` and `review-record`". This is v1's single
  accept/refuse lever — it conflates "may ops read this" with "may ops
  depend on this," which is exactly the conflation contract v2 §4 calls out
  by name ("v1 had one lever ... and used it to also answer 'may this role
  even read that file'").
- `### PRODUCES` (lines 78-95) and `### STOPS` (lines 97-110) are mostly
  compatible with v2 in content — the `ops-state` field list already matches
  contract v2 §2's `ops-record` row, and the tension note at lines 86-89
  already paraphrases what is now v2 §10's "`ops-record` tension, carried
  forward" paragraph. These need updating in name and cross-reference (v2
  calls it `ops-record`, not `ops-state`) but not a structural rewrite.
- There is no WAKES-ON language anywhere in the README. The state-machine
  section (lines 27-53) describes ops's *internal* `idle -> readiness ->
  rollout -> steady -> incident` machine and its two hooks, but nothing
  states *when ops wakes* relative to the board, which is v2 §3's new
  concept ("ops wakes on: a change landed (merged) that is ready to roll
  out").
- No finding back-edge (v2 §5) or loop-termination rule (v2 §6) is
  mentioned at all.

**`ops-cycle/hooks/state-gate.sh`.** This file does *not* implement
kind-based read refusal, an ACCEPTS check, or a `^kind:\s*(\S+)\s*$`-style
regex — a `grep -rn "kind:" ops-cycle/` and `grep -rn "ACCEPTS"` across the
whole repo turn up nothing inside `ops-cycle/`. The only place `ACCEPTS`
appears in the repo is `README.md:64` and the historical proposal that added
it. The gate's actual job today (per its own header comment, lines 1-38) is
narrow and unrelated to the blackboard: it watches writes resolving to
`ops/state.md` and allows/denies based on whether the resulting `(from, to)`
status transition is a row in `ops-cycle/hooks/transition-rules.md`. Two
things it *does* do that are relevant to v2:

- Lines 215-217: `contract_path = posixpath.join(root,
  "docs/specs/role-handoff-contract.md")`; `if not os.path.isfile(contract_path):
  deny("this repo has no collaboration contract yet.")` — this is the
  "refuse handoff actions when the work repo has no contract" behavior
  carried from the repo-local round (`docs/proposals/2026-07-26-repo-local-contract.md`).
  It only checks the file's *existence*, never its content or version, so it
  needs no change for v2 conformance — v2 replaced v1's SHA-pin idea with
  per-`upstream`-entry staleness (contract §12), which is a per-record
  concern, not a repo-bootstrap concern this gate line addresses.
- Line 219: `STATUS_RE = re.compile(r"^status:\s*([^\r\n#]*?)\s*(?:#.*)?$",
  re.M)` — this parses the gate's own `status:` field (ops's internal
  state-machine position, distinct from the blackboard's `kind:` field) and
  *already* tolerates a trailing comment (`# ...`) via the non-capturing
  `(?:#.*)?$` tail. This is the correct shape contract v2 §2's closing
  paragraph demands for `kind:` parsing ("`kind` parsing by any gate must
  tolerate a trailing comment on the line ... a regex anchored to
  end-of-line with no comment tolerance is a gate defect"). No `kind:`
  parsing regex exists in this gate to be broken — the gate never reads
  board records' `kind:` field at all today, because it only ever gates
  `ops/state.md`, not `docs/reports/records/**`. If work item 2 below adds
  any `kind:`-aware check to this gate (e.g. refusing a write whose target
  path implies a different kind than declared), it must be built following
  `STATUS_RE`'s already-correct trailing-comment-tolerant shape, not a bare
  `^kind:\s*(\S+)\s*$` anchor.

**`ops-cycle/hooks/run-gate-tests.sh`.** Feeds fixed JSON payloads at
`state-gate.sh` and asserts exit codes (cases a-h currently: same-state
writes, legal/illegal transitions, bash writes outside the state
directory, malformed JSON, and the `(none)`/empty-status sentinel cases —
lines 38-80+). None of the existing cases touch `docs/reports/records/**`
paths, because the gate does not currently guard them. If work item 2 below
adds path-ownership or DEPENDS-ON checks to the gate, `run-gate-tests.sh`
will need new cases for: a write inside
`docs/reports/records/<subject>/ops.md` or
`.../postmortems/<incident-slug>.md` (allow), a write to another role's
record path such as `.../coding.md` or `.../feasibility.md` (deny), and a
read of any board record regardless of kind (allow, unconditionally, per
§4). This proposal does not write those cases — flagging only that they
will be needed.

## What this proposal commissions

### 1. Rewrite README.md's "Handoff protocol" section (lines 55-111) to v2 shape

Replace the `### ACCEPTS` heading and its accept/refuse list with a
`### WAKES-ON` section stating contract v2 §3's ops row verbatim: ops wakes
on a change landed (merged) that is ready to roll out. Drop the "Refuses
`qa-state` and `review-record`" line — v2 §4 makes refusal-to-read
obsolete (READ is broad, unconditional, every role may read every other
role's record for context); what that line was actually protecting is a
DEPENDS-ON boundary, not a read boundary, and belongs in the next section
instead.

Add a `### READ / DEPENDS-ON / NEVER-OVERWRITE` section per contract §4:

- **READ (broad):** ops may read any board record under
  `docs/reports/records/**` and any `docs/proposals/*` file, unconditionally,
  for context.
- **DEPENDS-ON (narrow):** ops depends on `build-proposal` (what merged —
  `docs/proposals/<date>-build-<slug>.md`) and `hypothesis` /
  `feasibility-record` (the measurement design —
  `docs/proposals/<date>-<slug>.md` or
  `docs/reports/records/<subject>/feasibility.md`), quoting contract §4's
  own line: "ops depends on `build-proposal` (what merged) and `hypothesis`
  / `feasibility-record` (the measurement design)." This replaces the old
  ACCEPTS list's content without the read-refusal framing.
- **NEVER-OVERWRITE:** ops writes only
  `docs/reports/records/<subject>/ops.md` (`kind: ops-record`) and
  `docs/reports/records/<subject>/postmortems/<incident-slug>.md`
  (`kind: postmortem`), per contract §11's table row for `ops`. Carry
  forward the existing STOPS-section behavior (README.md:103-106): an
  existing record at a path ops does not own is refused and reported, never
  overwritten or merged silently.

Rename `ops-state` to `ops-record` throughout (contract v2 §2 uses
`ops-record`; the current README says `ops-state` at line 80 and in the
tension note at line 86 — both are stale naming, not stale content). Update
the `### PRODUCES` section (README.md:78-95) to state the `ops-record` kind
explicitly, its `loop_state` vocabulary `idle,readiness,rollout,steady,incident`
(contract §2's table row), required fields `error_budget: ok|exhausted`,
`postmortem: <pointer>`, and a `## Checklist` section with lines shaped
`- item: <desc> | status: yes|no | artifact: <url/path/config key>` — this
already matches the current README text almost verbatim, so this is a
rename plus an explicit citation of contract §2, not new content. Keep the
`postmortem` kind's required-fields list (Impact, Actions taken during
response, Root cause(s), Prevention follow-up with owner+tracking+closing-condition,
Review with a named human reviewer) unchanged — it already matches contract
§2's `postmortem` row exactly.

Carry forward, with an explicit citation, the tension note currently at
README.md:86-89 ("Tension flagged, not resolved..."): restate it against
contract §10's actual sentence — "`ops-record` is rewritten in place as
current system state changes (steady, incident, error-budget), not appended
to as a dated record, unlike the rest of `reports`" — and note that the
contract states this mismatch rather than resolving it, so ops's own
rulebook should say so explicitly too, rather than silently treating
`ops-record` as append-only like `coding.md`/`feasibility.md`/`qa.md` are.

Add a `### FINDING BACK-EDGE` section per contract §5: ops may both produce
and receive `finding` blocks. When ops closes a finding addressed to it
(`addressed_to: ops`), its `ops-record` write must carry a
`finding-response` entry containing the finding reference (record path plus
finding identifier), the action taken or decline reason, and — when a fix
changed something — proof of the fix (commit sha, targeted re-run result,
or equivalent). An entry missing any of the three parts does not close the
finding, per contract §5's own completeness rule.

Add a `### LOOP TERMINATION` line per contract §6: a wake ops observes is
consumed only by writing the resulting `ops-record` entry (a `loop_state`
change, a new `finding`, or a `finding-response`); an unchanged board wakes
no one, so a wake that produces no board change is not a valid consumption
of it.

Keep the existing `### STOPS` section's staleness-check and
already-owned-path-refusal content (README.md:99-106) — it already matches
contract §12 and §11's rules; only its cross-reference should move from "the
contract" generically to citing §12 and §11 by number, and its third bullet
("`handoff_status: provisional`") should be checked against whether v2
still uses `handoff_status` at all — search contract v2 for the term before
carrying it forward verbatim, since v2's common header (§1) does not list
`handoff_status` among its fields and this may be a v1 leftover that no
longer has a home.

### 2. Audit and, where warranted, rewrite ops-cycle/hooks/state-gate.sh

- **No change needed for READ-broad.** Confirmed by reading the script in
  full: it contains no kind-based read-refusal logic to delete. It never
  inspects `docs/reports/records/**` at all; it only gates writes resolving
  to `ops/state.md`. §4's READ-broad rule is already satisfied by omission,
  not by any logic that needs removing.
- **Narrowing the gate's job per items (a)-(c):** the gate's current sole
  responsibility (transition-table membership for `ops/state.md`, lines
  204-370) is orthogonal to the blackboard and does not need narrowing on
  its own account. If this rulebook wants the gate to also enforce contract
  v2's write-ownership and DEPENDS-ON rules against `docs/reports/records/**`
  paths (which it does not do today), that would be new scope, not a
  narrowing — flag this as an open question for whoever picks up this
  proposal: does ops want a mechanical path-ownership gate at all, given
  contract §11's own closing line that "no mechanical check in this
  contract enforces [path ownership]... enforcing it is each role's own
  rulebook's responsibility"? If yes, item (a)'s write-outside-owned-paths
  refusal and item (b)'s DEPENDS-ON-violation refusal are net-new gate
  logic, scoped to exactly the two paths in contract §11's `ops` row
  (`docs/reports/records/<subject>/ops.md`,
  `docs/reports/records/<subject>/postmortems/<incident-slug>.md`).
- **Item (c), no-contract refusal:** already implemented, at
  `ops-cycle/hooks/state-gate.sh` lines 215-217 (`contract_path = ...`;
  `deny("this repo has no collaboration contract yet.")`), landed by
  `docs/proposals/2026-07-26-repo-local-contract.md`. No change needed here
  — cite it as already-conformant rather than commissioning new work.
- **`kind:` regex:** none exists in this file today (confirmed by grep — no
  `kind` token appears anywhere under `ops-cycle/`). If item (a)/(b) above
  is picked up and any new logic needs to parse a board record's `kind:`
  field, it must be built as
  `re.compile(r"^kind:\s*([^\r\n#]*?)\s*(?:#.*)?$", re.M)` — copying the
  exact tolerant shape already used by this file's own `STATUS_RE` at line
  219 — not a bare `^kind:\s*(\S+)\s*$` anchor, which would silently accept
  `kind: ops-record` but mis-parse or reject `kind: ops-record  # re-scoped`
  (the exact failure shape contract §2's closing paragraph and this
  rulebook's own hunt-report lineage, e.g.
  `docs/reports/2026-07-30-hunt-none-sentinel-collision.md`-style silent
  bypass write-ups, warn against).

### 3. Check ops-cycle/hooks/run-gate-tests.sh

No test file is written by this proposal. Flag only: if item 2 adds any
`docs/reports/records/**` logic to `state-gate.sh`, `run-gate-tests.sh`
needs new `run_case` entries (following its existing pattern, lines 15-36)
covering: a write inside ops's two owned paths (allow), a write to another
role's owned path such as `docs/reports/records/<subject>/coding.md` (deny),
and — as a regression guard proving READ-broad was not accidentally
narrowed — a read-only tool event (or an event with no matching write
target) against any board record path (allow, unconditionally). If item 2
is not picked up (gate stays scoped to `ops/state.md` only), no test
changes are needed at all.

## Write set

Exact files this proposal commissions changing, if accepted:

- `README.md` — rewrite the "Handoff protocol" section, lines 55-111, per
  item 1 above (`### ACCEPTS` -> `### WAKES-ON` +
  `### READ / DEPENDS-ON / NEVER-OVERWRITE`; `ops-state` -> `ops-record`
  rename; add `### FINDING BACK-EDGE` and `### LOOP TERMINATION`; keep and
  re-cite `### PRODUCES` and `### STOPS`).
- `ops-cycle/hooks/state-gate.sh` — only if the open question in item 2 is
  answered "yes, add mechanical path-ownership/DEPENDS-ON enforcement":
  add write-ownership refusal scoped to the two `ops`-owned paths, and, if
  any `kind:` parsing is introduced, use the trailing-comment-tolerant
  regex specified above. If answered "no," this file needs no change for
  v2 conformance beyond what is already there.
- `ops-cycle/hooks/run-gate-tests.sh` — only if `state-gate.sh` gains new
  logic per the above; add corresponding `run_case` entries.

## Out of scope

- No build work. This proposal does not edit `README.md`,
  `ops-cycle/hooks/state-gate.sh`, or `ops-cycle/hooks/run-gate-tests.sh`;
  it only commissions that work for a later, separate change.
- No commit.
- The other five rulebook repos (coding, qa, feasibility, product, review) —
  contract v2 itself states landing it in each rulebook is "separate, one
  proposal per repo."
- Changing `docs/specs/role-handoff-contract.md` itself.
- Deciding the item-2 open question (whether `state-gate.sh` should grow
  mechanical path-ownership/DEPENDS-ON enforcement at all) — that is left
  as an explicit decision point for whoever picks this proposal up, per
  contract §11's own note that no mechanical check is required.
