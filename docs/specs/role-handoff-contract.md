---
status: final
---

# Role handoff contract (v2: blackboard/event model)

Authority document for how the nine role rulebooks — coding, qa,
feasibility, product, ux-design, ops, review, verify, reflect — coordinate inside the
target repository each is working on. v1 modeled coordination as one-shot
parcel handoffs between adjacent roles; v2 replaces that with a shared
blackboard each role reads, writes its own record onto, and wakes from. This
document defines the shared record format; it does not itself change any of
the nine rulebooks. Landing this contract in each rulebook is separate,
one proposal per repo.

## 1. Common header

Every role record carries this frontmatter block in addition to whatever
role-specific fields section 2 requires:

```yaml
kind: <artifact kind string, see section 2>
subject: <stable identifier for the piece of work, shared by every role
          touching it>
produced_by: coding | qa | feasibility | product | ux-design | ops | review | verify | reflect
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
sub-artifacts. All nine roles are sanctioned here, including product's and
coding's records, closing the trial's two unsanctioned-kind gaps.

| kind | produced by | path | `loop_state` vocabulary | required fields beyond common header |
|---|---|---|---|---|
| `hypothesis` | product | `docs/proposals/<date>-<slug>.md` | `idle,scoping,researching,hypothesis-registered,measuring,decided` | Background/Context, Problem Statement, Candidate Hypotheses, Known Risks, Goals/Success Metrics |
| `product-record` | product | `docs/reports/records/<subject>/product.md` | same as `hypothesis`, plus `scope-proposed,scope-approved` — see section 19 | pointer to the governing `hypothesis`; running acceptance-criteria notes; scope statement per section 19 once `loop_state` reaches `scope-proposed` |
| `one-pager` | product | `product/one-pager.md` | n/a (standing doc, not per-subject) | Background/Context, Problem Statement, Candidate Hypotheses, Known Risks, Goals/Success Metrics |
| `opportunity-tree` | product | `product/opportunity-tree.md` | n/a (continuous interview log) | — |
| `build-proposal` | coding | `docs/proposals/<date>-build-<slug>.md` | `proposed,approved,landed` | `files:` (write-set freeze list), `## Request`, `## Constraints`, `## What will be done`, `## Out of scope` |
| `coding-record` | coding | `docs/reports/records/<subject>/coding.md` | same as `build-proposal`, plus `finding-response` sub-entries per item 4, plus `findings-resolved` per section 15 | pointer to active `build-proposal`; commit shas landed; `resolved_findings:` list (when applicable) — see section 15 |
| `qa-record` | qa | `docs/reports/records/<subject>/qa.md` (fully in-repo; see section 6) | `observed,reproducing,reproduced,handed-off,re-verifying,verified-fixed,not-a-defect,wont-fix` | intake profile, bug reports, regression records, run stats — all in-repo under this record's area |
| `feasibility-record` | feasibility | `docs/reports/records/<subject>/feasibility.md` | `idle,scoped,probing,verdict`, plus `scope-proposed,scope-approved` when this record is the subject's front record — see section 19 | `market_argument_supplied: false`, `technical`/`prior_art`/`legal_regulatory`/`threat_model` (each `unresolved\|pass:<evidence>\|fail:<evidence>\|blocked:<evidence>`), `verdict: go\|no-go\|conditional` (required once `loop_state` reaches `verdict`), `measurement_design: <description or pointer>`; `technical` enumerates the deploy/runtime config surface (env var names the build must honor) whenever it is foreseeable at feasibility time — see section 17 |
| `spike-report` | feasibility | `docs/reports/records/<subject>/spikes/<spike-slug>.md` | n/a (closed report) | Spike Title, Description/Goal, Type, Timebox, Acceptance Criteria, Tasks, Outcomes, Recommendation, Open questions, Reversibility tag; fixture-N notation if fixtures are involved (records the fixture count it was authored against, so a downstream re-run can detect additions/removals) |
| `ux-design-record` | ux-design | `docs/reports/records/<subject>/ux-design.md` | `idle,drafting,reviewed` | pointer to the governing `hypothesis`/`product-record`; screen/flow/wireframe specs or pointers to them |
| `review-record` | review | `docs/reports/records/<subject>/review.md` | `idle,scoped,auditing,draft-reported,reported` | `closed_checks:` list keyed to the reviewed code sha — see section 16 |
| `verify-record` | verify | `docs/reports/records/<subject>/verify.md` | `idle,reproducing,reproduced,cleared` | what was attempted, what reproduced (if anything), reproduction evidence (repro steps, commit sha, run output); `closed_checks:` list keyed to the reviewed code sha — see section 16 |
| `finding` | any role | inline block within the addressing role's own record | n/a | `requirement`, `verdict` (`Present\|Surface\|Absent\|Incorrect\|Unverifiable`), `evidence`, `rationale`, `spec_vs_built` (required only when `verdict: Incorrect`), `addressed_to: <role>`, `severity: blocking\|advisory` — see item 4 |
| `ops-record` | ops | `docs/reports/records/<subject>/ops.md` | `idle,readiness,rollout,steady,incident` | `error_budget: ok\|exhausted`, `postmortem: <pointer>`, `## Checklist` (`- item: <desc> \| status: yes\|no \| artifact: <url/path/config key>`); `## Deploy-config` REQUIRED whenever `feasibility-record` did not enumerate the deploy/runtime config surface — see section 17 |
| `postmortem` | ops | `docs/reports/records/<subject>/postmortems/<incident-slug>.md` | n/a (closed report) | Impact, Actions taken during response, Root cause(s), Prevention follow-up (owner+tracking+closing-condition), Review (named human reviewer) |
| `reflect-record` | reflect | `docs/reports/records/<subject>/reflect.md` | `idle,reflecting,candidate-round-done,round-done` | pointer to the subject's other role records read; what went well, what failed, what pattern should change next time |

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
| coding | a feasibility `verdict: go`; a `qa-record` defect carrying a human is-this-a-defect verdict; a `finding` with `addressed_to: coding`; a `ux-design-record` reaching `loop_state: reviewed` — **all four triggers are gated by section 19's approval gate on a subject's FIRST build wake: none of them may wake coding into a subject's first build unless that subject's front record already shows `loop_state: scope-approved`.** Re-wakes on a subject already past its first build (e.g. a fix for a later finding) are unaffected — the precondition binds only the first entry into build for the subject. |
| qa | any commit touching `src/`/`tests/` in the running system |
| review | any commit landed by coding |
| ux-design | a new or changed `product-record` (or `hypothesis`, for a chain-root case) appears on the board |
| product | a qa or review outcome whose content questions the standing acceptance criteria |
| ops | a change landed (merged) that is ready to roll out |
| verify | coding and qa have both produced artifacts for a subject (first wake); again before landing, as a pre-land gate (second wake) |
| reflect | a subject's work has landed and verify and/or review have concluded (a `verify-record` reaching `cleared`, or a `review-record` reaching `reported`) |

