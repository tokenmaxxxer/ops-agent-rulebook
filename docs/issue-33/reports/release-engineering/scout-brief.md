---
subject: issue-33
role: release-engineering
kind: scout-brief
status: draft
budget: "5 stages max / 3 min wall-clock, self-timed via `date`"
---

# Scout brief — release-engineering enforcement mechanism (issue #33)

Stages run (timestamps via `date`, KST):
1. 22:10:12 — role-directive.sh library signature + call-site convention.
2. 22:10:20 — implementation-rulebook per-hook `tests/` directory census.
3. 22:10:30 — confirmed: only `no-footgun/` and `no-mock/` carry a
   hook-local `tests/parse-check.sh`; **`coding/hooks/tests/` does not
   exist** even though `coding-progress-gate.sh` (the exact hook cited as
   the rigor bar) has no dedicated allow/deny fixture anywhere in the repo
   at all — its only regression coverage is the shared, generic
   `deny-only-check.sh`/`parse-check.sh` pair.

Web access was not used for this brief. Falling back to in-repo/on-disk
comparables only: this repo's own `tests/deny-only-check.sh` (already
contains a hand-rolled "substance probe" — spins up a temp dir, feeds a
gate a synthetic empty-record payload, and asserts a deny) and
implementation-rulebook's hook tree, both read directly from disk this
session. No exemplar was fabricated; where a claim below cites a file, that
file was opened this session (see survey.md for exact paths and line
counts).

## Findings, mapped to the survey's five gaps

1. **Directive elaboration format** — confirmed viable and low-risk: the
   shared `core_role_directive` function (`core/hooks/lib/role-directive.sh`)
   takes exactly four positional string args and only formats/echoes them;
   it does not parse or size-limit them. Multi-paragraph `$'...'` blocks
   (as coding's `directive.sh` uses) are a drop-in replacement for this
   role's current single-sentence strings — no library change needed, no
   canon dependency added.

2. **Ordering / state-tracking need** — scout does NOT find a genuine
   cross-file/cross-phase ordering gap analogous to coding's
   finding-raised -> resolved -> re-cleared cycle. Coding's ordering
   constraint exists because a *second role* (verify) writes blocking
   findings into a *different* file that must later show `cleared`.
   release-engineering has no equivalent second-role dependency in its
   current four artifacts: the proposal-fields and rollout-plan-fields
   gates each police a single document's own internal completeness at
   write-time, which is what a stateless PreToolUse gate already does
   correctly. The one candidate for real ordering — "postmortem must be
   human-reviewed before an incident closes" — is already handled by the
   `readiness-checklist` skill's stated human-turn requirement (per the
   issue-27 proposal, item (d).4) and does not currently have machine
   state backing it in this repo. Recommendation: name this as a
   deliberate scope boundary in the proposal (state tracking is not
   needed for the two existing gates; the postmortem human-review gap is
   real but is a *new* gate on a document that doesn't exist yet in this
   repo — `postmortem-template.md`/`docs/issue-<n>/reports/postmortems/`
   — and should be scoped explicitly, not silently dropped).

3. **Gate test coverage** — implementation-rulebook itself does NOT keep
   per-gate fixture files even for the cited rigor-bar gate
   (`coding-progress-gate.sh` has zero dedicated test file). The actual
   working pattern for gate-specific tests in this ecosystem is this
   repo's OWN `tests/deny-only-check.sh`, which already embeds a
   substance probe (temp dir + synthetic payload + assert-deny) as a
   second check inside the shared script. That is the real, load-bearing
   precedent to extend — not a hunt for an external example that doesn't
   exist. Recommendation: add gate-specific allow/deny cases as new
   substance probes in the same file (or an adjacent
   `tests/release-engineering-gates-check.sh`), each driving
   `proposal-fields-gate.sh` / `rollout-plan-fields-gate.sh` directly with
   synthetic PreToolUse JSON on stdin.

4. **Agent/checklist need** — no repeated procedural step in
   release-engineering's four artifacts resembles coding's hunt cadence
   (a dispatch-twice-per-cycle obligation needing its own state file). The
   four skills already are the checklists. No new agent/checklist is
   scouted as necessary beyond item 2's postmortem-review gate above.

5. **Canon-reference discipline** — confirmed: `role-directive.sh` is
   sourced via `${CLAUDE_PLUGIN_ROOT_CORE:-...}/hooks/lib/role-directive.sh`,
   exactly as `ops/hooks/directive.sh` already does. No change to this
   sourcing convention is proposed; only the four string arguments grow.

## Sources
- In-repo/on-disk only (no web fetch performed this pass):
  - `ops/hooks/directive.sh`, `proposal-fields-gate.sh`,
    `rollout-plan-fields-gate.sh`, `hooks.json` (this repo)
  - `docs/issue-27/proposals/2026-07-31-rulebook-maturation.md` (this repo)
  - `tests/deny-only-check.sh`, `tests/parse-check.sh` (this repo)
  - `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/lib/role-directive.sh`
    (external canon checkout, read-only comparison — not copied)
  - `/home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/coding/hooks/`
    (`directive.sh`, `coding-progress-gate.sh`, `hunt-state.sh`, `state.sh`;
    external canon checkout, read-only comparison — not copied)

No design decision here required an external/web source: the adopted
methodology itself (RFC-shaped proposal, PRR/canary/postmortem shapes) was
already sourced and cited in issue-27's proposal; this issue's open
questions are about *this repo's own* implementation-rulebook precedent,
which is fully available on local disk.
