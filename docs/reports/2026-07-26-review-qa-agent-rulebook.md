---
date: 2026-07-26
subject: qa-agent-rulebook (read-only review)
---

# Review: qa-agent-rulebook

## Plugin inventory

Source: `qa-agent-rulebook/.claude-plugin/marketplace.json`.

- **`intake`** (`intake/`) — freezes a per-project QA profile (`intake.md`: tracker, issue template, labels, launch/test conventions, env var names). Mechanism: `UserPromptSubmit` prose directive (`intake/hooks/directive.sh`) + `SessionStart` script (`intake/hooks/session-start.sh`) + `/qa-init` command. No `PreToolUse` gate of its own — it relies on `qa-cycle`'s gate for any state-file effect and is otherwise pure discovery.
- **`testrun`** (`testrun/`) — runs the target app and records pass/fail/blocked verdicts with evidence; owns `observed→reproducing`, `reproducing→reproduced`, `reproducing→observed`, `reproducing→parked-unreproducible`. Mechanism: `UserPromptSubmit` prose directive only (`testrun/hooks/directive.sh`). It has no hook of its own that touches `state.md` — actual enforcement is 100% delegated to `qa-cycle`'s gate; `testrun` only asserts session discipline (charter, timebox, "report don't fix") in prose.
- **`bugreport`** (`bugreport/`) — bug-filing discipline for `reproduced→handed-off/not-a-defect/wont-fix` and the `severity`/`priority` field split. Mechanism: `UserPromptSubmit` prose directive (`bugreport/hooks/directive.sh`) + `/bug` command. No hook enforcement — same delegation pattern as `testrun`.
- **`stats`** (`stats/`) — read-only trust accounting (`/qa-stats`): acceptance/noise rate, UNFILED reasons. Mechanism: `UserPromptSubmit` prose directive only; genuinely no hooks that write anything (confirmed: `stats/hooks/directive.sh` is the only hook, and it only emits text).
- **`regress`** (`regress/`) — turns a confirmed bug into a regression test via a three-check adoption gate (fails on bug commit, passes on fix commit, stable k=5). Owns `handed-off→re-verifying`'s downstream re-run. Mechanism: `UserPromptSubmit` prose directive + `/regress` command. No hook checks the three-check log actually ran — it's asserted in prose ("must exist before the transition is treated as complete") with nothing mechanical behind it.
- **`qa-cycle`** (`qa-cycle/`) — the spine: owns `state.md` and the one `PreToolUse` gate (`qa-cycle/hooks/transition-gate.sh`) that adjudicates every attempted transition against the table in `docs/specs/qa-cycle-state-machine.md`. Mechanism: real `PreToolUse` hook (the only mechanically enforced gate in the whole stack), plus a `SessionStart` reporter (`report-phase.sh`) and a `UserPromptSubmit` prose directive.
- **`signoff`** (`signoff/`) — mints the human verdict token. Mechanism: real `UserPromptSubmit` hook (`signoff/hooks/capture-verdict.sh`) that parses the user's raw prompt text and writes token files, plus a prose directive and the `/go-no-go` command (itself pure prose — it never writes anything).
- **`qa-agent-env`** (`qa-agent-env/`) — bundler only, pulls in all seven plugins as dependencies. No code.

Net: of eight plugins, only **two** (`qa-cycle`, `signoff`) carry a hook that actually inspects or blocks a tool call / mints a credential. Every other plugin's "discipline" is a `UserPromptSubmit` directive string injected into context — a request to the model to behave, not a check on what it does.

## The cycle state machine as built