**Resolved-finding re-verify edge.** A role that raised a blocking `finding`
also wakes when the addressed role's own record reaches
`loop_state: findings-resolved` with a `resolved_findings` entry naming the
finder's record path and the finder-record sha it addresses: finding-raised
-> (fix) -> findings-resolved -> re-verify. Like every WAKES-ON row, this
edge is human-consulted, never automated — see section 15.

**Who evaluates these rows.** No automated watcher exists yet in this
operating model. The human's session opens a role's rulebook when the board
shows that role's trigger satisfied — a human reads the board, matches it
against the table above, and opens the matching role. WAKES-ON tells the
human (or a future automated watcher, if one is built) *whom* to open; it is
not a claim that opening happens automatically today. This is the intended
narrowing of the human's job: carrying the table's judgment of "does the
board match this row," not carrying memory of what should happen next.

**Round-end value-gates edge.** A subject reaching candidate round-done wakes
the human to run section 18's two value gates before round-done may be set:
candidate-round-done -> (gates A and B run) -> round-done. Like every wake in
this table, this edge is human-consulted, never automated — see section 18.

**Pre-work approval-gate edge.** A subject's front record reaching
`loop_state: scope-proposed` wakes the human to review it and, on approval,
set `loop_state: scope-approved`: scope-proposed -> (human review) ->
scope-approved. Like every wake in this table, this edge is human-consulted,
never automated, and it is the ONLY path to `scope-approved` — no role may
set that state on its own or any other role's record. See section 19.

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
  - ux-design depends on `hypothesis` and `product-record` (the accepted
    problem framing its screens/flows answer). `ux-design`'s contract entry
    enforces structure only — that a `ux-design-record` exists per subject,
    its WAKES-ON edge after product, and that it feeds coding on reaching
    `loop_state: reviewed` — and does not dictate what counts as good
    design; that judgment is ux-design's own.
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
  - reflect depends on the subject's other role records (`coding-record`,
    `qa-record`, `review-record`, `verify-record`, and any others present)
    and any `finding` blocks addressed to or from them — the retrospective
    material it reads to produce its retro. `reflect`'s contract entry
    enforces structure only — that a `reflect-record` exists per subject,
    its WAKES-ON edge after verify/review conclude, and that it may emit
    `finding` back-edges at `severity: advisory` — and does not dictate
    what the retro concludes; that judgment is reflect's own.
