---
status: landed
files:
  - product-agent-rulebook/product-cycle/hooks/state-gate.sh
  - product-agent-rulebook/product-cycle/hooks/transition-rules.md
  - product-agent-rulebook/.gitignore
  - product-agent-rulebook/product-cycle/hooks/run-gate-tests.sh
  - feasibility-agent-rulebook/feasibility-cycle/hooks/state-gate.sh
  - feasibility-agent-rulebook/feasibility-cycle/hooks/transition-rules.md
  - feasibility-agent-rulebook/.gitignore
  - feasibility-agent-rulebook/feasibility-cycle/hooks/run-gate-tests.sh
  - review-agent-rulebook/review-cycle/hooks/state-gate.sh
  - review-agent-rulebook/review-cycle/hooks/transition-rules.md
  - review-agent-rulebook/.gitignore
  - review-agent-rulebook/review-cycle/hooks/run-gate-tests.sh
  - ops-agent-rulebook/ops-cycle/hooks/state-gate.sh
  - ops-agent-rulebook/ops-cycle/hooks/transition-rules.md
  - ops-agent-rulebook/.gitignore
  - ops-agent-rulebook/ops-cycle/hooks/run-gate-tests.sh
---

# Same-state gate bypass and state-file tracking policy, across `product`, `feasibility`, `review`, `ops`

## Intent

`docs/reports/2026-07-28-hunt-role-workflow-plugins.md` reproduced a bypass
in `product-agent-rulebook/product-cycle/hooks/state-gate.sh` and confirmed
the same pattern in `feasibility-agent-rulebook/feasibility-cycle/hooks/state-gate.sh`:
when the parsed state field of a proposed write equals the state already on
disk, the gate does `allow()` immediately — `if new_stage == old_stage:
allow()` (product), `if old_status == new_status: allow()` (feasibility) —
before ever reading `transition-rules.md`. Reading `review-agent-rulebook/review-cycle/hooks/state-gate.sh`
and `ops-agent-rulebook/ops-cycle/hooks/state-gate.sh` for this proposal
shows the identical short-circuit in both (`if attempted_status ==
cur_status: allow()` in review; `if frm == to: allow()` in ops) — the hunt
only exercised two of the four repos, but the bypass is structural to all
four gates, not particular to product/feasibility. The practical
consequence: any write to a role's state file that leaves the state field
unchanged edits every other registered field — a metric, a threshold, a
decision rule, probe evidence, a verdict basis, an audit finding — with no
`actor: user` check and no row lookup in `transition-rules.md` at all. The
reproduction rewrote `product/state.md`'s `metric` and `threshold` fields
while holding `stage: hypothesis-registered` fixed and the gate exited 0.

A second, independent gap found while reading all four repos for this
proposal: they disagree on whether the role's state file is a tracked
artifact or a runtime one. `feasibility-agent-rulebook/.gitignore` ignores
`feasibility-record.md` and `ops-agent-rulebook/.gitignore` ignores
`ops/state.md`, each with a comment explaining the file is sandbox runtime
state that should never live in the plugin repository itself.
`product-agent-rulebook/.gitignore` and `review-agent-rulebook/.gitignore`
carry no such line for `product/state.md` / `review-record.md` — nothing
stops either file from being committed into the plugin repository by
accident in a local checkout used for testing.

## Constraints that change what gets built

- Every repo is self-contained: `product-agent-rulebook`,
  `feasibility-agent-rulebook`, `review-agent-rulebook`, and
  `ops-agent-rulebook` each implement this fix in their own copy of
  `state-gate.sh`. No shared file, no cross-repo import, no shared write
  target.
- `coding-agent-rulebook` and `qa-agent-rulebook` are out of bounds and are
  not touched by this proposal.