- **State file:** `<QA_WORKSPACE>/projects/<owner>-<repo>/state.md`, one file per project, a chain of independent `---`-delimited blocks, one per feedback item. Fields per block (per `docs/handbooks/qa-cycle.md` "The state file" and enforced by `qa-cycle/hooks/transition-gate.sh`): `item`, `state`, `reproduction`, `evidence`, `transition`, `severity`, `priority`. `qa-cycle` is the sole writer; every other plugin only "requests" a transition.
- **States** (`docs/specs/qa-cycle-state-machine.md` "States"): `(none)` (pre-existence marker, never a recorded state), `observed`, `reproducing`, `reproduced`, `handed-off`, `re-verifying`, `verified-fixed` (terminal), `not-a-defect` (terminal), `parked-unreproducible` (terminal-but-revivable), `wont-fix` (terminal). 9 real states + the bootstrap marker.
- **Transition table:** the spec documents 12 rows (11 from the item-axis spec plus one bootstrap row `(none)→observed`, actor `agent`, added only in the gate's own copy — `transition-gate.sh` lines ~137-150 comment this explicitly as "the only departure from the spec's table"). Table, with actor and `requires`:
  - `(none)→observed` agent, none (bootstrap, gate-only)
  - `observed→reproducing` agent, requires `target`
  - `reproducing→reproduced` agent, requires `severity`
  - `reproducing→observed` agent, none
  - `reproducing→parked-unreproducible` agent, none
  - `parked-unreproducible→observed` agent, none
  - `reproduced→handed-off` **human**, requires `token`
  - `reproduced→not-a-defect` **human**, requires `token`
  - `reproduced→wont-fix` **human**, requires `token`
  - `handed-off→re-verifying` **human**, requires `token`
  - `re-verifying→verified-fixed` agent, none
  - `re-verifying→reproducing` agent, requires `target`
- **Enforcement mapping:** exactly one hook enforces all 12 rows — `qa-cycle/hooks/transition-gate.sh`, a `PreToolUse` hook on `Write`/`Edit` (see Gaps). It is table-driven (`TABLE` list, `ROW_OF` dict) and reads each row's own `requires` list to decide whether to demand a `target` file, a `severity` field, or a `token`, rather than hard-coding per-transition special cases. `signoff/hooks/capture-verdict.sh` (`UserPromptSubmit`) is the only other component with runtime teeth, and it only mints tokens — it enforces nothing itself.
- Doc-vs-code drift the repo itself flags: per `docs/specs/qa-cycle-state-machine.md` line ~163, at the time of the 2026-07-30 item-axis spec revision, `transition-gate.sh`/`capture-verdict.sh` had not yet been updated and still spoke a prior per-project `phase` vocabulary. Reading the current `transition-gate.sh` (804 lines) shows this has since been done — the file is fully item-keyed — so this note in the spec is now stale documentation, not a live gap; worth flagging as an example of the model this repo already produces (a doc claiming a code state that code has since outgrown).

## The approval-token mechanism

`signoff/hooks/capture-verdict.sh` (`UserPromptSubmit`) mints two distinct token kinds, both under `<QA_WORKSPACE>/projects/<slug>/tokens/`:

- **State-transition token** (`<item-id>.token`): requires the prompt to name `item <id>` explicitly (regex, case-insensitive) and to match a phase-specific verdict phrase (e.g. `reproduced`→"confirmed defect"/"not a defect"/"won't-fix" wording; `handed-off`→"fix landed"/"re-verify" wording). Bound to `(item id, from→to)`. Explicitly rejects bare assent ("ok", "sounds good", a thumbs-up emoji) and scans the load-bearing phrase for credential/secret/internal-URL shapes before minting, refusing to mint (not just redacting) if it looks sensitive.
- **Priority token** (`<item-id>.priority.token`): requires `item <id>` plus `priority: <now|next|later|someday>`. Bound to `(item id, field=priority, new value)`.

**Consumption:** solely by `transition-gate.sh`. On an allowed human-actor row, the gate does not delete the live token — it moves it to `<item-id>.consuming` (or `.priority.consuming`), and finalizes (deletes) it only on the *next* invocation once the item's recorded state actually equals the marker's `to` value ("reserve-then-finalize", `docs/decisions/2026-07-31-token-consumption-ordering.md`). This closes a documented earlier bug (`docs/reports/2026-07-29-hunt-gate-execution-check.md`) where delete-on-allow let a token be spent even if the write it authorized never landed.

**Is it actually required, or only produced?** Required — genuinely, not just produced. Every row in `TABLE` marked `actor: human` carries `"requires": ["token"]`, and the gate's own code path (`if "token" in requires: ...`) refuses (exit 2) when no matching, unconsumed token or valid `.consuming` marker is found at the exact path `tokens/<item-id>.token`, matched on both `item` and the literal `from -> to` string — not on destination state alone. This was verified by reading the gate's `token_path`/`want_transition` matching logic directly, not asserted from the docs. The mechanism is real, but it is only as strong as the `PreToolUse` hook that consumes it — see Gaps for how that hook can be routed around.

## What is mechanically enforced versus asserted in prose

**Mechanically enforced (a model cannot simply ignore it, only bypass the specific hole below):**
- The 12-row transition table for any `Write`/`Edit` to `state.md` under `$QA_WORKSPACE/projects/*/state.md` (`transition-gate.sh`).
- The `severity` closed-set precondition on `reproducing→reproduced`.
- The `target.md` existence/shape/reference precondition on any row landing in `reproducing`.
- The four human-only transitions requiring an unconsumed, exactly-matching token.
- The `priority` field's separate token gate.
- Path-traversal defenses on item id / project slug (allow-list + resolve-then-contain), closing the forged-token bypass recorded in `docs/reports/2026-07-31-hunt-item-axis-enforcement.md`.
- Token minting is gated on prompt text actually present in the user's own turn, with an explicit reject list for vague assent and for credential-shaped phrases.

**Asserted in prose only, no hook behind it (a model can ignore these and nothing stops it):**
- "Report, don't fix" (`testrun` never editing target-project code) — nothing prevents the agent from calling `Edit`/`Write` against files in the target repo; there is no path-scope gate anywhere in this repo that blocks writes *outside* `$QA_WORKSPACE` (contrast with the four new role rulebooks' required PreToolUse path-bound gate — this repo has no equivalent "refuse writes outside my domain" gate, only a gate that adjudicates writes *to one specific file inside* the workspace).
- `bugreport`'s "file nothing you did not reproduce," duplicate search before filing, and the report-anatomy rules — nothing checks the filed issue's body against a reproduction that actually happened this session.
- `regress`'s three-check adoption gate (fail-on-bug/pass-on-fix/stable k=5) — the log is described as "required evidence" but nothing mechanical requires it to exist or be genuine before `re-verifying→verified-fixed` is attempted; that row's `requires` list in `transition-gate.sh` is `[]`.
- `intake`'s "never write a secret value" and "discovery over guessing" — prose only.
- `stats`'s read-only claim — true today only because it happens to have no `PreToolUse` hook and its directive says not to write; nothing would stop a future edit from making it write, and nothing today stops the *model* from writing `state.md` itself outside the `stats` "workflow" (the gate would still adjudicate that particular write, but only if it targets `state.md` specifically).
- Every plugin's "never write `state.md` directly, request the transition instead" — this is true in effect only because the one file every plugin might write to (`state.md`) happens to be covered by `qa-cycle`'s gate; nothing plugin-specific enforces it, and (per Gaps below) that coverage itself has a tool-name hole.

## User interaction points

- **`/qa-init`** (`intake`) — session-start discovery; stops to ask only for what can't be discovered from `git remote`/`gh label list`/repo inspection.
- **`/testrun <scope>`** (`testrun`) — session charter; the human sets scope and timebox, then the agent executes without further stops until a case fails or the timebox ends.
- **A failing case → `reproduced`** — the human is the required approver for what happens next; signaled by the item sitting in `reproduced` with no legal agent-only transition out (every outbound row from `reproduced` is `actor: human`).
- **`/go-no-go`** (`signoff`) — the explicit, designed stop: assembles the evidence bundle (reproduction, run-record entries, prior verdicts) and asks the human directly, by name, for one of `handed-off`/`not-a-defect`/`wont-fix`/`re-verifying`. Command itself never writes anything (`signoff/commands/go-no-go.md` step 3: "This command's job ends here"). Resume signal: the human's own next turn, parsed by `capture-verdict.sh` for an unambiguous verdict phrase — vague replies ("looks fine," "ok") are explicitly rejected and the command is instructed to re-ask.
- **Priority-setting turns** — a separate, state-independent stop: any turn of the form `item <id> priority <value>` mints a priority token regardless of what state the item is in.
- **`handed-off` interval** — an intentionally opaque wait: nothing in this stack observes the coding agent's progress; the only way out is the human's `re-verifying` trigger.
- **`/qa-stats`** — not a gate stop, but the human-facing view used to decide whether to keep trusting the pipeline's filings; feeds the human's judgment at the other stops without itself being a transition.

## Gaps

Ranked by consequence.

1. **Tool-name-bound gate — the known defect, reconfirmed against the current file.** `qa-cycle/hooks/transition-gate.sh` line ~217: `if tool not in ("Write", "Edit"): not_applicable()` — and `not_applicable()` is `sys.exit(0)` with no output, called *before* any path check runs. Any tool other than `Write`/`Edit` that ends up modifying `state.md` (a `Bash` call running `echo`/`cat`/`sed`/`python` against the exact path the gate would otherwise adjudicate) is invisible to the gate — not refused, not even inspected. Reproduced live during this review:
   ```
   payload: {"tool_name":"Bash","tool_input":{"command":"echo overwritten > .../state.md", "file_path":"...", "content":"---\nitem: bug-1\nstate: re-verifying\n---"}}
   $ QA_WORKSPACE=/tmp/ws2 bash qa-cycle/hooks/transition-gate.sh < payload
   exit=0   (no JSON output at all — not even an allow decision, just silent pass-through)
   ```
   This lands `handed-off → re-verifying` — a human-only, token-gated row — with zero token, entirely via `Bash`. This is a complete bypass of every human-only gate in the table, not a partial weakening. Consequence: critical. It also has zero regression-test coverage: `qa-cycle/hooks/tests/run-gate-tests.sh` only ever constructs `"tool_name": "Write"` payloads (single hit for `tool_name` in that file), so this hole would pass the existing test suite unnoticed.

2. **No path-scope gate outside `state.md` at all.** Every other plugin's "never edit the target project" / "report, don't fix" rule has no `PreToolUse` companion anywhere in this repo — only `qa-cycle`'s gate exists, and it only inspects writes whose resolved path is `$QA_WORKSPACE/projects/<slug>/state.md`. A write to the target project's source tree, or to any other file under `$QA_WORKSPACE` (run records, evidence files, `intake.md`, `target.md` content beyond its own precondition check), is `not_applicable()` from this gate's point of view and mechanically unguarded by anything else in the plugin set. This is a materially different (and weaker) posture than "PreToolUse path-bound gate that fails closed" as specified for the four new role rulebooks — this repo enforces one file's *content legality*, not a domain boundary.

3. **`regress`'s and `bugreport`'s and `testrun`'s core disciplines are pure prose, with the gate providing no backstop for their claims.** The `requires` list for `re-verifying→verified-fixed` is `[]` — nothing enforces that the three-check adoption gate actually ran, so an agent can go straight from asserting "fix landed" to "verified-fixed" without ever invoking `/regress`'s logic, as long as it writes syntactically legal `state.md` content. Same for `bugreport`'s duplicate-search-before-filing and reproduction-only-filing rules: nothing structural stops a fabricated report.

4. **Malformed-input behavior is inconsistent across the two runtime hooks by design, and that design choice is itself a gap for `capture-verdict.sh`.** `transition-gate.sh` fails closed on everything (unreadable stdin, bad JSON, missing `QA_WORKSPACE`, ambiguous state file, oversized file past a 1MB/64KB cap → all exit 2). `capture-verdict.sh` **never blocks** — every malformed condition (no `QA_WORKSPACE`, no `jq`/`python3`, bad JSON, no prompt, no matching project, ambiguous item state, no item id, unrecognized verdict wording) is a silent `exit 0` with nothing minted. This is a deliberate, documented split (a `UserPromptSubmit` hook that blocks would break normal conversation), but it means a legitimate verdict phrased in a form the regex doesn't anticipate is silently dropped with zero feedback to the human that their verdict didn't register — the human has no way to tell "my verdict didn't parse" from "my verdict parsed and is waiting to be consumed" other than checking for the token file directly.

5. **Missing files a documented step depends on, silently degrading rather than refusing.** `report-phase.sh` (SessionStart) was previously found to go silent when `state.md`'s shape changed out from under it (`docs/reports/2026-07-31-hunt-item-axis-enforcement.md`, "FINDING — ... will silently stop reporting anything"); reading the current file shows this specific instance was fixed (it now parses per-item blocks correctly), but the *pattern* — a reporting/consumption script reading a shape the gate no longer produces, and going quiet instead of erroring — is a recurring risk class in a system with this many scripts independently re-implementing the same block parser (`transition-gate.sh`, `capture-verdict.sh`, and `report-phase.sh` each have their own copy of `BLOCK_RE`/`ITEM_KEY`/`STATE_KEY`, not a shared library) rather than a one-off closed bug.

6. **State nothing maintains.** The `handed-off` interval is explicitly "opaque by design" — no file, hook, or record tracks the coding agent's actual progress on a handed-off item; the system's picture of reality is frozen at whatever the human asserts on `re-verifying`. This is a stated design choice (see `docs/decisions/2026-07-26-human-gate-over-pipeline-gate.md`), not an oversight, but it means a stale or wrong `re-verifying` trigger has no cross-check anywhere in the stack.

## What the new role rulebooks should copy, and what they should not

**Copy:**
- The single-spine ownership model: exactly one plugin (`qa-cycle`) owns the state file and the one `PreToolUse` gate; every other plugin only "requests" a transition in prose and never claims write authority. This is a clean separation and it is what makes the gate auditable at all — one file, one table, one enforcement point.
- Table-driven gate logic keyed by `(from, to)` with a per-row `requires` list (`["token"]`, `["target"]`, `["severity"]`, `[]`), rather than hard-coded per-transition special-casing. This is what let `target` and `severity` preconditions bolt on without touching the human-token logic, and is directly reusable in the four new rulebooks' own state gates.
- Reserve-then-finalize token consumption (`.token` → `.consuming` → deleted only once the authorized state is observed to have landed) instead of delete-on-allow — this closes a real, previously-exploited retry/aborted-write hole and should be the default pattern, not something each new rulebook rediscovers.
- Allow-list-then-resolve-then-contain path validation on every untrusted id used to build a filesystem path (item id, project slug) — this closed a real path-traversal-to-forged-token bypass here and is the correct baseline for the four new rulebooks' own state/token paths.
- The credential/secret/URL scan before minting any token, and the explicit rejection of vague assent ("ok", thumbs-up) as a verdict — cheap, load-bearing, easy to copy verbatim.
- `--dump-facts` as a read-only, argument-exact-match introspection path kept structurally separate from the adjudication path (guarded against stdin-payload smuggling) — good pattern for letting a drift-check test assert against the gate's own table without re-deriving it by hand.

**Do not copy:**
- The `tool_name in ("Write", "Edit")` gate condition, checked *before* the path check. This is the confirmed critical defect: it makes gate applicability a function of which tool the agent chose to use rather than of which file it touched, and it is invisible to the existing test suite because that suite also only ever constructs `Write` payloads. The four new rulebooks' state gates must decide applicability from the resolved path first, unconditionally on tool name — or, if a tool allowlist is kept as an optimization, it must cover every tool capable of an arbitrary file write (`Bash` at minimum) and default to "inspect" rather than "not applicable" for anything not explicitly known to be read-only.
- Relying on a single file-content gate (`state.md`) as the *only* mechanically enforced boundary in the whole stack, with every domain rule ("don't edit the target project," "don't fabricate a regression run," "don't file unreproduced bugs") left as prose with nothing behind it. The new rulebooks are specified to need a "PreToolUse path-bound gate that fails closed" — this repo's gate is path-bound only to one specific file, not to a domain (e.g. "nothing outside `$ROLE_WORKSPACE`"); the new rulebooks should generalize the containment check this repo already has correct (resolve-then-contain against a workspace root) into the actual scope boundary, not just onto one state file's path.
- Letting `requires: []` mean "nothing to check" for a row whose whole justification is external evidence (`re-verifying→verified-fixed` depending on the three-check adoption gate having actually run). If a transition's legitimacy depends on an artifact a sibling plugin is supposed to produce, the new rulebooks' `requires` mechanism should be able to demand that artifact's presence the same way `target`/`severity` are demanded here, rather than leaving it as an unenforced prose claim.
- Independently re-implementing the same block-parsing regexes in three different scripts (`transition-gate.sh`, `capture-verdict.sh`, `report-phase.sh`). One drifted before (`report-phase.sh`) when the state-file shape changed; a shared parsing module (even a small one, given these are single-file bash+embedded-python scripts) would remove that recurring failure class for the new rulebooks from the start.