- **NEVER OVERWRITE (unchanged from v1 §7).** Per-role write ownership
  (section 7 below) carries over without change. READ/DEPENDS-ON add
  semantics on top of an unchanged ownership rule; they do not loosen it.

## 5. The finding back-edge

Any role may post a `finding` addressed to any owning role via the board —
generalized from v1, where only review produced findings, to all nine roles.

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
- Approving scope changes, including the pre-work approval gate that moves
  a subject's front record from `scope-proposed` to `scope-approved`
  before any building role's first wake on that subject — see section 19.
- Running section 18's two round-end value gates and setting a subject's
  `round-done` state — required before `round-done` may be set, never
  automated.

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
| ux-design | `docs/reports/records/<subject>/ux-design.md` |
| review | `docs/reports/records/<subject>/review.md` (including inline `finding` blocks) |
| ops | `docs/reports/records/<subject>/ops.md`, `docs/reports/records/<subject>/postmortems/<incident-slug>.md` |
| verify | `docs/reports/records/<subject>/verify.md` (including inline `finding` blocks) |
| reflect | `docs/reports/records/<subject>/reflect.md` (including inline `finding` blocks) |

A role finding an existing record already present at a path section 11
assigns to a different role must refuse to write there and report the
conflict to the user, rather than overwriting or merging into it silently.

`docs/proposals/` stays shared between product and coding, disambiguated by
filename tag: coding's `build-proposal` filenames carry `-build-`
(`<date>-build-<slug>.md`), distinct on its face from product's
`<date>-<slug>.md`.

**Section 21 grant.** Each role additionally owns, in the target project,
the specific `docs/decisions/<date>-<slug>.md`, `docs/reports/<date>-<slug>.md`,
and `docs/specs/` entries that role itself authors under section 21's
trigger — never the directory as a whole, only the file(s) it writes there.
This mirrors this table's existing `records/<subject>/<role>.md` grain: a
role that makes a hard-to-reverse choice owns its own
`docs/decisions/<date>-<slug>.md`; a role that produces a measurement,
benchmark, test run, or investigation owns its own
`docs/reports/<date>-<slug>.md`; a role whose work is system design tied to
the code owns its own `docs/specs/` entry. Two roles never collide on the
same file because each owns only the file it itself authored. This grant is
what makes section 21's placement obligation satisfiable under this
section's ownership scoping.

