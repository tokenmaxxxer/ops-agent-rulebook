---
name: issue-39-current-state-survey
subject: issue-39
role: release-engineering
status: survey
---

# Current-state survey — issue #39 (재감사 잔여 결함, A- → A+)

Prerequisites pulled and confirmed landed before this survey:
core `tokenmaxxxer-core` issue #75 (PR #76/#77, commit `52bdc15`) and
on-the-record issue #182 (PR #183/#185). Canon form read from
`docs/handbooks/gate-house-standard.md` and `core/hooks/lib/gate-lib.sh`
in a fresh clone of `tokenmaxxxer/tokenmaxxxer-core`.

## Confirmed canon shape (core #75)

- Mandatory guarded source line:
  `. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "<gate-name>.sh: cannot source gate-lib.sh" >&2; exit 2; }`
  — no `||` guard is the confirmed fail-open defect (unreachable core →
  127 on any `gate_kill_switch_active` call → reads as kill-switch-off →
  silent allow).
- `gate-lib.py` now has `gate_bash_write_targets(command)`, sh/py parity
  with `gate-lib.sh`'s `gate_bash_write_targets`.
- `core/hooks/tests/run-gate-lib-tests.sh` makes 7 case groups mandatory
  per gate suite: `replace_all` single-occurrence, MultiEdit mixed
  `replace_all`, malformed JSON (3 shapes), kill-switch unrecognized-value
  stays active, absolute/`./`-prefixed path parity, Bash-write-target
  parity (sh/py), and **missing-core deny** (`CLAUDE_PLUGIN_ROOT_CORE`
  pointed at a nonexistent path with no valid relative fallback → must
  assert exit 2, not silent allow).
- `core/hooks/tests/compliance-check.sh [hooks-dir]` flags: hand-rolled
  kill switch reading `*_OFF` without `gate_kill_switch_active`; hand-rolled
  `.replace(old, new[, 1])` reconstruction instead of
  `gate_reconstruct_write`; and an unguarded `gate-lib.sh` source line.

## This repo's five field-gates, checked against that canon

