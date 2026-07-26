---
status: final
---

# Role handoff contract (v2: blackboard/event model)

Authority document for how the seven role rulebooks — coding, qa,
feasibility, product, ops, review, verify — coordinate inside the target
repository each is working on. v1 modeled coordination as one-shot parcel
handoffs between adjacent roles; v2 replaces that with a shared blackboard
each role reads, writes its own record onto, and wakes from. This document
defines the shared record format; it does not itself change any of the
seven rulebooks. Landing this contract in each rulebook is separate, one
proposal per repo.

## 1. Common header

Every role record carries this frontmatter block in addition to whatever
role-specific fields section 2 requires:

```yaml
kind: <artifact kind string, see section 2>
subject: <stable identifier for the piece of work, shared by every role
          touching it>
produced_by: coding | qa | feasibility | product | ops | review | verify
upstream:
  - path: <repo-root-relative path>
    sha: <commit SHA the artifact was read at>
    acknowledged_sha: <optional; see section 4>
loop_state: <this role's own state-machine position; see section 2's
             per-kind loop_state vocabulary>
```

- `upstream` is a list; empty (`upstream: []`) for a record not derived from
  another role's artifact — a chain root. A chain-root record states its own
  `sha` (the commit that introduced the record itself) at write time; there
  is nothing to compare it against, so section 4's staleness rule is
  trivially satisfied for it and never fires against itself.
- `subject` is minted per section 5 and copied verbatim by every role
  touching the same piece of work.
