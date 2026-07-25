---
status: landed
files:
  - product-agent-rulebook/product-cycle/hooks/transition-rules.md
  - product-agent-rulebook/product-cycle/hooks/inject-transition-rules.sh
  - product-agent-rulebook/product-cycle/hooks/hooks.json
  - product-agent-rulebook/product-cycle/hooks/state-gate.sh
  - product-agent-rulebook/product-cycle/hooks/capture-approval.sh
  - product-agent-rulebook/.gitignore
  - feasibility-agent-rulebook/feasibility-cycle/hooks/transition-rules.md
  - feasibility-agent-rulebook/feasibility-cycle/hooks/inject-transition-rules.sh
  - feasibility-agent-rulebook/feasibility-cycle/hooks/hooks.json
  - feasibility-agent-rulebook/feasibility-cycle/hooks/state-gate.sh
  - feasibility-agent-rulebook/feasibility-cycle/hooks/capture-approval.sh
  - feasibility-agent-rulebook/.gitignore
  - review-agent-rulebook/review-cycle/hooks/transition-rules.md
  - review-agent-rulebook/review-cycle/hooks/inject-transition-rules.sh
  - review-agent-rulebook/review-cycle/hooks/hooks.json
  - review-agent-rulebook/review-cycle/hooks/state-gate.sh
  - review-agent-rulebook/review-cycle/hooks/capture-approval.sh
  - review-agent-rulebook/.gitignore
  - ops-agent-rulebook/ops-cycle/hooks/transition-rules.md
  - ops-agent-rulebook/ops-cycle/hooks/inject-transition-rules.sh
  - ops-agent-rulebook/ops-cycle/hooks/hooks.json
  - ops-agent-rulebook/ops-cycle/hooks/state-gate.sh
  - ops-agent-rulebook/ops-cycle/hooks/capture-approval.sh
  - ops-agent-rulebook/.gitignore
  - docs/specs/agent-roles.md
---

# Conversational state machine: remove approval-token minting, enforce transitions as a read prose table

## Intent

