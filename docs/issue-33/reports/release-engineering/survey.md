---
subject: issue-33
role: release-engineering
kind: current-state-survey
status: draft
---

# Current-state survey — release-engineering enforcement infrastructure (issue #33)

## What exists today

- `ops/hooks/directive.sh` (`docs/issue-33` repo, i.e. this repo's `ops/`
  plugin) — a `SessionStart` role directive built from four single-block
  strings (`YOU_DECIDE`, `USE_WHEN`, `PRODUCES`, `HAND_OFF`) passed to
  `core_role_directive` (shared lib at
  `${CLAUDE_PLUGIN_ROOT_CORE}/hooks/lib/role-directive.sh`, referenced not
  copied). Each string is prose — a paragraph, not a stage/judgment/
  prohibition breakdown. `PRODUCES` currently folds together the phase-1
  rollout-plan skill AND the phase-1 RFC-shaped-proposal norm from issue-27
  in one run-on sentence.
- `ops/hooks/proposal-fields-gate.sh` (154 lines) — PreToolUse gate on
  `docs/issue-<n>/proposals/*.md` writes; checks for four textual markers
  (scope/change-description, risk, rollback/back-out, one inline
  citation). Fail-closed trap, JSON payload parsing, path resolution
  against `CLAUDE_PROJECT_DIR`, kill switch env var. Delivered in issue-27
  phase 2 (PR #32).
- `ops/hooks/rollout-plan-fields-gate.sh` (165 lines) — PreToolUse gate on
  `ops/rollout-plan.md` writes; parses `## Step` blocks, requires every
  metric to carry a non-empty `threshold:` before the step is marked
  `result: pass`/`fail`. Same fail-closed/kill-switch shape. Also from
  issue-27 phase 2.
- `ops/hooks/hooks.json` registers both directive.sh and the two gates.
- `ops/.claude-plugin/plugin.json` — plugin manifest, depends on
  `tokenmaxxxer-core` (core + warrant plugins) installed alongside.
- Repo-root `tests/deny-only-check.sh` and `tests/parse-check.sh` — generic,
  distributed-to-every-rulebook harnesses (deny-only verdict shape + bash
  3.2 parseability). Neither is release-engineering-specific; neither
  exercises the two field gates' actual pass/deny behavior end to end.
- `docs/issue-27/proposals/2026-07-31-rulebook-maturation.md` — the
  "domain-researched proposal & deliverable norms" adoption this issue
  builds on. Established: (a) RFC-shaped phase-1 proposal norm (scope,
  risk, rollback, sourced evidence), (b) confirmed the four phase-2 skills
  (`error-budget-policy`, `readiness-checklist`, `rollout-plan`,
  `postmortem`) as already matching converged practice — no methodology
  change, (d) the plugin-reflection plan that produced the two gates above.
  It explicitly flagged as out of scope: any gate *tests*, any *state
  tracking* for methodology ordering, and the dangling `state-gate.sh` /
  `state-machine.md` / `transition-rules.md` references the skills mention
  but this repo never built.

## What issue-27 established (methodology content, confirmed not re-derived here)

RFC-shaped phase-1 proposal (scope/risk/rollback/sourced-evidence) and the
four phase-2 skill shapes (error-budget policy, PRR readiness checklist,
canary rollout plan with pre-declared thresholds, human-reviewed
postmortem). Issue #33 does not revisit this methodology; it asks that the
methodology, already adopted, be turned into a directive detailed enough to
read as instructions rather than a one-line summary, and into gates that
verify it mechanically — matching the rigor of implementation-rulebook's
hook machine.

## What "hook machine" rigor looks like in implementation-rulebook (comparison bar)

Read directly from
`/home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/coding/hooks/`
(external canon checkout, read for comparison only — nothing from it is
copied into this repo):

- `directive.sh` (~90 lines of shell, each of the four values a multi-line
  `$'...'` block with explicit sub-headers per phase — e.g. `PRODUCES`
  enumerates SCOPE-EXCEEDED RULE, HONEST CLAIMS, a "What did not work"
  section, a "Rationale for deviations" section, a document-placement
  ladder, hunt cadence, and how hunt results feed the record — each a named
  rule with a trigger condition, not a summary sentence).
- `coding-progress-gate.sh` (178 lines) — a PreToolUse gate on `git commit`
  that reads a *different role's* record file (`verify.md`), scans for
  `finding` blocks with `severity: blocking` addressed to this role, and
  refuses the commit unless this role's own record shows a matching
  `resolved_findings` entry AND the finder's record shows `loop_state:
  cleared`. This is genuine cross-file state tracking enforcing an ordering
  constraint (finding raised -> resolved -> re-cleared, in that order)
  before the ordinarily-unrelated action (a commit) is allowed to proceed.
- `hunt-state.sh` / `hunt-guard.sh` (47 + 172 lines) — a rotating-stance
  state file plus a guard that enforces the hunt cadence the directive
  names ("dispatch at end of phase 1 and before phase-2 completion").
- `state.sh` (29 lines) — a `SessionStart` informer (not a gate) that
  reconstructs open-unit context (branch, PR review state, whether the
  role's own record file exists) — read-only, never blocks.
- Every one of the above ships next to its own `tests/` directory exercising
  allow and deny paths.

Total: ~440 lines of hook shell for coding alone, split across a directive,
two independent state/gate pairs (progress-gate + hunt-guard), and a
non-blocking context-restorer — each piece enforcing a *different* rule,
not one monolithic script.

## Gaps this survey identifies for scout to target

1. **Directive elaboration format**: no example yet of how *this role's*
   phase-1/phase-2 stage breakdown should be written as multi-line
   `$'...'` blocks (issue #33 explicitly asks for this — "facet별 실행
   가능한 수준"). Need to confirm the `$'...'`-block convention is the
   right vehicle (it is — confirmed above) and work out the per-facet
   split that fits release-engineering's four artifacts without simply
   restating skill prose.
2. **Ordering/state-tracking need**: does release-engineering actually have
   a methodology-order constraint analogous to coding's finding->resolved
   ordering? Candidate: issue-27's own adopted sequence for the
   *phase-1 proposal itself* — a proposal must have scope+risk+rollback
   BEFORE a phase-2 write is legal (already gated, no ordering issue) —
   versus rollout-plan's per-step "thresholds before result" ordering
   (already gated, single-document, no cross-file state needed). Need
   scout to confirm no genuine cross-file/cross-phase sequencing gap
   exists here (unlike coding's cross-role finding lifecycle), so state
   tracking can be scoped correctly (possibly: none needed, or a lighter
   in-repo state file only if the PRR->rollout->postmortem order needs
   enforcing across separate files).
3. **Gate test coverage**: neither existing gate (`proposal-fields-gate.sh`,
   `rollout-plan-fields-gate.sh`) has a dedicated allow/deny test case
   under `tests/`. implementation-rulebook's per-gate `tests/` dirs are the
   comparable pattern to scout for exact shape (fixture payload format,
   how `python3` heredoc gates get driven from a shell test harness).
4. **Whether an agent/checklist is warranted**: issue-27's phase-2 skills
   already ARE the checklists (readiness-checklist, rollout-plan,
   postmortem). Need scout to confirm whether release-engineering has any
   *repeated procedural step* (e.g., "run the hunt cadence" for coding) that
   isn't already covered by an existing skill, or whether "no new
   agent/checklist needed" is the right call (issue text says "if
   applicable").
5. **Canon-reference discipline**: confirm the `core_role_directive` lib
   function signature (arity, ordering) so the elaborated directive stays a
   drop-in replacement rather than inventing a new call shape.
