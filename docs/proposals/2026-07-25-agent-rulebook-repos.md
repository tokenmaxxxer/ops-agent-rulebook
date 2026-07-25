---
status: landed
files:
  - product-agent-rulebook/README.md
  - product-agent-rulebook/.gitignore
  - product-agent-rulebook/.claude-plugin/marketplace.json
  - product-agent-rulebook/install.sh
  - product-agent-rulebook/product-agent-env/.claude-plugin/plugin.json
  - product-agent-rulebook/product-cycle/.claude-plugin/plugin.json
  - product-agent-rulebook/product-cycle/hooks/hooks.json
  - product-agent-rulebook/product-cycle/hooks/state-gate.sh
  - product-agent-rulebook/product-cycle/hooks/capture-approval.sh
  - product-agent-rulebook/product-cycle/skills/
  - product-agent-rulebook/docs/README.md
  - product-agent-rulebook/docs/specs/state-machine.md
  - product-agent-rulebook/docs/specs/README.md
  - product-agent-rulebook/docs/handbooks/README.md
  - product-agent-rulebook/docs/decisions/README.md
  - product-agent-rulebook/docs/reports/README.md
  - product-agent-rulebook/docs/proposals/README.md
  - product-agent-rulebook/docs/_assets/README.md
  - feasibility-agent-rulebook/README.md
  - feasibility-agent-rulebook/.gitignore
  - feasibility-agent-rulebook/.claude-plugin/marketplace.json
  - feasibility-agent-rulebook/install.sh
  - feasibility-agent-rulebook/feasibility-agent-env/.claude-plugin/plugin.json
  - feasibility-agent-rulebook/feasibility-cycle/.claude-plugin/plugin.json
  - feasibility-agent-rulebook/feasibility-cycle/hooks/hooks.json
  - feasibility-agent-rulebook/feasibility-cycle/hooks/state-gate.sh
  - feasibility-agent-rulebook/feasibility-cycle/hooks/capture-approval.sh
  - feasibility-agent-rulebook/feasibility-cycle/skills/
  - feasibility-agent-rulebook/docs/README.md
  - feasibility-agent-rulebook/docs/specs/state-machine.md
  - feasibility-agent-rulebook/docs/specs/README.md
  - feasibility-agent-rulebook/docs/handbooks/README.md
  - feasibility-agent-rulebook/docs/decisions/README.md
  - feasibility-agent-rulebook/docs/reports/README.md
  - feasibility-agent-rulebook/docs/proposals/README.md
  - feasibility-agent-rulebook/docs/_assets/README.md
  - review-agent-rulebook/README.md
  - review-agent-rulebook/.gitignore
  - review-agent-rulebook/.claude-plugin/marketplace.json
  - review-agent-rulebook/install.sh
  - review-agent-rulebook/review-agent-env/.claude-plugin/plugin.json
  - review-agent-rulebook/review-cycle/.claude-plugin/plugin.json
  - review-agent-rulebook/review-cycle/hooks/hooks.json
  - review-agent-rulebook/review-cycle/hooks/state-gate.sh
  - review-agent-rulebook/review-cycle/hooks/capture-approval.sh
  - review-agent-rulebook/review-cycle/skills/
  - review-agent-rulebook/docs/README.md
  - review-agent-rulebook/docs/specs/state-machine.md
  - review-agent-rulebook/docs/specs/README.md
  - review-agent-rulebook/docs/handbooks/README.md
  - review-agent-rulebook/docs/decisions/README.md
  - review-agent-rulebook/docs/reports/README.md
  - review-agent-rulebook/docs/proposals/README.md
  - review-agent-rulebook/docs/_assets/README.md
  - ops-agent-rulebook/README.md
  - ops-agent-rulebook/.gitignore
  - ops-agent-rulebook/.claude-plugin/marketplace.json
  - ops-agent-rulebook/install.sh
  - ops-agent-rulebook/ops-agent-env/.claude-plugin/plugin.json
  - ops-agent-rulebook/ops-cycle/.claude-plugin/plugin.json
  - ops-agent-rulebook/ops-cycle/hooks/hooks.json
  - ops-agent-rulebook/ops-cycle/hooks/state-gate.sh
  - ops-agent-rulebook/ops-cycle/hooks/capture-approval.sh
  - ops-agent-rulebook/ops-cycle/skills/
  - ops-agent-rulebook/docs/README.md
  - ops-agent-rulebook/docs/specs/state-machine.md
  - ops-agent-rulebook/docs/specs/README.md
  - ops-agent-rulebook/docs/handbooks/README.md
  - ops-agent-rulebook/docs/decisions/README.md
  - ops-agent-rulebook/docs/reports/README.md
  - ops-agent-rulebook/docs/proposals/README.md
  - ops-agent-rulebook/docs/_assets/README.md
  - qa-agent-rulebook/install.sh
