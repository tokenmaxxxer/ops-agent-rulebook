
## after-proposal — stance 4: assume the write set cannot carry this work — find the path the build will need that the proposal does not list

Verdict: FINDING — proposal's README section commits to the `install.sh` install-path convention but the write set lists no `install.sh` path for any of the four repositories
Kind: design-error
Seed: docs/proposals/2026-07-25-agent-rulebook-repos.md ("What will be done" README bullet, line ~218), contrasted with its own `files:` frontmatter list and with coding-agent-rulebook/install.sh and qa-agent-rulebook (which has no install.sh and instead documents `/plugin marketplace add` + `/plugin install` by hand)

### Reproduce
grep -n "install.sh" /home/jwjung/tokenmaxxxer/docs/proposals/2026-07-25-agent-rulebook-repos.md
sed -n '/^files:/,/^---/p' /home/jwjung/tokenmaxxxer/docs/proposals/2026-07-25-agent-rulebook-repos.md | grep -c "install.sh"
find /home/jwjung/tokenmaxxxer/qa-agent-rulebook -iname install.sh   # confirm the alternative sibling convention has none

### Observed
The proposal text (line 218) says each repository's README follows "the install-path convention shown by `coding-agent-rulebook/install.sh` and its README's install section." The frontmatter `files:` write set, grepped for `install.sh`, returns `0` matches — no `<name>-agent-rulebook/install.sh` path is listed for any of the four repositories, and no bundle plugin (analogous to `coding-agent-env`/`qa-agent-env`) is listed either, even though `coding-agent-rulebook`'s install.sh installs the bundle it hardcodes by name.

### Expected
Either the write set should list an `install.sh` path (and a bundle plugin, if the convention is to be followed as literally as the README bullet promises), or the "What will be done" README bullet should not promise the install.sh convention at all and instead state the qa-agent-rulebook-style manual `/plugin marketplace add` + `/plugin install <plugin>@<marketplace>` instructions, which the write set already supports with only a marketplace.json and plugin.json.

## before-landing — stance 0: assume the gate just touched is bypassable — find the bypass

Verdict: FINDING — feasibility-cycle's state-gate.sh Bash-detection uses a literal-filename regex, so a Bash write to feasibility-record.md via shell variable indirection is allowed through untouched (never denied, no content check applied).
Kind: silent-failure
Seed: feasibility-agent-rulebook/feasibility-cycle/hooks/state-gate.sh (new repo), diff seed: four new *-agent-rulebook repos + qa-agent-rulebook/install.sh

### Reproduce
```
mkdir -p /tmp/gatetest && cd /tmp/gatetest
cat > feasibility-record.md <<'EOF2'
---
status: probing
technical: pass, evidence here
prior_art: pass, evidence here
legal_regulatory: pass, evidence here
threat_model: pass, evidence here
---
EOF2
export CLAUDE_PROJECT_DIR=/tmp/gatetest
PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"f=feasibility-record.md; printf -- \"---\\nstatus: verdict\\n---\\n\" > \"$f\""}}'
echo "$PAYLOAD" | /home/jwjung/tokenmaxxxer/feasibility-agent-rulebook/feasibility-cycle/hooks/state-gate.sh; echo "EXIT=$?"
# then actually run the same shell command in that directory:
(cd /tmp/gatetest && f=feasibility-record.md; printf -- "---\nstatus: verdict\n---\n" > "$f"); cat /tmp/gatetest/feasibility-record.md
```

### Observed
The hook prints nothing and exits 0 (allow) for the Bash payload, even though the underlying regex `write_shapes` requires the literal substring `feasibility-record.md` to appear immediately after the redirect operator. Because the command uses `"$f"` at the redirect site instead of the literal filename, the regex never matches, so the gate falls through to `allow()` at the bottom of the Bash branch. Actually executing that same command in the project directory overwrites `feasibility-record.md`'s frontmatter straight to `status: verdict`, skipping the probing state and the four-probe content check entirely, and with no approval-token requirement applied (the design doc says `probing -> verdict` is content-gated, no token even specified for this transition, so this is a pure content-check bypass).

### Expected
Per docs/specs/agent-roles.md Part 3 and the repository's own header comment ("a rejection rule is evaluated against the path being written, never against which tool performs the write... Bash command that would write to the record file is denied outright"), any Bash command whose *resolved target path* is feasibility-record.md should be denied, regardless of how the filename is spelled in the command text (literal, quoted, or held in a variable). The gate should resolve the actual write target (e.g. by parsing/executing-safely or maintaining a stricter denial default: deny any Bash call touching redirection/tee/sed-i/cp/mv syntax unless it can positively prove the target is NOT the guarded file), rather than pattern-matching literal filename text.
