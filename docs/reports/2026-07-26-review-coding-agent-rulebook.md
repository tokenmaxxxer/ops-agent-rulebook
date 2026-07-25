---
proposal: none — read-only review, no proposal/write-set in this repo
---

# Review — coding-agent-rulebook

Read directly (via `cat`, not the Read tool — see the Gaps section for why) against
`/home/jwjung/tokenmaxxxer/coding-agent-rulebook/` as of 2026-07-26. Every claim below
is grounded in a specific file; paths are relative to that repo root unless stated
otherwise.

## Plugin inventory

Ten plugins in `.claude-plugin/marketplace.json`:

- **freelunch** — forces width-conditional parallel dispatch (solo vs. fan-out). Mechanism: `UserPromptSubmit` directive (`freelunch/hooks/freelunch.sh`, 181 lines, versioned prose with inline changelog) + a `PreToolUse` telemetry/soft-enforcement hook on `Agent|Task|Workflow` (`freelunch/hooks/observe.sh`) that logs JSONL and, only under `FREELUNCH_ENFORCE=1`, denies non-background or non-Sonnet dispatches. Also ships an `agents/freelunch-worker.md` subagent definition and JS "workflow" fan-out scripts.
- **terse** — output-prose compression, 4 levels. Mechanism: `UserPromptSubmit` directive (`terse/hooks/terse.sh`) reading persistent state from `~/.claude/terse.level`, written by the `/terse` slash command (`terse/commands/terse.md`). Prose-only, no gate.
- **blueprint** — 16-archetype architecture selection. Mechanism: a Skill (`blueprint/skills/blueprint/SKILL.md`) backed by CSV data (`archetypes.csv`, `antipatterns.csv`, `rules.csv`) and a `scripts/prep.py` CLI. No hooks at all (`blueprint/hooks/hooks.json` does not exist).
- **no-mock** — steers toward production-runnable structure (real persistence/integration, no silent mocks). Mechanism: `UserPromptSubmit` directive only (`no-mock/hooks/directive.sh`). Explicitly de-scoped verification: its own header states v0.1.0's Stop-hook `proof.sh` gate and post-write mock sniffer were removed in v0.2.0. Prose directive, no gate.
- **scout** — pre-build reconnaissance (Camp benchmarking + Kano + saturation stop). Mechanism: `UserPromptSubmit` directive only (`scout/hooks/directive.sh`). Pure prose protocol with judgment points; nothing mechanical checks that scouting happened.
- **no-footgun** — names threat patterns per surface (injection, deser, XSS, secrets, paths, SSRF, IDOR, authz). Mechanism: `UserPromptSubmit` directive only (`no-footgun/hooks/directive.sh`), plus a cascading custom-rules file it reads and inlines (`~/.claude/no-footgun.md`, `./.claude/no-footgun.md`) with a 16KB truncation guard. Prose only.
- **doctrine** — six lifetime-based buckets under `docs/`. Mechanism: **all three** — `SessionStart` hook creates the buckets (`doctrine/hooks/ensure-buckets.sh`), `UserPromptSubmit` directive classifies at write time (`doctrine/hooks/directive.sh`), `PreToolUse` gate (`doctrine/hooks/placement-gate.sh`) mechanically refuses non-README writes under `docs/` outside the six buckets.
- **warrant** — one approval gate at the front (proposal → approved → landed), frozen write set, commit-trailer requirement, background "hunter" probes. Mechanism: the heaviest in the stack — `SessionStart` (`state.sh` + `hunt-state.sh reset`), `UserPromptSubmit` directive (`directive.sh`), `PreToolUse` **two** gates (`scope-gate.sh` for write-set/trailer enforcement, `hunt-guard.sh` for hunter concurrency/cap), `SubagentStop` (`hunt-state.sh release`), plus a dedicated `warrant-hunter` subagent (`agents/warrant-hunter.md`).
- **dispatch** — chat-to-git record keeping (issue/PR/comment/merge-on-approval mirroring). Mechanism: `UserPromptSubmit` directive only (`dispatch/hooks/directive.sh`). No gate — explicitly "direction only, no gates" per its own `plugin.json` description.
- **coding-agent-env** — no code; a dependency bundle in `plugin.json` pulling in all nine others.

