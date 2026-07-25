---
status: landed
files:
  - feasibility-agent-rulebook/feasibility-cycle/hooks/state-gate.sh
  - product-agent-rulebook/product-cycle/hooks/state-gate.sh
  - review-agent-rulebook/review-cycle/hooks/state-gate.sh
  - ops-agent-rulebook/ops-cycle/hooks/state-gate.sh
---

## 1. Intent

A reproduced bypass in `feasibility-cycle`'s state gate lets a Bash write reach `feasibility-record.md` through a shell variable (`f=feasibility-record.md; ... > "$f"`), because the gate's Bash-detection regex requires the literal filename text to appear at the redirect site and silently allows anything it doesn't match. The fix is to make every new-role gate (`feasibility`, `product`, `review`, `ops`) judge Bash writes by the write's resolved target path and fail closed whenever that path cannot be determined, instead of pattern-matching literal filename text.

## 2. Constraints that change what gets built

- Per-repo independence: each of the four rulebooks implements its own fix in its own `hooks/state-gate.sh`. No shared library file, no new cross-repo dependency, no repo importing another repo's gate logic.
- `coding-agent-rulebook` and `qa-agent-rulebook` are out of scope and must not be touched, read, or referenced as targets for this change.
- The gate never decides applicability from the tool name (`Bash` vs `Write` vs `Edit`); applicability is decided by whether the call's resolved write target can reach the guarded state file's path. A `Bash` call and a `Write` call are judged by the identical question: does this write's target path equal the state file's resolved path?
- Silence-on-ambiguity is the defect being fixed: if a Bash command's write target cannot be determined statically (variable, parameter/command/arithmetic expansion, indirection via `eval`/`$(...)`, a heredoc into a computed filename), the gate must DENY, not fall through to `allow()`.

## 3. What will be done, per repo