`docs/specs/agent-roles.md` currently specifies, for `product`, `feasibility`,
and `ops`, a human-gated transition ("gated", requiring "a recorded approval
token... from the user's own turn"). Each of the four new rulebooks
(`product-agent-rulebook`, `feasibility-agent-rulebook`,
`review-agent-rulebook`, `ops-agent-rulebook`) implements this today with a
`capture-approval.sh` `UserPromptSubmit` hook that regexes the user's raw
prompt text to mint a token file, and a `state-gate.sh` `PreToolUse` hook that
refuses the gated transition unless a matching token exists.

This proposal removes the token mechanism entirely. Reading whether the user
approved, rejected, or redirected a transition is a semantic judgment — the
model already makes it correctly by reading conversation context, and a regex
over raw prompt text cannot do better than the model at that judgment; it can
only reject phrasings the regex author didn't anticipate (the qa-agent-rulebook
review documents this exact failure mode: a legitimate verdict phrased outside
the regex's anticipated set is silently dropped with no feedback to the human).
In place of token-minting, procedure is enforced the way
`coding-agent-rulebook`'s `doctrine` plugin was forced to fix its own
compliance problem: not as a paragraph the model may or may not apply, but as
a literal condition→destination table injected into every prompt. Doctrine's
own README reports the concrete effect of that rewrite — a prose-only
directive ("does this turn owe documentation") produced 0 of 6 correct runs;
the same rule rewritten as an explicit table produced 3 of 3. This proposal
carries that lesson into all four new rulebooks as a first-class design
element, not an afterthought.

## Constraints that change what gets built

- **Semantic judgment belongs to the model, not a hook.** No hook in any of
  the four repos mints an approval token or otherwise decides user intent by
  regex. The model reads approval, rejection, or course-correction from
  conversation context, the same way it already reads everything else in the
  turn.
- **Procedure is prose, but table-shaped, and injected every turn.** Each
  repo's `UserPromptSubmit` hook injects the role's transition rules on every
  prompt, at the same priority `coding-agent-rulebook`'s `warrant/directive.sh`
  uses for its own procedural directive. The rules are written as a
  condition→allowed-transition table — current state, legal transitions from
  it, which of those require the user to have said something, and what the
  model must do before transitioning — not as paragraphs, because the ablation
  above is the only measured evidence available in this codebase on which
  shape actually changes model behavior.
- **The table is data, not prose duplicated in two places.** One file per repo
  (`transition-rules.md`) is the single source. The injector hook reads it
  verbatim into the `UserPromptSubmit` payload; `state-gate.sh` parses the same
  file to know which `(from, to)` pairs exist. No table is hand-copied into
  the hook script or the gate script.
- **The gate shrinks to two questions.** `state-gate.sh` no longer touches
  approval or tokens at all. For a given write, it asks only: (1) does the
  resolved target path reach this role's state file, applying the same
  resolved-path rule (not tool-name matching) already landed in
  `docs/proposals/2026-07-26-state-gate-path-resolution.md`; and if so, (2) is
  the resulting `(from, to)` transition present in `transition-rules.md`.
  Everything that does not resolve to the state file is allowed through
  unconditionally. This directly resolves the regression in
  `docs/reports/2026-07-26-hunt-state-gate-path-resolution.md`: ops-cycle's
  prior global fail-closed default denied ordinary evidence-gathering `Bash`
  commands that never named the state file at all, because the gate's default
  posture was "deny unless proven safe" rather than "allow unless it reaches
  the guarded file." Shrinking the gate's jurisdiction to the state file
  removes that failure mode by construction, not by adding an exception list.
- **The record carries the human, not the gate.** On every transition the
  model appends one line to the state file naming the specific user utterance
  it read as the transition's basis (a quote or a close paraphrase, not "user
  approved"). Nothing mechanically enforces that this line is present or
  accurate — it exists so a reader outside the session, later, can see what
  the transition rested on. This mirrors `coding-agent-rulebook`'s `dispatch`
  plugin, which requires quoting the user's approval in a PR comment on
  exactly the same "asserted, not gated" basis.
- **Per-repo independence, unchanged from today.** Each of the four rulebooks
  implements its own `transition-rules.md`, its own injector hook, its own
  `state-gate.sh`. No shared file, no cross-repo import, no shared directory —
  the same standing constraint `docs/specs/agent-roles.md` Part 2 already
  states for these repos never reading each other.
- **`coding-agent-rulebook` and `qa-agent-rulebook` are untouched.** Neither
  repo is read, edited, or referenced as a target of this proposal beyond
  being cited as prior art above. `qa-agent-rulebook`'s own token mechanism
  (`signoff/hooks/capture-verdict.sh`) is explicitly out of scope; this
  proposal does not argue it should change, only that the four new,
  not-yet-battle-tested rulebooks should not copy it.
- **`docs/specs/agent-roles.md` moves in the same unit.** Its Part 2
  ("Answering a gate... Approval comes from the user's own turn... the same
  rule `qa-cycle`'s verdict tokens enforce") and each of `product`'s,
  `feasibility`'s, and `ops`'s per-role "Rejection rule" prose describing an
  "approval token" become false the instant the token mechanism is deleted, so
  the spec is edited alongside the code, not after.

## What will be done (per repo)

Each of the four repos gets the identical set of five changes, applied to its
own `<role>-cycle/hooks/` directory (verified to actually contain
`capture-approval.sh`, `state-gate.sh`, and `hooks.json` today in all four:
`product-agent-rulebook/product-cycle/hooks/`,
`feasibility-agent-rulebook/feasibility-cycle/hooks/`,
`review-agent-rulebook/review-cycle/hooks/`,
`ops-agent-rulebook/ops-cycle/hooks/`):

1. **New file `<role>-cycle/hooks/transition-rules.md`** — the condition→
   transition table for that role, one row per legal `(from, to)` pair, each
   row marked whether it requires the user to have said something in this
   turn and what the model must do first (e.g., for `product`:
   `hypothesis-registered -> measuring` marked "requires user approval of the
   registered metric/threshold/decision-rule package, in this turn" —
   language drawn straight from the transition tables already in
   `docs/specs/agent-roles.md` Part 3, minus the token clause).
2. **New file `<role>-cycle/hooks/inject-transition-rules.sh`**, replacing
   `capture-approval.sh`'s role in `hooks.json` — a `UserPromptSubmit` script
   that reads `transition-rules.md` and emits it as a fenced context block on
   every prompt, following the existing `X_OFF` kill-switch idiom
   (`coding-agent-rulebook`'s nine verbatim copies) so it can be disabled the
   same way every other directive hook in this org already is.
3. **Modified `<role>-cycle/hooks/hooks.json`** — the `UserPromptSubmit` entry
   currently pointing at `${CLAUDE_PLUGIN_ROOT}/hooks/capture-approval.sh` is
   repointed at `${CLAUDE_PLUGIN_ROOT}/hooks/inject-transition-rules.sh`; the
   `PreToolUse` entry for `state-gate.sh` is unchanged in matcher shape
   (`Write|Edit|NotebookEdit|Bash`, confirmed present in
   `product-agent-rulebook/product-cycle/hooks/hooks.json` today and assumed
   identical in the other three pending their own read, since all four were
   built from the same template per the prior reviews).
4. **Modified `<role>-cycle/hooks/state-gate.sh`** — all token-lookup logic
   (locating, validating, and requiring a token file bound to `(item, from,
   to)`) is deleted. The gate's remaining logic is: resolve the tool call's
   target path; if it does not resolve to this role's state file, allow
   unconditionally; if it does, parse `transition-rules.md` for the
   `(current-status, attempted-status)` pair and allow only if that row
   exists in the table, denying otherwise with a message naming the missing
   row.
5. **Deleted file `<role>-cycle/hooks/capture-approval.sh`** and its
   gitignored token directory line in that repo's `.gitignore` — confirmed
   present as `.product-cycle/` in `product-agent-rulebook/.gitignore` today;
   the equivalent line (`.feasibility-cycle/`, `.review-cycle/`,
   `.ops-cycle/`, by the same naming convention) is removed from the other
   three repos' `.gitignore` files once their exact line text is confirmed at
   build time.

`docs/specs/agent-roles.md` — Part 2's "Answering a gate" paragraph is
rewritten to drop the approval-token sentence and state instead that approval
is read from context and recorded, not minted; each of `product`'s,
`feasibility`'s, and `ops`'s "Rejection rule" prose in Part 3 has its "a
recorded approval token... exists" clause replaced with "the transition
appears in that role's `transition-rules.md`, and the state file records the
user utterance the model read as its basis." `review`'s and `coding`'s and
`qa`'s sections are otherwise untouched, since `review` never had a gated
transition and `coding`/`qa` are out of scope.

## Out of scope

- `coding-agent-rulebook` and `qa-agent-rulebook`: not read, not edited.
- `qa-agent-rulebook`'s `signoff` token mechanism: not modified, not deprecated
  by this proposal; it is cited only as contrast.
- The path-resolution mechanics of `state-gate.sh` itself (how a `Bash` target
  is resolved to a canonical path): governed entirely by
  `docs/proposals/2026-07-26-state-gate-path-resolution.md`, referenced here,
  not re-specified.
- Any change to `product-cycle/skills/hypothesis-testing/SKILL.md`,
  `feasibility-cycle/skills/feasibility-cycle/SKILL.md`,
  `review-cycle/skills/review-cycle/SKILL.md`, or
  `ops-cycle/skills/readiness-checklist/SKILL.md` — none of the four skills
  files is touched; the transition mechanism lives entirely in `hooks/`.
- Bootstrapping any new state file, project, or example run — this proposal
  changes the mechanism, not any live data.
- Any change to the `review` role's transition table shape beyond removing an
  approval-token reference it never actually had (per `docs/specs/agent-roles.md`,
  `review` has no `gated` row in its Part 3 table already).

## How we will know it worked

- `grep -r capture-approval` across all four `*-agent-rulebook/*-cycle/hooks/`
  directories returns nothing, and no `.gitignore` in those four repos still
  references a token directory.
- Each repo's `hooks.json` `UserPromptSubmit` entry resolves to
  `inject-transition-rules.sh`, and a manual prompt submission shows the
  role's transition table appended to context.
- `state-gate.sh` in each repo, read start to end, contains no token-file
  path construction, no token matching logic, and exactly one table lookup
  against `transition-rules.md`.
- A write that never resolves to the role's state file (an evidence-gathering
  `Bash` command, an unrelated file edit) is allowed through with no gate
  message in all four repos — directly closing the ops-cycle regression in
  `docs/reports/2026-07-26-hunt-state-gate-path-resolution.md`.
- A write that resolves to the state file with an illegal `(from, to)` pair is
  denied, citing the missing row, in all four repos.
- `docs/specs/agent-roles.md` no longer contains the string "approval token"
  anywhere in Part 2 or Part 3.

## What did not work

- Expected every repo's transition table to describe a graph reachable from a clean checkout; product-agent-rulebook has no row with `from = (none)`, nothing creates `product/state.md`, and the gate refuses the write that would create it while the injector refuses to proceed without it — a permanent deadlock, reproduced by the before-landing hunter. See docs/reports/2026-07-26-hunt-conversational-state-machine.md.
- review-agent-rulebook and ops-agent-rulebook also have no bootstrap row; they do not deadlock today only because their state files already exist in the working copy. feasibility-agent-rulebook is the only one that handled this, via a synthetic `none` state.
- product-agent-rulebook's state file moved from per-proposal frontmatter `status` to `product/state.md` field `stage` to match the other three; this is a change to existing behaviour, not just an addition.