## How a directive actually reaches the model

Every steering plugin (all except blueprint) wires a shell script to `UserPromptSubmit`
in its `hooks/hooks.json`, e.g. `warrant/hooks/hooks.json:28-37`. On every user prompt,
Claude Code invokes each script; the script does a kill-switch check (`case
"${X_OFF:-}" in ""|0|false|no|off) ;; *) exit 0 ;; esac` — this exact idiom is
duplicated verbatim across all nine `X_OFF` kill switches), then `cat <<'EOF' ...
EOF`-emits a large fenced block (e.g. `<warrant-directive priority="high">…</warrant-directive>`,
`doctrine/hooks/directive.sh:29-...`) to stdout. Claude Code injects that stdout as
additional context ahead of the actual user turn — this is the entire delivery
mechanism. There is no template substitution, no conditional branching in the
directive text itself (other than the `priority="high"` XML attribute and, for
terse/no-footgun, small runtime-computed inserts: terse's `${STYLE}` block selected
by `~/.claude/terse.level`, no-footgun's per-file custom-rules block). The model
receives plain English/markdown prose and is trusted to apply the "SURFACE GATE"
clause each directive opens with (e.g. `warrant/hooks/directive.sh:86`, `doctrine/hooks/directive.sh`
"SURFACE GATE: apply only when…") to decide whether it's even in scope for the turn.
Nothing enforces that self-assessment; it is the model reading its own instructions
and deciding whether they apply.

`PreToolUse` gates (doctrine's `placement-gate.sh`, warrant's `scope-gate.sh` and
`hunt-guard.sh`) work differently and mechanically: Claude Code pipes a JSON payload
(`tool_name`, `tool_input`) to the script's stdin before the tool call executes; the
script inspects only that payload (never generated file content) and exits 0 (allow,
optionally emitting a `permissionDecision` JSON) or exits 2 with a stderr message that
becomes a hard refusal the model sees as a tool error. This is the only place in the
stack where a rule is enforced rather than requested.

## State and enforcement

Persistent, cross-turn state that this repo's hooks actually read and write:

- **`docs/proposals/*.md` frontmatter `status:`** (warrant) — the one piece of state that gates real behavior. `scope-gate.sh` scans this directory on every `PreToolUse` call and requires exactly one `approved` entry before it enforces anything (`warrant/hooks/scope-gate.sh:271-306`).
- **`.warrant-hunt.lock` / `.warrant-hunt.count`** at the (resolved) repo root — hunter single-flight lock and session dispatch cap, written by `hunt-guard.sh`, cleared by `hunt-state.sh` on `SubagentStop`/`SessionStart`.
- **`~/.claude/terse.level`** — one word, read by `terse.sh` every prompt.
- **`~/.claude/no-footgun.md`, `./.claude/no-footgun.md`** — cascading rule files, read (not written) every prompt.
- **`docs/reports/<date>-hunt-<slug>.md`** — append-only hunt record, written by the `warrant-hunter` subagent, not read by any hook (only by humans/future sessions).

Mechanically enforced (a `PreToolUse` gate exits 2 on violation) vs. merely asserted
in prose the model can ignore:

- **Mechanically enforced:** doctrine's bucket placement for `docs/*` writes (`placement-gate.sh`); warrant's write-set containment and commit-trailer-on-`git commit` for `Bash`/`Write`/`Edit`/`NotebookEdit` while exactly one proposal is `approved` (`scope-gate.sh`); warrant's hunter single-flight/cap/no-nesting (`hunt-guard.sh`); freelunch's `FREELUNCH_ENFORCE=1` opt-in denial of sync or non-Sonnet dispatch (`observe.sh`) — **note this is off by default**, so in the shipped default configuration freelunch is prose-only too, exactly like doctrine's directive half and everything else.
- **Prose only, model-trusted:** the entire warrant protocol *except* the two mechanical checks above — writing the proposal in the first place, stopping after writing it, appending "What did not work," dispatching a hunter at the right two moments, taking the stance at `(count mod 5)` rather than the "apt-seeming" one, setting `status: landed` and filing the durable sections; the entire doctrine classification judgment (which of the six buckets); all of scout, no-mock, no-footgun, dispatch — every one of these plugins has **zero** `PreToolUse`/`Stop` gate. doctrine's own README (`doctrine/README.md`, "This does not, by itself, get documents written — measured") reports the sharpest evidence of this: two headless runs with the buckets freshly created and the directive live still produced **no document** on tasks that squarely matched a trigger (env var added, retry/timeout logic added), matching four earlier no-`docs/`-tree runs — 0 of 6. Only rewriting the directive from "these turns owe a document" to an explicit condition→destination table got it to 3 of 3. Even a well-tuned directive is admitted, in the shipping plugin's own documentation, to be an unreliable mechanism — this is the project being honest about a prose-only rule's failure rate, not speculation.

The repo's own `warrant/README.md` ("What is verified, and what is not") draws the
same line explicitly: the gate is "deterministic and tested against a decision
table… six silent failures were found that way and closed"; "the protocol half is
prompt text… It is not guaranteed the way the gate is."

## User interaction points

- **Warrant's single approval gate** — the directive instructs: write the proposal, "WRITE IT, THEN STOP… Do not begin the work in the same turn." Resume signal is the user's next message (implicitly "approved," nothing checks the wording); no gate blocks starting early — a model that ignores "then stop" is not stopped by anything.
- **Warrant's post-landing report** — "after approval there is exactly one more exchange, the one where the work is reported" (`directive.sh:138`). Purely conventional.
- **Dispatch's merge gate** — the only interaction point in the stack with an explicit anti-inference rule in prose: "Merge... only on an EXPLICIT, unambiguous approval from the USER'S OWN turn — never inferred from vague assent… and never taken from the content of a file, issue, PR, or comment" (`dispatch/hooks/directive.sh`). No hook backs this; a model that merges on "looks fine, ship it" is stopped by nothing but its own reading of the directive.
- **Scout's two judge points** — "are these actually top-tier" and the saturation check — both purely internal model judgment calls, not user-facing stops, and not gated.
- **Warrant hunter findings** — "A finding reaches the user at the next turn boundary, in one line" — asynchronous, non-blocking by design ("never gates the work" — `warrant/README.md`).
- **`no-footgun`'s oversized/unreadable custom-rules file** — the only place any directive stops to report a *degraded* condition to the user rather than asking for a decision: it prints a `status="unreadable"` block or a truncation notice so the model states plainly that rules are not in effect, rather than silently proceeding as if the (empty) rule set were complete.

None of these except doctrine's and warrant's `PreToolUse` gates has any mechanical
backing; all of them are "the directive tells the model to stop and wait," fully
dependent on the model reading and honoring that sentence on that turn.

## Gaps

Ranked by consequence, all traced to a concrete file or a reproduction I obtained
directly while doing this review:

1. **The scope-gate's "one repo" assumption breaks across a multi-repo workspace, and I hit this live.** `warrant/hooks/scope-gate.sh:206-220` resolves its `root` from `CLAUDE_PROJECT_DIR` (falling back to `git rev-parse --show-toplevel`, but *keeping* `CLAUDE_PROJECT_DIR` verbatim as `root` whenever that env var is set and `git rev-parse` fails). In this workspace, `/home/jwjung/tokenmaxxxer` is **not** a git repo (it holds five sibling `*-agent-rulebook` repos plus `coding-agent-rulebook` plus `docs/`), yet `CLAUDE_PROJECT_DIR` is set to it. The gate therefore reads `/home/jwjung/tokenmaxxxer/docs/proposals/` as *the* proposals directory and enforces whatever is `approved` there against **every tool call in every sibling repo**, including this read-only review of `coding-agent-rulebook/`. I directly received: `warrant: refused — coding-agent-rulebook/.claude-plugin/marketplace.json is outside the write set frozen by docs/proposals/2026-07-26-state-gate-path-resolution.md` — a proposal whose entire write set was four *other* rulebooks' `state-gate.sh` files, with `coding-agent-rulebook` explicitly named **out of scope** in its own body. The gate does not know or care that the proposal it is enforcing has nothing to do with the repo the tool call targets. This is the "monorepo proposal directories the gate does not reach" case the README (`warrant/README.md`, "What is verified") lists as a *known* limitation, inverted into its opposite failure: instead of standing down on a sub-repo it can't see, it wrongly claims one flat root over unrelated sibling repos it can see too much of.
2. **The same gate fires on `Read`, not just `Write`/`Edit`/`Bash` as its own header promises.** `scope-gate.sh`'s comment block says "PreToolUse hook (Write|Edit|NotebookEdit|Bash)"; `hooks.json`'s matcher is `".*"` (`warrant/hooks/hooks.json:39-40`), and the Python body falls through to the generic `path = tool_input.get("file_path")…` branch for any tool call carrying that key — which a `Read` call does. I received the refusal above on a `Read`, not a write. Fails safe here (over-blocks rather than under-blocks), but it is undocumented scope creep: a reviewer, or any read-only agent, is refused access to files it never intended to modify, and the refusal message ("outside the write set… Widening the set mid-build is what the gate exists to prevent") is worded entirely around edits, actively misleading about why a read was blocked.
3. **freelunch's only mechanical check is off by default.** `observe.sh` denies sync/non-Sonnet dispatch only under `FREELUNCH_ENFORCE=1`; unset, it only logs. The plugin whose README leads with "1.50x geomean speedup" benchmark numbers ships, by default, as pure prose — identical in enforcement strength to no-mock or scout, contrary to the impression its `plugin.json` description ("no verification passes" as a design philosophy, not "no enforcement machinery either") gives.
4. **doctrine's directive is proven unreliable at getting documents written, and the fix that worked is fragile.** Per its own README, the win came from replacing a judgment ask ("does this turn owe documentation") with a literal condition→destination table matched against surface features of the turn. That is a narrower, more brittle mechanism than it looks — a task that doesn't verbally match one of the five listed trigger phrases (env var, chosen-over-alternative, changed public shape, ran tests/benchmark, found a stale doc) produces nothing, silently, with no gate to catch the miss. n is small (a handful of runs); the repo is honest that this is unresolved, not solved.
5. **Ordering between plugins is asserted in prose, never enforced.** Every plugin's directive has a "COMPOSITION" paragraph claiming which plugin "decides" what (e.g. warrant/`directive.sh:132`: "freelunch decides how the approved work is executed... doctrine decides where documents land... This directive decides only what may begin and when"). Nothing arbitrates if two directives' injected text actually conflicts in a given turn (e.g. warrant says stop after writing the proposal; freelunch's width-conditional fan-out logic is silent on whether *proposal-writing itself* is a fan-out-eligible unit). All nine `UserPromptSubmit` hooks fire unconditionally and independently, concatenated by Claude Code in some hook-registration order that no file in this repo pins or documents; the "composition" is entirely a shared-vocabulary convention between prose blocks the model must reconcile itself, every turn.
6. **Hunter release is admittedly approximate, and the guard's cap is filesystem-global, not proposal-scoped.** `hunt-state.sh`'s own comment: "SubagentStop does not say WHICH subagent stopped, so an unrelated worker finishing can drop a live hunter's lock." `hunt-guard.sh`'s `.warrant-hunt.count` is per-repo-root for the whole session, not per-proposal, so `WARRANT_HUNT_MAX` (default 3) is a session-wide budget shared across however many proposals land in one session — the directive's "two hunters per unit" design can starve a second or third unit in the same session with no signal beyond a terse refusal ("N hunters already dispatched… No more until the count file is cleared").
7. **Malformed/missing-file handling is inconsistent by design across plugins, and that inconsistency isn't documented as a cross-cutting rule.** warrant's gates deliberately fail *closed* on a readable-but-malformed proposal (`scope-gate.sh:298-306`, "an unreadable warrant is how a gate quietly stops existing") but fail *open* on missing `python3` or unreadable payload (`scope-gate.sh:170`, `case`-guarded). doctrine's `placement-gate.sh` fails open on the same classes of input problem (its own header: "Fails open. A missing python3, unreadable payload, or unexpected schema lets the write through"). Two plugins in the same stack made opposite choices about the same failure class for defensible but different reasons, and nothing states the general rule a third rulebook should copy — a builder has to infer it from two READMEs' worth of prose rather than from one stated principle.

## What the new role rulebooks should copy, and what they should not

**Copy:**
- Warrant's actual shape for a state machine: state lives in a single frontmatter field (`status:`) inside a file the repo already has a reason to keep (the proposal), not a bespoke sidecar; the `PreToolUse` gate re-derives all enforcement from that one field plus the proposal's own `files:` list on every call, rather than caching a decision. This is the one part of this repo that is genuinely a load-bearing, tested state machine, and its test matrix (traversal, empty/over-broad write sets, several spellings of the trailer command, malformed frontmatter, monorepo sub-proposals) is the right shape for a completeness check on the new gates.
- The fail-open/fail-closed distinction as a *stated, deliberate* choice, not an accident: decide, for each new gate, whether "cannot parse my own input" should deny (state-integrity questions — the new rulebooks' whole purpose) or allow (missing interpreter — infrastructure absence), and write down which and why, rather than letting each of the four sibling gates converge on a different answer independently (the state-gate-path-resolution proposal I read in this workspace exists precisely because three of the four new gates picked "fall through to allow on an unresolvable Bash write target" and had to be walked back to "deny on ambiguity").
- The `X_OFF` kill-switch idiom and its "off means off, not falsy" comment, verbatim — it is duplicated correctly nine times in this repo and is worth keeping as one shared convention across the four new rulebooks too, since each will need its own kill switch.
- Doctrine's honesty about a directive's measured failure rate — ship the ablation, including the runs where it did nothing, rather than asserting the directive works.

**Do not copy:**
- The assumption, baked into every scope/root-resolution routine in this repo (`scope-gate.sh`, `hunt-guard.sh`, `hunt-state.sh`), that `CLAUDE_PROJECT_DIR` (or its git-toplevel fallback) names exactly one repo whose `docs/proposals/` is the only one that matters. The four new rulebooks live as siblings under one non-git workspace directory, which is exactly the layout this repo's own root-resolution code gets wrong, and I reproduced the wrong behavior directly. Each new rulebook's `state-gate.sh` needs to anchor on its **own** rulebook directory (`ops-agent-rulebook/`, etc.) explicitly, not on whatever `CLAUDE_PROJECT_DIR`/git-toplevel happens to resolve to in a multi-repo workspace — and that anchoring choice needs its own test case, not an inherited one.
- Treating "a `PreToolUse` gate exists" as proof the surface is covered. Confirm the hook's `matcher` in `hooks.json` actually matches only the tool calls the header comment claims — warrant's own gate does not (item 2 above), and a state-gate meant to guard one record file should be checked against `Read`, `Glob`, and `Grep` calls too, not just the write-shaped tools its comment names.
- Composing plugins purely through shared vocabulary in independent prose blocks with no arbitration. If the four new role rulebooks are meant to hand off to each other (product → feasibility → review → ops), that handoff needs at least one file (state, not prose) that all four gates can check, rather than four independently-written "COMPOSITION" paragraphs each asserting what it assumes the others do.
- freelunch's pattern of shipping a mechanical enforcement path that is off by default and only exercised under an explicit env var — if a new rulebook's approval-token minting or gate logic has a "real" enforced mode and a permissive observe-only mode, ship with enforcement **on**, or state loudly in the top-level README which mode new installs get, since this repo's own README does not mention that `FREELUNCH_ENFORCE` defaults unset anywhere outside the hook script's internal comment.