- The gate judges the resolved target path of a write, never a tool name,
  never a literal filename appearing in a command string; an unresolvable
  `Bash` write target aimed at the state file's own directory fails closed.
  This rule, frozen by `docs/reports/2026-07-26-hunt-conversational-state-machine.md`
  (the `2026-07-26-state-gate-path-resolution` fix already present in all
  four scripts read above), is unchanged by this proposal.
- Artifact writes — a spike report, a one-pager, a finding record, a
  rollout plan, a postmortem, anything that is not the role's own state
  file — stay ungated. Only the state file is gated, in every repo.
- `(none)` remains the synthetic bootstrap state in all four tables; it is
  never a legal `to` value and this proposal does not change that.

## What will be done

The following is the frozen contract for the build; the implementer
follows it verbatim in each of the four repos independently.

**Remove the same-state short-circuit.** In each `state-gate.sh`, delete
the branch that returns `allow()` (or exits 0) purely because the parsed
state field of the proposed write equals the state already on disk —
`product-agent-rulebook`'s `if new_stage == old_stage: allow()`,
`feasibility-agent-rulebook`'s `if old_status == new_status: allow()`,
`review-agent-rulebook`'s `if attempted_status == cur_status: allow()`, and
`ops-agent-rulebook`'s `if frm == to: allow()`. After the fix, a write whose
resulting state equals the current state is judged by
`transition-rules.md` exactly like any other transition: it is allowed only
if a row with `from == to` for that state exists (an explicit self-loop)
and, where that row is `actor: user`, its precondition is judged satisfied
from the user's own turn. Absence of such a row denies with the gate's
existing "this transition is not in the table" message — the same message
path already used for every other illegal transition, not a new denial
category.

**Add the self-loop rows that documented skill steps actually depend on, and
no others.** Reading all four `transition-rules.md` files, together with
every `SKILL.md` under each repo's `<role>-cycle/skills/`, for this
proposal shows most same-state edits already carry an explicit self-loop
row. But one is missing, and an after-proposal hunt
(`docs/reports/2026-07-29-hunt-same-state-gate-and-state-file-policy.md`)
reproduced the consequence of leaving it out: `product-cycle`'s
`hypothesis-testing/SKILL.md` step 5 documents, as normal in-state work,
"Update other fields (e.g. collected-data notes) freely; do not touch
`threshold`" while `status: measuring` — a same-state write with no
corresponding `measuring | measuring` row. Removing the short-circuit
without adding that row denies this documented step identically to the
illegal `metric`/`threshold` rewrite the proposal set out to block; the
gate cannot yet tell "append a progress note" from "quietly rewrite the
registered hypothesis." The row is added below to restore that
distinction, scoped narrowly (it does not, and must not, cover
`threshold`; the gate's separate `threshold`-immutability check in
`measuring`, described in the same skill, is unchanged by adding this row
and continues to deny any write that touches `threshold`).

Per-repo disposition:

- **product** (`product-cycle/hooks/transition-rules.md`) — ADD one row:
  `measuring | measuring | agent | a collected-data/progress field is being
  recorded while status: measuring; threshold is not among the changed
  fields (state-gate.sh's separate threshold-immutability check in
  measuring still applies and is not loosened by this row)`
  - Justification: `product-cycle/skills/hypothesis-testing/SKILL.md`,
    step 5 ("measuring"), which describes the agent recording
    collected-data notes on its own initiative, with no user
    approval/confirmation token required for that specific act — hence
    `actor: agent`, matching the other purely-agent self-loops already in
    this table (there are none in `product-cycle` today, but this mirrors
    `ops-cycle`'s `rollout | rollout | agent` pattern below).
  - No other same-state write was found in this repo's skills beyond the
    already-covered `scoping | scoping | user` (justified by
    `one-pager/SKILL.md`'s "How to run the conversation" section and
    `opportunity-solution-tree/SKILL.md`, both of which explicitly name
    the `scoping -> scoping` self-loop and require the user's own
    affirmation/sourcing each cycle).

- **feasibility** (`feasibility-cycle/hooks/transition-rules.md`) — no new
  row needed. The one same-state write found in this repo's skills,
  `spike-report/SKILL.md`'s "If the timebox expires with no conclusive
  answer" section, explicitly names itself "the `probing -> probing`
  self-loop" and requires the user to decide extend-vs-stop — already
  covered by the existing `probing | probing | user` row. No other
  `feasibility-cycle` skill (`reversibility-tag`, `feasibility-cycle`,
  `stride-table`, `license-scan`, `build-vs-buy`) documents a same-state
  `status` write.

- **review** (`review-cycle/hooks/transition-rules.md`) — no new row
  needed. Two same-state writes were found, both already covered:
  `finding-record/SKILL.md`'s "What it asks the user for" section
  describes asking the user for evidence/access mid-audit — the
  `auditing -> auditing` self-loop, covered by the existing
  `auditing | auditing | user` row; the same file's "In `draft-reported`,
  if the reviewed party disputes a finding..." section, and
  `severity-classification/SKILL.md`'s dispute-driven band adjustment,
  both describe the `draft-reported -> draft-reported` self-loop, covered
  by the existing `draft-reported | draft-reported | user` row.

- **ops** (`ops-cycle/hooks/transition-rules.md`) — no new row needed. The
  one same-state write found, `rollout-plan/SKILL.md`'s "How the
  agent-owned rows read it" section (the agent promoting a canary step on
  its own when a threshold check comes back clean, no human turn
  required), is already covered by the existing `rollout | rollout | agent`
  row.

Outside `product`, removing the short-circuit does not strand any
documented same-state step — the gate falls through to the row check,
finds the existing row, and allows. Inside `product`, it does, until the
`measuring | measuring` row above is added; this proposal now adds it. No
other new self-loop is added anywhere, and the hunt's earlier reproduction
state (`product`, `hypothesis-registered`) still has no self-loop row and
none is added for it here — same-state edits to a registered
metric/threshold there remain denied after this fix, exactly as intended.

**State-file tracking policy, applied identically in all four repos.** The
role's state file is a runtime artifact, not a design artifact, and is
gitignored in every repo:
- `feasibility-agent-rulebook/.gitignore` (ignores `feasibility-record.md`)
  and `ops-agent-rulebook/.gitignore` (ignores `ops/state.md`) already do
  this correctly; touched only to confirm the line stays present, no
  behavior change.
- `product-agent-rulebook/.gitignore` gains a line ignoring `product/state.md`.
- `review-agent-rulebook/.gitignore` gains a line ignoring the review
  record's default name, `review-record.md` (the name is overridable via
  `REVIEW_RECORD_NAME`, per `state-gate.sh`; the ignore line covers the
  shipped default, matching what the other three repos gitignore under
  their own hardcoded defaults).