- `loop_state` is this contract's field for that role's internal
  state-machine position (section 2 lists each role's vocabulary). A role's
  internal state machine remains its own business — this contract does not
  define its transitions — but the role must write its current state into
  `loop_state` at every transition it completes. `loop_state` is the shared
  truth other roles may depend on; a role's private notes about intermediate
  sub-steps are not, and are not required to appear here.

## 2. Artifact kind table (the blackboard's rows)

Every role writes exactly one status record onto the blackboard,
`docs/reports/records/<subject>/<role>.md`, plus zero or more per-item
sub-artifacts. All seven roles are sanctioned here, including product's and
coding's records, closing the trial's two unsanctioned-kind gaps.

| kind | produced by | path | `loop_state` vocabulary | required fields beyond common header |
|---|---|---|---|---|
| `hypothesis` | product | `docs/proposals/<date>-<slug>.md` | `idle,scoping,researching,hypothesis-registered,measuring,decided` | Background/Context, Problem Statement, Candidate Hypotheses, Known Risks, Goals/Success Metrics |
| `product-record` | product | `docs/reports/records/<subject>/product.md` | same as `hypothesis` | pointer to the governing `hypothesis`; running acceptance-criteria notes |
| `one-pager` | product | `product/one-pager.md` | n/a (standing doc, not per-subject) | Background/Context, Problem Statement, Candidate Hypotheses, Known Risks, Goals/Success Metrics |
| `opportunity-tree` | product | `product/opportunity-tree.md` | n/a (continuous interview log) | — |
| `build-proposal` | coding | `docs/proposals/<date>-build-<slug>.md` | `proposed,approved,landed` | `files:` (write-set freeze list), `## Request`, `## Constraints`, `## What will be done`, `## Out of scope` |
| `coding-record` | coding | `docs/reports/records/<subject>/coding.md` | same as `build-proposal`, plus `finding-response` sub-entries per item 4 | pointer to active `build-proposal`; commit shas landed |
| `qa-record` | qa | `docs/reports/records/<subject>/qa.md` (fully in-repo; see section 6) | `observed,reproducing,reproduced,handed-off,re-verifying,verified-fixed,not-a-defect,wont-fix` | intake profile, bug reports, regression records, run stats — all in-repo under this record's area |
| `feasibility-record` | feasibility | `docs/reports/records/<subject>/feasibility.md` | `idle,scoped,probing,verdict` | `market_argument_supplied: false`, `technical`/`prior_art`/`legal_regulatory`/`threat_model` (each `unresolved\|pass:<evidence>\|fail:<evidence>\|blocked:<evidence>`), `verdict: go\|no-go\|conditional` (required once `loop_state` reaches `verdict`), `measurement_design: <description or pointer>` |
| `spike-report` | feasibility | `docs/reports/records/<subject>/spikes/<spike-slug>.md` | n/a (closed report) | Spike Title, Description/Goal, Type, Timebox, Acceptance Criteria, Tasks, Outcomes, Recommendation, Open questions, Reversibility tag; fixture-N notation if fixtures are involved (records the fixture count it was authored against, so a downstream re-run can detect additions/removals) |
| `review-record` | review | `docs/reports/records/<subject>/review.md` | `idle,scoped,auditing,draft-reported,reported` | — |
| `verify-record` | verify | `docs/reports/records/<subject>/verify.md` | `idle,reproducing,reproduced,cleared` | what was attempted, what reproduced (if anything), reproduction evidence (repro steps, commit sha, run output) |
| `finding` | any role | inline block within the addressing role's own record | n/a | `requirement`, `verdict` (`Present\|Surface\|Absent\|Incorrect\|Unverifiable`), `evidence`, `rationale`, `spec_vs_built` (required only when `verdict: Incorrect`), `addressed_to: <role>`, `severity: blocking\|advisory` — see item 4 |
| `ops-record` | ops | `docs/reports/records/<subject>/ops.md` | `idle,readiness,rollout,steady,incident` | `error_budget: ok\|exhausted`, `postmortem: <pointer>`, `## Checklist` (`- item: <desc> \| status: yes\|no \| artifact: <url/path/config key>`) |
| `postmortem` | ops | `docs/reports/records/<subject>/postmortems/<incident-slug>.md` | n/a (closed report) | Impact, Actions taken during response, Root cause(s), Prevention follow-up (owner+tracking+closing-condition), Review (named human reviewer) |

`kind` parsing by any gate must tolerate a trailing comment on the line
(`kind: build-proposal  # re-scoped`); a regex anchored to end-of-line with
no comment tolerance is a gate defect, not a contract violation by the
record's author.

## 3. WAKES-ON: who wakes when the board changes

Each role's loop wakes when the board reaches one of its trigger
conditions, replacing v1's single accept/refuse-at-handoff moment.
Concurrent wakes are the normal case: a board change may satisfy more than
one role's row at once, and all of them proceed in parallel — this is where
the model's parallelism comes from, not an edge case.

| role | wakes on |
|---|---|
| feasibility | a new or changed `hypothesis` record appears on the board |
| coding | a feasibility `verdict: go`; a `qa-record` defect carrying a human is-this-a-defect verdict; a `finding` with `addressed_to: coding` |
| qa | any commit touching `src/`/`tests/` in the running system |
| review | any commit landed by coding |
| product | a qa or review outcome whose content questions the standing acceptance criteria |
| ops | a change landed (merged) that is ready to roll out |
| verify | coding and qa have both produced artifacts for a subject (first wake); again before landing, as a pre-land gate (second wake) |

**Who evaluates these rows.** No automated watcher exists yet in this
operating model. The human's session opens a role's rulebook when the board
shows that role's trigger satisfied — a human reads the board, matches it
against the table above, and opens the matching role. WAKES-ON tells the
human (or a future automated watcher, if one is built) *whom* to open; it is
not a claim that opening happens automatically today. This is the intended
narrowing of the human's job: carrying the table's judgment of "does the
board match this row," not carrying memory of what should happen next.

## 4. Consumption semantics

Replaces v1's ACCEPTS/refuse table with three separate questions, at the
right grain — v1 had one lever (accept/refuse a whole kind) and used it to
also answer "may this role even read that file," which conflated two
different concerns (see qa row below).

- **READ (broad).** The board exists to be read. Every role may read every
  other role's record, unconditionally, for context. Reading something is
  never itself a violation.
- **DEPENDS-ON (narrow, per role).** What a role's own conclusion is allowed
  to cite as its basis:
  - product depends on `feasibility-record` (a verdict causing it to react).
  - coding depends on `hypothesis`, `feasibility-record`, and `finding`
    blocks addressed to it.
  - qa's DEPENDS-ON list is empty. qa may READ `feasibility-record`'s
    `measurement_design` and any other record as advisory context, the same
    as any role — this is not a reading ban. But qa's verdict must be built
    from direct observation of the running system, never from another
    role's record. This is the direct-observation principle, restated as a
    DEPENDS-ON restriction rather than a refusal to open the file.
  - review depends on `build-proposal` (the change) to decide what should
    exist, and may READ `hypothesis`'s and `build-proposal`'s narrative
    sections freely for context on intent. What review may DEPEND ON for a
    `finding`'s `spec_vs_built` judgment is narrower: the finished change as
    built and the `build-proposal`'s stated `files:`/sections, not the
    hypothesis's aspirational narrative standing in for what was actually
    specified. Reading the narrative is allowed; building `spec_vs_built` on
    it alone is not.
  - ops depends on `build-proposal` (what merged) and `hypothesis` /
    `feasibility-record` (the measurement design).
  - verify depends on `coding-record`, `qa-record`, and `review-record` — it
    reads what was built, what qa already tried, and what review concluded,
    then goes looking for what none of them caught. It emits `finding`
    blocks per section 5, `addressed_to: coding`, with `severity: blocking`
    or `advisory`. A `verify` finding with `severity: blocking` is not
    overridden by a `review-record` in `loop_state: reported` with a clean
    verdict — review's and verify's verdicts are independent, and verify's
    blocking findings gate landing on their own terms, per this section's
    unchanged NEVER-OVERWRITE / ownership rule. `verify`'s contract entry
    enforces structure only — that a verify record exists, its WAKES-ON
    edges, and a blocking-finding channel back to coding — and does not
    dictate what counts as a defect; deciding what is a real defect is
    verify's own judgment.
- **NEVER OVERWRITE (unchanged from v1 §7).** Per-role write ownership
  (section 7 below) carries over without change. READ/DEPENDS-ON add
  semantics on top of an unchanged ownership rule; they do not loosen it.

## 5. The finding back-edge

Any role may post a `finding` addressed to any owning role via the board —
generalized from v1, where only review produced findings, to all six roles.

- `addressed_to: <role>` names the role that owns the fix.
- `severity: blocking | advisory`. `blocking` means loops that DEPEND ON the
  addressed role's output pause until the finding is resolved. `advisory`
  means downstream loops continue; the finding is context, not a gate.
- The addressed role's WAKES-ON list covers findings addressed to it (each
  row in section 3 already includes its role's finding trigger).
- **Response schema.** When the addressed role closes out a `finding`, its
  own record must carry a `finding-response` entry containing: the finding
  it responds to (a stable reference — record path plus finding
  identifier), the action taken or, if declined, the reason for declining,
  and — when code changed — proof of the fix (commit sha, targeted re-run
  result, or equivalent evidence). An entry missing any of these three parts
  does not close the finding.

## 6. Loop termination

- A wake is consumed by writing the resulting record entry (a `loop_state`
  change, a new `finding`, a `finding-response`, or equivalent). Writing
  nothing means the wake was not consumed.
- An unchanged board wakes no one. If a role's write leaves the board
  byte-identical to what a waking role already observed, no further wake
  fires from it.
- **qa↔coding cycle termination.** A `finding` from qa produces a
  `finding-response` from coding; coding's fix produces a new commit, which
  wakes qa again per section 3. This cycle terminates when a wake produces
  no new board change — i.e., qa observes the fix, and either verifies it
  (`loop_state: verified-fixed`, no new `finding`) or re-opens it with a new
  `finding` that itself constitutes a board change. A qa wake that results
  in neither a `verified-fixed` write nor a new `finding` is not a valid
  consumption of the wake and must not be treated as cycle-closing; but a
  wake that reproduces an *already-filed, unresolved* finding without
  adding new information is not a new board change either, and does not
  re-open the cycle. This is the rule that keeps qa↔coding ping-pong finite.
- **verify↔coding cycle termination.** Extends the above to verify: a
  `verify` wake is not a valid consumption unless it produces either a
  `cleared` `loop_state` (no unresolved reproduced findings) or a
  new/re-affirmed `finding`. A blocking finding resolves only when coding's
  `finding-response` supplies fix evidence that verify re-observes, or the
  human explicitly waives it under section 8's human-judgment seat.

## 7. `loop_state` authority

The board's `loop_state` field is the one piece of a role's state machine
that other roles may depend on. A role is free to run whatever internal
sub-states or scratch process it wants; none of that is visible or binding
to other roles unless reflected onto `loop_state`. A role must update
`loop_state` on the board at each transition it completes — a role that
completes a transition internally but leaves the board's `loop_state` stale
has not, for the purposes of this contract, completed the transition, since
no other role's WAKES-ON check can see it.

## 8. The human's seat

The human's role narrows to judgment points, named explicitly. Everything
else — which role runs next — is carried by WAKES-ON (section 3), not by a
human relaying a handoff.

- Minting or retiring a `subject` (see section 9's minting rule; retirement
  is the same act in reverse — no further role treats a retired subject's
  board as live).
- Verdict tokens this contract reserves for a human (e.g. qa's
  is-this-a-defect call).
- Resolving cross-role disputes that DEPENDS-ON rules (section 4) do not
  settle.
- Approving scope changes.

## 9. Minting `subject`

Any role may open a chain — not only product. Whichever role is first to
write an artifact for a piece of work mints `subject` as `<date>-<slug>`,
taken from the artifact it is itself about to write, and records it in its
own header. Minting is deterministic regardless of which role does it:
"derive it from the artifact you're writing," not "ask product."

Before minting, a role must search `docs/reports/records/*/` and
`docs/proposals/*` for an existing `subject` whose artifacts touch the same
files or describe the same named request, and adopt it verbatim if found.
Skipping this search is what splits one piece of work into two subject
directories.

**Remoteless-repo identifier fallback.** v1's `<owner>-<repo>` slug existed
only for the now-abolished `$QA_WORKSPACE` cross-repo path (section 10) and
is deleted along with it — no external workspace needs a per-repo
identifier anymore. Where any per-repo derived identifier is still needed
elsewhere in a rulebook (e.g. a local cache key), the naming rule is: use
the repo's directory name. This holds regardless of whether the repo has a
remote configured, so a remoteless repo never breaks the convention.

## 10. Where records live: the blackboard is fully in-repo

All role records live inside the target repository, at
`docs/reports/records/<subject>/<role>.md`, inside doctrine's `reports`
bucket. Every `path` entry in every `upstream` list is repo-root-relative.

**qa's evidence moves in-repo.** v1 kept qa's bulk evidence (intake
profile, run logs, regression history) in `$QA_WORKSPACE`, an external,
host-local, uncommitted tree, with only a thin pointer record left inside
the repo. That exception is abolished. qa's evidence — intake profile, bug
reports, regression records, run stats — now lives entirely inside the work
repo, under qa's own record area
(`docs/reports/records/<subject>/qa/**`, alongside `qa.md` itself). No
role's cross-role-visible status escapes the repo; there is no external
workspace path left for a future hunter to find qa's status having leaked
out of.

**`ops-record` tension, carried forward.** `ops-record` is rewritten in
place as current system state changes (steady, incident, error-budget), not
appended to as a dated record, unlike the rest of `reports`. This document
states the mismatch rather than papering over it; it does not invent a
seventh bucket to fit it.

## 11. Per-role path ownership (never-overwrite)

| role | writes |
|---|---|
| product | `docs/proposals/<date>-<slug>.md` (`kind: hypothesis`), `docs/reports/records/<subject>/product.md`, `product/one-pager.md`, `product/opportunity-tree.md` |
| coding | `docs/proposals/<date>-build-<slug>.md` (`kind: build-proposal`), `docs/reports/records/<subject>/coding.md` |
| qa | `docs/reports/records/<subject>/qa.md`, `docs/reports/records/<subject>/qa/**` (all in-repo, section 10) |
| feasibility | `docs/reports/records/<subject>/feasibility.md`, `docs/reports/records/<subject>/spikes/<spike-slug>.md` |
| review | `docs/reports/records/<subject>/review.md` (including inline `finding` blocks) |
| ops | `docs/reports/records/<subject>/ops.md`, `docs/reports/records/<subject>/postmortems/<incident-slug>.md` |
| verify | `docs/reports/records/<subject>/verify.md` (including inline `finding` blocks) |

A role finding an existing record already present at a path section 11
assigns to a different role must refuse to write there and report the
conflict to the user, rather than overwriting or merging into it silently.

`docs/proposals/` stays shared between product and coding, disambiguated by
filename tag: coding's `build-proposal` filenames carry `-build-`
(`<date>-build-<slug>.md`), distinct on its face from product's
`<date>-<slug>.md`.

**Carried over, unenforced (v1 §7's flagged tension).** warrant's
`scope-gate.sh` allows any write under `docs/` unconditionally, regardless
of an approved proposal's `files:` write set. Nothing mechanical stops one
role from writing into another role's record path. This table is the
normative rule, not a description of what warrant already enforces;
enforcing it is each role's own rulebook's responsibility (a
`placement-gate.sh`-style check), same as v1. This proposal does not add
the gate.

## 12. Staleness rule

Before acting on a handed-over artifact, a role compares each `upstream`
entry's recorded `sha` against the current commit touching `path`
(`git log -1 --format=%H -- <path>`). If they differ, the role stops and
asks the user:

> `<path>` has changed since this record was written (recorded at `<sha>`,
> now at `<current-sha>`). Proceed on the version at `<sha>`, or re-confirm
> against the current version?

The role does not decide this itself and does not silently re-read and
continue. It waits for the user's answer.

**Chain-root exemption.** An `upstream: []` record has nothing to compare
against; it states its own `sha` at write time and the check is trivially
satisfied — this is not a gap, it is the defined behavior for the first
record in a chain.

**When it fires.** Exactly once per role-entry, at the point the role
begins acting on a handed-over artifact, before work starts. It does not
re-fire mid-build; a change landing in `path` while the role is already
working is caught on the *next* entry into that artifact, not immediately —
deliberate, so the check does not collide with warrant's rule against
pausing mid-build.

**First-read `acknowledged_sha`.** On a role's first read of an upstream
artifact there is no prior `acknowledged_sha` to compare against, so the
full staleness prompt above applies exactly once, unconditionally.
`acknowledged_sha` is written only *after* that first answer — it is
omitted from the `upstream` entry until then, never populated with a guess
or a placeholder.

**Acknowledging a sha instead of re-confirming it.** Once the user has
answered the prompt for a given `path`/`sha` pair, the role records
`acknowledged_sha: <sha>` next to that entry. On a later re-entry, if the
current sha at `path` equals the recorded `acknowledged_sha`, the role
treats it as already confirmed and does not re-prompt, even though it
differs from the original `sha`. If the current sha matches neither `sha`
nor `acknowledged_sha`, the full prompt fires again.

## 13. Commit trailer requirement

Every commit a role's rulebook makes as part of landing a record or a
build must carry the trailer format its own rulebook's hook enforces
(e.g. a `Subject:` or `Kind:` trailer identifying the record the commit
belongs to). This requirement is documented here, in the contract body,
rather than being discoverable only via a hook rejection at commit time.
The exact trailer keys are each rulebook's own concern; this contract only
requires that some machine-checkable trailer identifying `subject` and
`kind` be present, and that it be stated in the rulebook's own docs, not
left implicit.

## 14. Mechanical checks are not substantive checks

- **`kind` is self-declared and unverified.** No rulebook adopting this
  contract checks that a declared `kind` matches the artifact's actual
  content. WAKES-ON and DEPENDS-ON filter on the declared value only.
- **Sha equality (section 12) proves a file did not move — nothing more.**
  A matching sha means the bytes at `path` are byte-identical to what was
  read; it says nothing about whether the conclusion drawn from it still
  holds.
- **Section 11's path ownership is a table, not a gate.** No mechanical
  check in this contract enforces it; a role staying inside its own path is
  a structural guarantee this contract's prose implies but that no hook
  actually provides unless the role's own rulebook adds one.

A passing structural check (kind matched, sha matched, wake fired) clears a
role to proceed under this contract; it is not evidence the artifact is
sound. That judgment stays with the role reading it.