---

# Agent rulebook repositories: product, feasibility, review, ops

## Intent

Each of the four new agent roles specified in `docs/specs/agent-roles.md` —
`product`, `feasibility`, `review`, `ops` — gets its own rulebook repository,
built to that role's state machine, created both locally under
`/home/jwjung/tokenmaxxxer/` and remotely under the `tokenmaxxxer` GitHub
organization. This proposal supersedes
`docs/proposals/2026-07-25-product-agent-rulebook-repo.md`, which covered
`product` alone and deferred the remote.

## Why the remote is now in scope

Checked facts: the authenticated `gh` account `JiwonJung94` holds `admin`
role with `active` state in the `tokenmaxxxer` organization; org policy has
`members_can_create_repositories: true` for both public and private
repositories; the token in use carries the `repo` scope. Creating org
repositories under `tokenmaxxxer` is therefore possible.

The earlier proposal deferred the remote on a mistaken reading: it treated
`gh repo list` — which by default lists only the authenticated user's own
repositories, not repositories owned by an organization the user belongs to
— as evidence that org access was absent. `tokenmaxxxer`'s repositories not
appearing in `JiwonJung94`'s own repo list was misread as lacking permission
to create them, when the correct check is the org membership role and org
repo-creation policy, both of which permit it.

## What the hunt found, and how this proposal answers it

`docs/reports/2026-07-25-hunt-product-agent-rulebook-repo.md` found a design
error in the superseded proposal: its write set named only one hook,
`product-cycle/hooks/state-gate.sh`, a `PreToolUse` gate that *checks* for
"a recorded approval token... from the user's own turn" before allowing
`hypothesis-registered -> measuring`. Nothing in that write set ever writes
such a token — the gate was specified to check state that had no writer,
so the checked transition would either be permanently refused (fail-closed
on missing state) or, worse, get a free-lanced substitute later that infers
approval from file content, directly reintroducing the "content is not
consent" failure the spec rules out.

The sibling repository `qa-agent-rulebook` already carries the working
example of the missing half:
`qa-agent-rulebook/signoff/hooks/capture-verdict.sh`, registered on
`UserPromptSubmit`, reads the literal text of the user's own turn, detects
an unambiguous verdict (rejecting bare assent like "ok"/"sounds good"),
and mints a single-use token file bound to a specific item id and a
specific `(from, to)` transition pair — which a separate `PreToolUse` gate
then only reads.

Every one of the four repositories in this proposal carries both halves of
that pattern, and both halves are named in the write set: a minting hook
registered on `UserPromptSubmit` (`hooks/capture-approval.sh` in each
repository) that reads the user's own turn and writes an approval-token
file bound to the carrying state file and the specific gated transition,
and a checking gate registered on `PreToolUse` (`hooks/state-gate.sh`) that
refuses the gated transition unless that token file exists and matches.
No gate in this proposal checks for a token nothing writes.

## Constraints already settled

- Each repository is fully self-contained and independently installable
  into its own sandbox. No shared code, no cross-repo dependency, no
  shared file, no shared index or ledger between any of the four, or with
  `coding-agent-rulebook` or `qa-agent-rulebook`.
- Current constraint (changed from this same proposal's earlier statement
  below): `coding-agent-rulebook` is not modified and is read as a
  structural reference only. `qa-agent-rulebook` now receives exactly one
  new file, its own `install.sh`, and nothing else in it is touched. This
  reverses the earlier constraint stated further down in this same
  proposal — under "Per-repository install and marketplace" and "Out of
  scope" — that `qa-agent-rulebook` would not be modified at all. Read the
  two as sequential, not contradictory: this bullet states the constraint
  that now governs.
- Each role implements its own state machine independently. The four state
  machines are exactly as specified in `docs/specs/agent-roles.md` (Part 3)
  — not restated here; each repository's `docs/specs/state-machine.md`
  transcribes its own role's table, rejection rule, and per-state refusals
  in that repository's own words, since the repository must be
  self-contained and not depend on reading the spec repository at runtime.
- Rejection rules are evaluated against the path being written, never
  against which tool performs the write. A guard that inspects only
  file-editing tool payloads is bypassed by the same edit made through a
  shell command (`echo ... > file`, `sed -i`, `tee`); each gate must
  resolve the target path or command string regardless of which tool
  produced it, mirroring `coding-agent-rulebook/warrant/hooks/scope-gate.sh`.
- Each gate fails closed when its own input is malformed: unparseable tool
  payload, unparseable or missing state file, missing or malformed token
  file — any of these denies the transition; none falls through to allow.