- As a defensive step matching the existing comments in the
  feasibility/ops `.gitignore` files, each repo's build also runs `git rm
  --cached <state file>` for its own state-file path — a no-op if the path
  was never tracked, which `git ls-files` confirms is the case in all four
  repos today, but cheap insurance against a local checkout that added it
  by hand during testing.
- Rationale, one sentence: the gate judges the working-tree state, so a
  committed copy of the same file creates a second truth that can drift
  from what the gate is actually evaluating.

**Extend each repo's gate tests.** None of the four repos has an existing
gate test script (verified: no `*test*` file exists under any of the four
repo trees). Each repo gets a new `<role>-cycle/hooks/run-gate-tests.sh`
containing, at minimum, the case that would have caught this bug: a
`Write` to the state file that keeps the state field unchanged, while the
current state has no self-loop row for it, must be denied (non-zero exit).
The reproduction shape from the hunt record is the concrete case to encode
for `product` (`stage: hypothesis-registered` held fixed, `metric`/
`threshold` rewritten); each of the other three repos gets the equivalent
case built from its own carrying artifact and field names.

## Out of scope

- `coding-agent-rulebook` and `qa-agent-rulebook`.
- Any change to the artifact-producing skills (`one-pager`, `spike-report`,
  `finding-record`, `postmortem`, and the rest) — their writes are ungated
  today and remain ungated.
- The resolved-path binding rule itself (`2026-07-26-state-gate-path-resolution`).
- Any new transition beyond removing the same-state short-circuit and
  adding the single `measuring | measuring` row in `product-cycle`
  identified above — no other self-loop row is added or removed by this
  proposal, per the per-repo analysis above that every other legitimate
  same-state case already has one.

## How we will know it worked

- In all four repos, the new gate-test case — a `Write` to the state file
  holding the state field unchanged, on a state with no self-loop row —
  passes (i.e., the gate denies it, non-zero exit).
- The hunter's exact reproduction (rewriting `metric`/`threshold` on
  `product/state.md` while keeping `stage: hypothesis-registered`) is
  denied by `product-agent-rulebook/product-cycle/hooks/state-gate.sh`.
- Every pre-existing self-loop row (`scoping|scoping`, `probing|probing`,
  `auditing|auditing`, `draft-reported|draft-reported`, `rollout|rollout`)
  still passes its own gate test unchanged — the fix removes the
  short-circuit without regressing the rows that were already legal.
- `git status` in each of the four repos shows the role's state file
  untracked (or absent) after the build, and `git ls-files | grep -i
  state` / `grep -i record` returns nothing for it in any of the four
  repos.
- Every skill step that edits the state file in place while leaving the
  state field unchanged — `product-cycle/skills/hypothesis-testing/SKILL.md`
  step 5 (`measuring`), `feasibility-cycle/skills/spike-report/SKILL.md`'s
  timebox-extension step (`probing`), `review-cycle/skills/finding-record/SKILL.md`'s
  evidence-request step (`auditing`) and dispute-resolution step
  (`draft-reported`), `review-cycle/skills/severity-classification/SKILL.md`'s
  band-adjustment step (`draft-reported`), and
  `ops-cycle/skills/rollout-plan/SKILL.md`'s canary-promotion step
  (`rollout`) — is covered by a self-loop row in that repo's
  `transition-rules.md` after this build, so no documented skill step is
  denied by the fixed gate.

## What did not work

- 네 레포 모두 필요한 자기 루프 행을 이미 갖고 있다고 판단해 `transition-rules.md`를 쓰기 집합에서 뺐는데, after-proposal 헌터가 product의 `hypothesis-testing` 5단계(`status: measuring` 유지 상태에서 수집 데이터 추가)에 대응하는 `measuring | measuring` 행이 없음을 재현했다. 네 레포의 `transition-rules.md`를 쓰기 집합에 다시 넣었다.
- product와 review의 상태 파일이 추적 중이라고 판단해 `git rm --cached`를 계획에 넣었는데, 양쪽 모두 no-op이었다 — 네 레포 어디에서도 상태 파일은 추적된 적이 없다. 정책 통일은 `.gitignore` 라인 추가만으로 끝났다.
- product 게이트에서 상태 파일을 겨냥한 합법 전이의 `Bash` 쓰기가 허용될 것으로 보고 테스트 케이스를 썼는데, 게이트는 `Write`/`Edit`에만 결과 내용을 계산하므로 `Bash`는 합법성과 무관하게 "unrecognized tool Bash"로 거부된다. 스킬 문서상 의도된 설계이므로 테스트를 실제 보장(무관한 경로의 Bash 쓰기는 비게이트)으로 바꿔 썼다.
- before-landing 헌터: 상태 파일이 존재하면서 상태 값이 문자열 `(none)`이면 파일 없음과 구별되지 않아 `(none) → X` 부트스트랩 전이가 exit 0, 출력 없이 통과한다. 네 게이트 전부 같은 패턴. 미수정 — 기록: docs/reports/2026-07-29-hunt-same-state-gate-and-state-file-policy.md