**Handbook grant (component-scoped shared-write).** `docs/handbooks/<component>.md`
is owned by the component, not by a single first-author role: any role that
changes that component's operational surface (an environment variable,
config key, dependency, migration, or run/setup/deploy step, per section
21's handbook trigger) may create or update that component's handbook.
This is deliberately different from this section's other grants, which are
single-author write-once; a handbook is a living current-state doc that
must track whichever role most recently touched the component's
operational surface, per section 21's write-time maintenance rule.
`<component>` itself is derived, not chosen, and creating a new handbook
file requires a search for an existing one first — see section 21's
"Deriving `<component>`" and "Search before write" paragraphs.

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

## 15. Finding-resolution handshake

Section 5 defines how a `finding` is raised and how the addressed role's
`finding-response` closes it out. It does not define how the role that
*raised* the finding learns to re-verify it — this section does.

- The fixer (the role that addressed the finding) records resolution in its
  **own** record only. Per section 4's NEVER-OVERWRITE rule, the fixer must
  never write to the finder's record — resolution is signaled forward, not
  written backward.
- The fixer's record carries a `resolved_findings:` list, each entry naming
  the finder record's path and the finder-record sha it addresses:

  ```yaml
  resolved_findings:
    - finder_path: <path to the finder's record>
      finder_sha: <sha of the finder's record at the finding it addresses>
  ```

- The fixer sets `loop_state: findings-resolved` on its own record when it
  writes a `resolved_findings` entry. This is in addition to, not instead
  of, the `finding-response` entry section 5 already requires.
- **Wake edge.** finding-raised -> (fix) -> `findings-resolved` -> re-verify.
  The finder is re-woken to re-verify, per section 3's resolved-finding
  edge. Like all wakes in this contract, this edge is human-consulted, not
  automated: the human sees `loop_state: findings-resolved` on the board and
  opens the finder's role to re-check.
- Re-verification itself is the finder's own judgment (per section 4's
  per-role DEPENDS-ON rules for that role); reaching `findings-resolved`
  clears the fixer's side of the handshake, it does not itself close the
  finding — only the finder's re-verification does that.

## 16. Closed-checks cite-and-skip (verify/review division of labor)

verify (adversarial) and review (5-lens) both read the same built code and
can re-derive the same conclusions blind to each other's work. This section
gives them a hand-off mechanism, without turning either into a rubber stamp
for the other.

- A role's record declares which checks/lenses/probes it CLOSED, via a
  `closed_checks:` list keyed to the exact code sha it closed them on:

  ```yaml
  closed_checks:
    - check: <lens/probe name>
      code_sha: <commit sha of the code this check was closed against>
  ```

- A downstream role MAY cite-and-skip a check another role already closed —
  citing the `closed_checks` entry instead of re-deriving it — **only when**
  the closing entry's `code_sha` equals the code sha currently under review.
  A check closed on a different sha does not count as closed; the code
  changed since, so the downstream role MUST run it itself.
- Any check not present in a prior role's `closed_checks` at the current
  code sha MUST still be run by the downstream role. This section is not a
  mandate to skip — it is a mechanism to avoid blind re-derivation of checks
  someone has already closed on the exact code being looked at.
- This does not loosen section 4's independence rule: a `verify` finding
  with `severity: blocking` is still not overridden by a clean
  `review-record`, and vice versa. Citing a closed check narrows what must
  be re-derived; it does not merge the two roles' verdicts.

## 17. Deploy-config ownership

No role owned naming deploy/runtime config (e.g. `PORT` and other env var
names the build must honor) prior to this section, which let it be invented
unilaterally wherever it was first needed. This section assigns ownership.