- The user does all coordination by hand; no machinery is added to
  automate carrying an artifact from one role's repository to another's.
- Repository visibility is **private** at creation. Reason: private-to-
  public is a one-step, low-risk change available at any time, whereas
  public-to-private after a repository has been indexed and possibly
  mirrored or scraped is not cleanly reversible. `coding-agent-rulebook`
  and `qa-agent-rulebook` are already public; matching them is a later,
  separate decision, not this one.

## Per-repository install and marketplace

Verified state of the two existing repositories: the marketplaces are
already separate. `coding-agent-rulebook/.claude-plugin/marketplace.json`
declares `"name": "tokenmaxxxer-coding"`, and
`qa-agent-rulebook/.claude-plugin/marketplace.json` declares
`"name": "tokenmaxxxer-qa"`. Each manifest's plugin `source` values are
`./`-relative to its own repository, so installing one pulls in nothing
from the other. Each already carries a bundle plugin
(`coding-agent-env`, `qa-agent-env`) that contains no code of its own and
lists only that same repository's role plugins as dependencies. But
`install.sh` exists only in `coding-agent-rulebook`; `qa-agent-rulebook`
has none, so its users must run the marketplace-add and plugin-install
commands by hand. Plainly: the assumption "both were built this way"
holds for the marketplace split and does NOT hold for the install script.

The four new repositories follow this convention, frozen for this build:

- Each repository declares its OWN marketplace, named
  `tokenmaxxxer-<role>` — `tokenmaxxxer-product`, `tokenmaxxxer-feasibility`,
  `tokenmaxxxer-review`, `tokenmaxxxer-ops`. No shared marketplace name.
- Every plugin `source` in a manifest is `./`-relative to that repository.
  No manifest names another repository.
- Each repository carries its own bundle plugin `<role>-agent-env`,
  containing no code of its own, listing that repository's role plugins
  as dependencies — matching what the two existing bundles do.
- Each repository carries its OWN `install.sh` at its root. It registers
  only its own marketplace from GitHub source
  `tokenmaxxxer/<role>-agent-rulebook`, then installs that repository's
  plugins and its own bundle, at user scope. It names no other repository
  and no other marketplace. Following `coding-agent-rulebook/install.sh`,
  it prefers the `claude` CLI and falls back to merging
  `extraKnownMarketplaces` and `enabledPlugins` into
  `~/.claude/settings.json`, backing that file up first and following
  symlinks rather than replacing them.
- This convention now extends to five repositories: the four new ones plus
  `qa-agent-rulebook`. `qa-agent-rulebook` already has its own marketplace
  (`tokenmaxxxer-qa`) and its own bundle plugin (`qa-agent-env`) with
  `./`-relative sources, so the only missing piece is the install script;
  adding it brings that repository to the same install convention as the
  others. Its `install.sh` registers only marketplace `tokenmaxxxer-qa`
  from GitHub source `tokenmaxxxer/qa-agent-rulebook`, installs that
  repository's own plugins (`intake`, `testrun`, `bugreport`, `stats`,
  `regress`, `qa-cycle`, `signoff`) and the `qa-agent-env` bundle at user
  scope, and names no other repository or marketplace.

Because these install scripts are shell that writes into a user
configuration file, each follows two rules: the settings-file path is
resolved and prefix-checked against the user's home directory before any
write, and a parse failure of existing settings aborts with the original
file untouched rather than overwriting it. The same two safety rules apply
to `qa-agent-rulebook/install.sh`.

## What will be done

For each of the four repositories, in this order — `product`,
`feasibility`, `review`, `ops`:

- `git init` locally under `/home/jwjung/tokenmaxxxer/<name>-agent-rulebook/`,
  with an initial commit carrying a `Proposal:
  docs/proposals/2026-07-25-agent-rulebook-repos.md` trailer.
- `gh repo create tokenmaxxxer/<name>-agent-rulebook --private --source .
  --remote origin --push`, adding the org remote and pushing the initial
  commit.
- A plugin scaffold mirroring the conventions found in
  `coding-agent-rulebook`: a top-level `.claude-plugin/marketplace.json`
  registering the plugin (matching the shape of
  `coding-agent-rulebook/.claude-plugin/marketplace.json`'s `name`/
  `owner`/`plugins` entries), the plugin directory's own
  `.claude-plugin/plugin.json` manifest, a `hooks/hooks.json` hook
  registration, and a `skills/` directory for the plugin's skill content.
  The plugin directory is named per role: `product-cycle`,
  `feasibility-cycle`, `review-cycle`, `ops-cycle` — as instructed, no
  departure from those names was needed; `coding-agent-rulebook`'s own
  per-plugin directories (`warrant`, `dispatch`, `doctrine`, `scout`, …)
  confirm one-plugin-per-directory-name is the live convention, and
  `<role>-cycle` was already the name `qa-agent-rulebook` uses for its
  own equivalent plugin (`qa-cycle`), so it is followed here for
  consistency across the org's rulebooks, not invented fresh.
