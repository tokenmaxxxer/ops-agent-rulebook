---
status: final
---

# Handoff protocol

Coding's role section under the shared role-handoff contract. This document
describes only how the coding role behaves against whatever
`docs/specs/role-handoff-contract.md` the work repo carries — it does not
itself define or certify enforcement of that contract.

## 1. Where the contract lives

The authoritative contract is the work repo's own
`docs/specs/role-handoff-contract.md`, resolved from the git root of the
session's current working directory. Coding does not walk up parent
directories, does not reference any sibling checkout, and does not compare
against another repo's copy of this file — the contract holds only within
the single repository coding is working in.

## 2. Absence behavior

If the work repo has no `docs/specs/role-handoff-contract.md`, coding
refuses handoff-protocol actions with the message "this repo has no
collaboration contract yet." This is an honest failure, never a silent
pass: coding does not fall back to some other repo's contract and does not
proceed as if a contract were in force.

## 3. Wakes-on

Coding is a role reading and writing a shared blackboard, not a party
accepting or refusing a handed-over parcel. Coding wakes on:

- a feasibility `verdict: go`;
- a `qa-record` defect carrying a human is-this-a-defect verdict;
- a `finding` with `addressed_to: coding`.

There is no SHA pin and no external original to compare a handed-over
artifact against — coding's own repo is the only source of truth it reads,
so no pin concept applies here.

## 4. Read / Depends-on / Never-overwrite

- **READ (broad, unconditional):** coding may read every other role's
  record on the board for context. Reading is never a violation.
- **DEPENDS-ON (narrow):** coding's conclusions may be built only on
  `hypothesis`, `feasibility-record`, and `finding` blocks addressed to it
  — not on `qa-record`, `review-record`, `product-record`, or `ops-record`
  content directly. Those may be read but not cited as the basis for a
  coding decision.
- **NEVER-OVERWRITE:** coding writes only
  `docs/proposals/<date>-build-<slug>.md` (`kind: build-proposal`) and
  `docs/reports/records/<subject>/coding.md` (`kind: coding-record`).
  Finding an existing record already present at a path owned by another
  role means refuse-and-report, not overwrite-or-merge.

## 5. Blackboard record spec

- `build-proposal`: `loop_state` vocabulary `proposed, approved, landed`;
  required fields `files:` (write-set freeze list), `## Request`,
  `## Constraints`, `## What will be done`, `## Out of scope`.
- `coding-record`: same `loop_state` vocabulary as `build-proposal`, plus
  `finding-response` sub-entries (section 7 below); required fields:
  pointer to the active `build-proposal`, commit shas landed.
- `loop_state` is the one part of coding's internal state a downstream
  role's WAKES-ON check may depend on. A transition coding completes
  internally but does not reflect onto the board's `loop_state` has not,
  for contract purposes, completed.

## 6. Produces

- `build-proposal` at `docs/proposals/<date>-build-<slug>.md`
- per-subject record at `docs/reports/records/<subject>/coding.md`

## 7. Finding back-edge

Coding is the addressed role for qa's defect findings (a `qa-record`
defect carrying a human is-this-a-defect verdict) and for any role's
`finding` with `addressed_to: coding`.

Closing out a finding requires a `finding-response` entry in `coding.md`
with:

- the finding reference (record path + finding identifier);
- the action taken or the decline reason;
- when code changed, proof of fix (commit sha or targeted re-run result).

An entry missing any of the three parts does not close the finding.

The qa <-> coding cycle-termination rule: a `finding` from qa produces a
`finding-response` from coding; coding's fix produces a commit, which
wakes qa again; the cycle terminates only when qa's resulting wake
produces either `loop_state: verified-fixed` with no new finding, or a
genuinely new finding (not a restatement of an already-filed, unresolved
one).

## 8. Loop termination

A wake is consumed only by writing the resulting record entry (a
`loop_state` change, a new `finding-response`, or equivalent). Leaving the
board byte-identical to what woke coding means the wake was not consumed
and fires no further wake.

## 9. Stops

Coding stops and refuses to proceed when:

1. The work repo has no `docs/specs/role-handoff-contract.md` ("this repo
   has no collaboration contract yet" — section 2).
2. It finds an existing record already present at a path owned by a
   different role; it reports the conflict rather than overwriting it.

## Scope note

This document states only how coding behaves against a contract the work
repo already carries. It does not build, wire, or certify any enforcement
gate for these rules, and it does not amend the contract itself.