- **Default: feasibility owns it when foreseeable.** feasibility's
  `technical` field (section 2's `feasibility-record` row) enumerates the
  deploy/runtime config surface — the env var names and their meaning — when
  that surface is foreseeable at feasibility time. When feasibility's record
  states it, that record is the authority coding and ops build against.
- **Fallback: ops's REQUIRED deploy-config section.** When feasibility did
  not foresee a piece of the deploy-config surface, `ops-record`'s
  `## Deploy-config` section (section 2's `ops-record` row) is REQUIRED and
  becomes the authority for the config it names. This is a fallback, not a
  parallel default — ops only originates naming for what feasibility could
  not have foreseen.
- Whichever record does the naming, the other role's DEPENDS-ON reading of
  it (section 4) is unchanged: this section assigns naming authority, it
  does not add a new DEPENDS-ON edge.

## 18. Round-end value gates

A subject's round is not done merely because every role produced its
record. Two standing goals of this whole system — that the multi-role
procedure actually improves the deliverable, and that the git records alone
let a zero-context reader pick the work back up — are not guaranteed by
following the process; they must be MEASURED as outcomes at round end, not
assumed from process compliance. This section defines the two gates and the
round-done state they gate.

**(A) Procedure-value gate.** A role or handoff mechanism earns its place
only if removing it would measurably worsen the deliverable. At round end,
each role/mechanism that ran during the round is judged: did it change the
outcome or catch something real — cite the evidence (a bug caught, a
decision a later reader needed, a genuine handoff) — or did it only produce
a record because the process said to? Anything that cannot show it changed
the outcome is marked `ritual` for that round. Persisting `ritual` across
rounds is a defect the next contract revision must remove or convert to
real value. This gate never asserts "the step was performed" — it asserts
"the step earned its keep."

**(B) Blind-onboarding gate.** Before a round is declared done, an agent
with ZERO session context, given only the repository, must (1) reconstruct
what was asked/built/decided for the round's subject from records alone,
and (2) state what to do next and act on it — recording every stuck point,
contradiction, or unverifiable claim it hits along the way. The round
passes only if a no-context reader can both reconstruct AND continue
without out-of-band help; any stuck point is a records defect to fix, not a
gate to route around.

**(C) `round-done` definition and trigger.** A subject reaches `round-done`
when its `reflect-record` (section 2) — the last record to act in a round —
has its `loop_state` set to `round-done`, from `candidate-round-done`, the
same two states named in section 3's round-end value-gates edge. Gates A
and B above are a REQUIRED
human-consulted judgment-point that must fire BEFORE `round-done` may be
set — registered per section 3's round-end value-gates edge and section 8's
human's-seat entry, named in the structure exactly like every other
handoff. This stays human-routed: the human runs the gates and sets
`round-done`; it is NOT an automated watcher. A `round-done` set without
both gates having fired is a contract violation the structure can point to.

**Mechanism is out of scope.** How a round PASSES these gates — sha
conventions, single-source-of-truth numbering, or any other concrete
mechanism — is out of scope for this section. Passing the gate is what
matters; the mechanism is each round's own choice.

## 19. Pre-work approval gate

Building work — coding, or any role producing the subject's primary
deliverable — must not start on a subject until a human has approved a
recorded scope statement. This section defines the gate; section 3's
pre-work approval-gate edge and the amended coding row wire it into
WAKES-ON.

- **Who records the scope.** Whichever role is first to open the subject
  (per section 9's minting rule — product or feasibility, ordinarily)
  writes a scope statement into its OWN record: what will be done, the
  intended write surface, what is explicitly out of scope, and how success
  will be judged. This is written into the front record's own fields; a
  role never writes another role's record to satisfy this section.
- **`loop_state: scope-proposed`.** The front role sets its record's
  `loop_state` to `scope-proposed` once the scope statement is written.
  This is the state section 2 adds to `product-record` and, when it is the
  front record instead, to `feasibility-record`.
- **`loop_state: scope-approved` — human-owned, never self-certified.** Only
  the human may move a record from `scope-proposed` to `scope-approved`,
  per section 3's pre-work approval-gate edge and section 8's human's-seat
  list. No role approves its own scope statement, and no role approves
  another role's. An agent reading this contract in isolation has no path
  to write `scope-approved` itself — the state is reachable only through
  the human-consulted WAKES-ON edge.
- **What the gate blocks.** No building role may be woken into a subject's
  FIRST build until that subject's front record shows
  `loop_state: scope-approved`. Section 3's coding row is amended
  accordingly: feasibility's `verdict: go`, a qa-record defect, a `finding`
  addressed to coding, and a `ux-design-record` reaching `reviewed` all
  remain valid triggers, but none of them independently wakes coding into a
  subject's first build without `scope-approved` already set on that
  subject. This is a precondition added on top of the existing triggers,
  not a replacement for them — adding scope-approved as a parallel,
  independently-satisfiable edge would leave the pre-existing triggers free
  to wake the first build on their own, which defeats the gate; the fix is
  to amend the existing triggers themselves.
- **Re-wakes are unaffected.** The precondition binds only a subject's
  first entry into build. A later wake on a subject already past
  `scope-approved` — a fix for a finding, a qa regression, a ux-design
  revision — proceeds under the existing rows in section 3 without
  re-clearing this gate.
- **How a human approves, mechanically.** The approval is an exact line the
  human types in their own session — `APPROVE <kind> <subject>` — which
  mints a single-use token a gate then consumes. Two properties are
  load-bearing and neither may be relaxed. The whole turn must equal that
  line: three earlier designs read approval out of prose and all three
  leaked, because deciding what a sentence means is a language problem and
  a regex is the wrong tool for it. And the turn must be the human's own: a
  session spawned by an orchestrator receives its task as a prompt, so an
  orchestrator-authored turn is never an approval and the mint refuses
  under the orchestrator's stamp. A role asks by printing the exact line;
  it never relays one.
- **Unattended runs.** A run with no human present does not skip this gate
  and does not let the working role decide. Either it stops for a human, or
  an independent session — spawned by the orchestrator between role
  sessions, given no task context, no tools, and the mechanical git facts
  alongside the recorded material — returns `APPROVE`, `REFUSE`, or `HOLD`,
  and only a clean `APPROVE` mints a token marked `actor: judge`. `HOLD` is
  the correct answer whenever it cannot tell, and is not a failure. A gate
  accepts a judge's token only while its own session is unattended, so an
  approval minted in an unattended run can never satisfy an attended gate
  later. **The four decisions section 8 reserves for the human's seat —
  scope approval among them — are never delegated to a judge.** Unattended
  mode is set by the human or by the orchestrator on the human's behalf; an
  agent cannot set it from inside its own session.

## 20. Per-role record minimum content

Every role record (`docs/reports/records/<subject>/<role>.md`, per section
11) must, at every point it is read by another role or a human, contain
enough for a next reader to pick the work up cold. This section makes that
requirement explicit rather than leaving it implicit in section 18 gate B's
after-the-fact measurement.

A role record must state, at minimum:

1. **What was done** — the concrete work this record's role performed for
   the subject.
2. **Why** — including the alternative considered and why it was not taken,
   whenever the role made a real choice (not required when there was no
   choice to make).
3. **The concrete basis the next reader needs to continue** — the upstream
   commit sha or record path this record's conclusions rest on, this
   record's own current `loop_state`, and any open (unresolved) `finding`
   entries touching this subject.

Additionally, whenever the role leaves work open, the record must state:

4. **A next-steps backlog** — what a continuer should do next, concrete
   enough to act on without re-deriving it from scratch.
5. **An open-finding resolution path** — for any open finding or advisory
   the role is aware of touching this subject, the intended resolution path
   or who owns resolving it, not just the fact that it is open.

This is a minimum, not a template — role-specific required fields (section
2's table) are additional, not replaced by this list. This section pairs
with section 18 gate B: gate B measures, after a round, whether a
zero-context reader can reconstruct and continue from the records alone;
this section is what each role does at write time so that measurement
passes instead of failing on records that only show completion, not basis.

## 21. Document placement beyond the role record

The role record (section 11) is the subject-scoped work trail; it is not
the only place durable project knowledge belongs. In the target project's
own `docs/`, a role that produces one of the following must file it at the
stated location instead of folding it into the role record. Section 11's
"Section 21 grant" paragraph is what gives each role write-ownership of the
file it authors here — this section states the obligation, that paragraph
grants the ownership it requires:

- **A hard-to-reverse choice** — a library, file format, schema, protocol,
  storage engine, or interface picked over a named alternative, or any
  change to a public/on-disk/wire shape — goes in
  `docs/decisions/<date>-<slug>.md`, stating what was chosen, over what
  alternative, and why.
- **A measurement, benchmark, test run, or investigation** that produced
  numbers or findings goes in `docs/reports/<date>-<slug>.md`, stating what
  was run, what came back, and what it means.
- **System design tied to the code** goes in `docs/specs/`.
- **An operational surface change** — a role that introduces or changes an
  environment variable, a config key, a dependency, a migration, or a
  run/setup/deploy step in the target project — must create or update
  `docs/handbooks/<component>.md`: what it is, what it defaults to, what
  breaks without it, and the concrete commands to install, run, and operate
  the deliverable (not only how to test it).

  **Deriving `<component>`.** Mirroring section 9's `subject` derivation,
  `<component>` is not asked-for but derived, deterministically, from the
  artifact being changed: it is the name of the module, service, or
  config-area that owns the operational surface being touched — e.g. the
  directory or package containing the env var's consuming code, the
  dependency's declaring manifest (service directory for a per-service
  manifest, repo root for a repo-wide one), the migration's target
  service/database, or the run/setup/deploy step's script or workflow
  directory. Use that owning directory's own name (its `package.json`/
  `pyproject.toml` name field, or failing that its directory basename) as
  the slug, lowercased and hyphenated. Because the slug is read off the
  surface's owning location rather than chosen by the role, two roles
  independently changing the same logical surface derive the same slug.

  **Search before write.** Before creating `docs/handbooks/<component>.md`,
  a role must search `docs/handbooks/*` for a handbook already filed under
  the derived `<component>` slug (or an evident naming variant of it) and,
  if found, update that existing file in place rather than creating a new
  one — mirroring section 9's search-before-mint discipline for `subject`.
  Skipping this search is what would split one component's operational
  surface into multiple never-converging handbook files.

  A handbook is a living current-state doc, not a write-once record, so
  section 11's "Section 21 grant" single-author ownership does not apply to
  it. Instead, section 11 grants `docs/handbooks/<component>.md`
  component-scoped shared-write ownership: any role that changes that
  component's operational surface may create or update that component's
  handbook, keyed to the component rather than to whichever role authored
  it first — explicitly distinct from the per-role write-once record
  ownership, which stays single-author unchanged.

  **Write-time maintenance.** The role that changes a component's
  operational surface must update that component's handbook in the same
  unit of work that made the change (same-turn-sync), not on a separate
  wake. This resolves the living-doc-vs-single-author-ownership
  contradiction: last change wins as current state, and the surface-changer
  owns the update, so no handbook is ever asserted-current-but-unmaintained.

The role record links to these documents rather than duplicating their
content — the record stays the per-role trail (what this role did, why,
and where to look next); the decision/report/spec is the durable artifact
future work depends on. This is the target project's own obligation,
stated here in the contract body so it holds without any external
doc-classification hook installed on the agents doing the work — the
pre-work approval gate (section 19) and this placement rule are both
contract-internal now, not dependent on host tooling the spawned agents do
not carry.