| gate | sources gate-lib.sh | guard present | uses gate_reconstruct_write | uses gate_kill_switch_active | Bash-tool matcher | mandatory test cases present |
|---|---|---|---|---|---|---|
| `readiness-checklist/hooks/readiness-fields-gate.sh` | yes (issue-36) | **no** — line 2 is a bare `. "$path"`, no `\|\|` | yes | yes | no | 6/7 present (missing #7 missing-core) |
| `proposal-norm/hooks/proposal-fields-gate.sh` | no | n/a | no (hand-rolled `.replace(o, n, 1)`) | no (hand-rolled `case ... esac`, unrecognized value **disables**) | no | 4 fixture cases only (missing Edit, MultiEdit/replace_all, malformed-JSON, kill-switch-unrecognized, absolute-path, missing-core = 6 short) |
| `postmortem/hooks/postmortem-review-gate.sh` | no | n/a | no | no (same hand-rolled `case`) | no | no dedicated `allow-deny-check.sh` mandatory-case coverage beyond the shared `deny-only-check.sh` substance probe |
| `error-budget-policy/hooks/error-budget-gate.sh` | no | n/a | no | no (same hand-rolled `case`) | no | same as postmortem |
| `rollout-plan/hooks/rollout-plan-fields-gate.sh` | no | n/a | no | no (same hand-rolled `case`) | no | same as postmortem |

Verified directly (`grep` against each gate file): the four unmigrated
gates all still use `case "${X_OFF:-}" in ""\|0\|false\|no\|off) ;; *)
exit 0 ;; esac` — the confirmed fail-open shape (**any unrecognized
value, including a typo, disables the gate**) — and all use
`current.replace(o, n, 1)` in Edit and a loop of the same in MultiEdit,
ignoring `replace_all`. This matches the issue's "나머지 4개 플러그인
스위트 2~4케이스(의무 6케이스 미달)" line exactly: `proposal-norm` has 4
of the mandatory cases, the other three have effectively 0 dedicated
mandatory-case fixtures.

`readiness-checklist` itself is not clean either: its source line lost the
`\|\|` guard because it migrated (issue-36) before core #75 existed. It
needs the guard added and the missing-core (#7) test case, same as the
other four need the full migration.

## `cd` 이탈 시 allow

None of the five `hooks.json` in this repo register a `Bash` matcher —
every one is `"matcher": "Write\|Edit\|MultiEdit"` only (confirmed by
reading all five `hooks/hooks.json` files). A `Bash` tool call that writes
through a shell redirect or `cd`-then-write
(e.g. `cd ../.. && echo x >> docs/issue-N/proposals/foo.md`, or any
`Bash` command reaching a protected path) never invokes any of these five
gates at all — the PreToolUse hook simply never fires for that tool name,
which is indistinguishable from an explicit allow at the point of use.
`gate_bash_write_targets` (both languages, parity-tested per core #75)
exists specifically to let a gate also cover `Bash`-tool write attempts,
but no gate here calls it and no matcher here includes `Bash`.

## parse-check 인자 오파싱

`tests/parse-check.sh` defaults its directory argument to
`.../ops/hooks` only (line 35:
`dir="${1:-$(cd ".../../ops/hooks" ...)}"`). README's documented
invocation is the no-argument form (`/bin/bash tests/parse-check.sh`),
and no other file in this repo calls it with an explicit directory
argument (`grep` across `*.sh`/`*.md`/`*.json` finds no second call
site). The no-arg default therefore silently bash-3.2-parses only the 2
files under `ops/hooks/` and never reaches the other five plugins'
`hooks/*.sh` (10 gate + directive files) or their `hooks/tests/*.sh`
fixtures — the documented "run the checks" step is not actually checking
most of the repo's shell.

## hooks.json matcher / code coverage

Matcher and code tool-name checks are internally consistent per gate
today (`Write\|Edit\|MultiEdit` matcher, `tool in ("Write","Edit",
"MultiEdit")` in code) — the mismatch is the missing `Bash` leg on both
sides, covered above, not a matcher/code disagreement within the existing
scope.

## README / manifest — old role name and ghost files

- Repo root `.claude-plugin/marketplace.json`: `"name":
  "tokenmaxxxer-ops"`, first plugin `"name": "ops"`.
- `README.md` title: `# tokenmaxxxer / ops-agent-rulebook`; body refers to
  "the `ops` role", "an `ops` session", `docs/issue-<n>/reports/ops.md`,
  branch `issue-<n>/ops`, `claude plugin marketplace add
  tokenmaxxxer/ops-agent-rulebook`, `claude plugin install
  ops@tokenmaxxxer-ops`.
- Git history confirms this is a genuine leftover, not current
  intent: the first commit is literally titled "Build ops-agent-rulebook:
  the ops role's plugin marketplace"; every commit since PR #26 (contract
  v3 restructure) uses the `deliver(release-engineering): ...` /
  `propose(release-engineering): ...` commit-message role tag, the repo
  itself is named `release-engineering-rulebook`, and the board-gate
  installed in this session enforces `issue-<n>/release-engineering` as
  the only valid branch name for this role — i.e. the ecosystem-wide
  canonical role name for this rulebook is `release-engineering`, and
  `ops` is exactly the old, unrenamed name issue #39 asks to zero out.
- Ghost file paths (referenced, not present): `readiness-checklist/skills/
  readiness-checklist/SKILL.md` cites `ops-cycle/skills/rollout-plan/
  SKILL.md`; `postmortem/skills/postmortem/SKILL.md` cites `ops-cycle/
  skills/postmortem/SKILL.md` and `ops-cycle/skills/postmortem/templates/
  postmortem-template.md`. No `ops-cycle/` directory exists anywhere in
  this repo (confirmed by `find`); the real paths are `rollout-plan/
  skills/rollout-plan/SKILL.md` and `postmortem/skills/postmortem/
  templates/postmortem-template.md` respectively.
- Not a ghost: `ops/state.md`, `ops/rollout-plan.md`,
  `ops/error-budget-policy.md`, `ops/postmortem-<id>.md` name the runtime
  *record* directory (`ops/`, the plugin-name-matching data dir used by
  the state machine), a separate concern from the plugin/role display
  name — left as-is unless the proposal decides otherwise.

## Scope not covered here (belongs to phase 2 / other issues)

- `on-the-record`'s `spawn.py` injection (#182) and core's own gate-lib
  fixes (#75) are already merged upstream; this repo only needs to
  *consume* the confirmed shapes, not re-derive them.