**feasibility-agent-rulebook/feasibility-cycle/hooks/state-gate.sh**
The Bash branch currently matches only against `write_shapes`, a regex requiring the literal substring `feasibility-record.md` immediately after a redirect/tee/sed -i operator (confirmed in the reproduction: `f=feasibility-record.md; printf ... > "$f"` never matches, and the branch falls through to `allow()` with no content check). Replace this with: (a) extract every redirection/tee/cp/mv/sed -i/heredoc target token the command contains, via the existing operator-position regexes; (b) for each token, if it is a literal path (no `$`, no backticks, no command substitution, no obvious variable reference), resolve it against the project root and compare to the resolved state-file path; (c) if the command contains a write-shaped construct (redirect, tee, cp, mv, sed/perl/ruby -i, dd, install, truncate, heredoc) but at least one target token is non-literal (contains `$`, backticks, `$(...)`, or is an unquoted bare word that isn't a plain relative/absolute path), deny outright rather than skip it. Only commands with zero write-shaped constructs at all are allowed through untouched.

**product-agent-rulebook/product-cycle/hooks/state-gate.sh**
Already resolves Bash targets through `BASH_TARGET_RE` + `posixpath.realpath` (lines 94–133), which is closer to the intended design than the other three, but it has the same underlying hole: `BASH_TARGET_RE` captures whatever token sits after the operator — if that token is `"$f"` or `` `x` `` it gets treated as a literal path segment, `posixpath.realpath` will resolve it as a real (wrong) relative path under `root`, the comparison to the guarded record path will fail, and the call falls through to `allow()` at line 133 ("not writing a file we can identify"). Fix: before resolving `cand` as a path, reject the command outright (deny, not allow) if `cand` (or any other write-shaped target found in the same command) contains `$`, backticks, or command/parameter-expansion syntax. The "no target found" branch at line 129–133 must only `allow()` when the command contains no write-shaped construct at all (redirect/tee/sed -i); if a write-shaped construct is present but no literal target could be extracted, deny.

**review-agent-rulebook/review-cycle/hooks/state-gate.sh**
The gate is explicitly substring/name-based by its own comment (lines 195–211): it treats a command as a candidate write only `if state_name in command` (the literal basename `review-record.md` appears verbatim) `and write_indicators.search(command)`. A command that reaches the file only via a variable (`f=review-record.md; ... > "$f"`) never contains the literal basename, so `state_name in command` is false, `touches_state` stays `False`, and the call is allowed with no content check — the same class of bypass as feasibility's, just structured as a substring check instead of a single regex. Fix: change the write-shaped-construct branch so that when the command matches `write_indicators` (redirect/tee/cp/mv/sed -i/etc.) but the state file's literal basename is NOT found in the command, the gate does not default to "not a candidate" — it must check whether the write-shaped target token is a non-literal reference (variable/expansion/substitution) and, if so, deny rather than fall through un-gated.

**ops-agent-rulebook/ops-cycle/hooks/state-gate.sh**
`bash_targets()` (lines 89–101) extracts the captured token from `REDIRECT_RE`/`TEE_RE`/`CP_MV_RE`/`SED_I_RE` and resolves it with `resolve()`; if the token is `"$f"` it resolves to a path literally named `$f` (or similar), which will not equal `state_abs`. The fallback at lines 116–123 catches only the case where the state file's path/basename is *named literally elsewhere* in the command (`state_rel in command or state_abs in command`), returning `"maybe"` (gated) for that case only. A pure-variable write (`f=ops/state.md; cmd > "$f"`) matches neither the direct resolution nor the literal-substring fallback, so `touches_state_file()` returns `False` and the call is allowed at line 128. Fix: extend `bash_targets()` (or its caller) so that any extracted target token containing `$`, backticks, or expansion syntax is treated as unresolvable, and unresolvable-but-write-shaped commands are folded into the same `"maybe"` (gated) path that lines 116–123 already use for literal-substring matches — never into the `False` (allowed) path.

## 4. Out of scope

- `coding-agent-rulebook` and `qa-agent-rulebook` — not read, not touched, not part of this write set.
- Any shared/common gate library or helper file — each repo's fix stays self-contained in its own `hooks/state-gate.sh`.
- Full shell parsing/execution to compute exact resolved targets of arbitrarily complex expansions — the fix only needs to reliably detect *that* a write-shaped target is non-literal (variable/expansion/substitution present) and deny; it does not need to compute what the variable would expand to.
- Changes to the approval-token mechanism, the state-machine transition tables, or any content-check logic beyond the path-resolution/applicability layer.
- Non-Bash tool handling (`Write`/`Edit`/`NotebookEdit` path resolution) in the three repos where it is already sound; only touched if a repo's existing Write/Edit path resolution shares the same fall-through-to-allow defect.

## 5. How we will know it worked

For each of the four repos, the following bypass command shape — piped as a `PreToolUse` payload for a `Bash` call whose command indirects the write target through a shell variable instead of naming the guarded state file literally — must be DENIED (non-zero exit, deny message), not silently allowed:

```
f=<state-file-basename>; printf -- "---\nstatus: <next-state>\n---\n" > "$f"
```

(and the equivalent forms: `` `echo <state-file-basename>` ``, `cmd >"$(printf %s <state-file-basename>)"`, `eval "cmd > $f"`, a heredoc redirected into a variable-held filename). A command with the same write-shaped construct but naming an unrelated file (e.g. `f=notes.md; ... > "$f"`) must still be ALLOWED — the fix must not deny every ambiguous Bash write globally, only those that plausibly reach the guarded state file's directory/basename or that the gate cannot rule out. Success is: bypass reproduction denied in all four repos, existing legitimate literal-path writes (as already covered by each repo's test/reproduction fixtures) still allowed.

## What did not work

- Expected the fail-closed rule to apply only to writes aimed at the role's state file; in ops-agent-rulebook the unresolvable-target deny fires globally, before the target is compared to `ops/state.md`, so ordinary shell commands that never name the state file are refused. Reproduced by the before-landing hunter; see docs/reports/2026-07-26-hunt-state-gate-path-resolution.md.
- The `PreToolUse` matcher in ops-cycle/hooks/hooks.json is `.*`, so the gate is consulted for every tool call; combined with the global deny above this makes the ops readiness-checklist skill's own requirement unsatisfiable.