- A named state file convention and a named state field, documented in
  that repository's `docs/specs/state-machine.md`: the carrying artifact
  and `status` frontmatter field `docs/specs/agent-roles.md` names for
  that role (the specification file for `product`, the feasibility record
  for `feasibility`, the review record for `review`, the
  readiness/rollout record plus its checklist section for `ops`).
- Two cooperating hooks implementing that role's transition table and
  rejection rules from the spec:
  - `hooks/capture-approval.sh`, a `UserPromptSubmit` hook mirroring
    `qa-agent-rulebook/signoff/hooks/capture-verdict.sh`'s discipline: it
    reads only the literal text of the user's own turn, requires an
    explicit, unambiguous statement of the gated decision (rejecting bare
    assent), binds the resulting token to the specific carrying file and
    the specific `(from, to)` transition pair for that role's gated
    transitions (`hypothesis-registered -> measuring` for `product`;
    `probing -> verdict` for `feasibility`; `auditing -> reported` for
    `review`; `readiness -> rollout` and `rollout -> steady` for `ops`),
    and never blocks — malformed input, no identifiable transition, or an
    ambiguous verdict all mean: mint nothing, exit clean.
  - `hooks/state-gate.sh`, a `PreToolUse` gate that refuses a gated
    transition unless the token minted above exists, matches the file and
    transition, and — where the rule also depends on file content (e.g.
    `product`'s metric/threshold/decision-rule fields, `feasibility`'s
    four probe fields, `review`'s per-requirement verdicts, `ops`'s
    checklist-with-pointer rule) — that content condition is also met.
    Content alone, without the token, never passes.
- The six `docs/` buckets (`specs/`, `handbooks/`, `decisions/`,
  `reports/`, `proposals/`, `_assets/`), matching
  `coding-agent-rulebook`'s docs bucket layout, each with a `README.md`.
- A README covering what the role does, what it is given to start, what
  it produces, and how to install the plugin into a sandbox, following the
  install-path convention shown by `coding-agent-rulebook/install.sh` and
  its README's install section.

**Not executed or verified in this work**: for all four repositories, the
hooks are written but not exercised against a live session — no test run
drives a real tool call through either hook, no state file is walked
through its role's states, and no approval-token mint-then-check round trip
is rehearsed end to end.

Additionally, for `qa-agent-rulebook`: write `qa-agent-rulebook/install.sh`,
following `coding-agent-rulebook/install.sh`'s conventions but registering
only marketplace `tokenmaxxxer-qa` from GitHub source
`tokenmaxxxer/qa-agent-rulebook`, then commit it in that repository with a
`Proposal: docs/proposals/2026-07-25-agent-rulebook-repos.md` trailer and
push to its existing remote. This is the only change made to that
repository.

## Out of scope

- Any modification to `coding-agent-rulebook` or `qa-agent-rulebook`.
- Making any of the four repositories public, or adding branch protection,
  CI, or issue templates.
- Any shared file or cross-repository mechanism, including between the
  four new repositories themselves.
- Resolving the design/UX open question recorded in
  `docs/specs/agent-roles.md`.
- Running or testing the hooks against a live session.
- No other file in `qa-agent-rulebook` is modified, and
  `coding-agent-rulebook` is not modified at all.

## How we will know it worked

Four repositories exist locally under `/home/jwjung/tokenmaxxxer/` and at
`github.com/tokenmaxxxer/<name>-agent-rulebook`, each private, each with an
initial commit carrying the `Proposal:
docs/proposals/2026-07-25-agent-rulebook-repos.md` trailer. Each plugin
(`product-cycle`, `feasibility-cycle`, `review-cycle`, `ops-cycle`)
installs into a sandbox alone with no other rulebook repository present
and functions without reaching outside itself. For each role, every
transition in that role's table in `docs/specs/agent-roles.md` (Part 3)
has a corresponding rule in that repository's `state-gate.sh` — an
enforced check or an explicit no-op where no machine check applies — each
gated transition's rejection is expressed as a condition on a file path
or file content, never as an instruction directed at the model, and the
approval token that gate checks has a named writer
(`hooks/capture-approval.sh`) in the same repository. Each of the five
repositories — the four new ones plus `qa-agent-rulebook` — has an
`install.sh` at its root that references only its own repository and its
own marketplace name, and installing any one of the five into a clean
sandbox brings in that repository's plugins and nothing from any sibling.
