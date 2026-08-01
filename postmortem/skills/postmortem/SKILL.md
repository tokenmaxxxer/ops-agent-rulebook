---
name: postmortem
description: >-
  Use when working the ops role's incident state (ops/state.md status:
  incident) once the incident is over and a blameless postmortem is owed.
  Enforces Google's required trigger criteria and required sections, and
  incident.io's four named action-item failure patterns, as mechanical
  field checks. Writes ops/postmortem-<incident-id>.md from
  postmortem/templates/postmortem-template.md. Does NOT itself mark the
  postmortem "reviewed" — that human gate belongs to the
  incident -> steady row in transition-rules.md, not to this skill.
  Do NOT use for the live incident timeline itself (build that as the
  incident unfolds, before this skill runs) or for the rollout thresholds
  (rollout-plan).
---

# postmortem — the blameless incident writeup, and what NOT to self-certify

Belongs to the `incident` state, run once the incident is over. Writes
`ops/postmortem-<incident-id>.md` using
`postmortem/skills/postmortem/templates/postmortem-template.md` as the field
skeleton. Writing this file is never gated — it is not `ops/state.md`.

## Required trigger criteria (fixed before the fact, per Google's stated
rule, so there is no post-hoc argument about whether one is owed)

A postmortem is owed when any of: user-visible downtime/degradation beyond
a threshold, any data loss, on-call engineer intervention (rollback,
traffic reroute, etc.), resolution time above a threshold, or a monitoring
failure that meant the incident was discovered manually.
(`docs/reports/research/2026-07-27-role-practice/ops.md`.)

## Required sections (asked of the user, not invented)

1. **Impact** — what broke, for whom, how long.
2. **Actions taken** — what was done during the response, factually, drawn
   from the live incident timeline built during the incident itself.
3. **Root cause(s)**.
4. **Prevention / follow-up action items** — see the mechanical check
   below; this is the field the practice research names as the single most
   actionable, fully-sourced gate to enforce.

## The mechanical check on every action item (incident.io's four named
failure patterns, made into a field check)

Refuse to mark an action item complete unless it names:

- **One individual owner** — a named person, never a team. "The team
  should look into X" is not an assignment.
- **A tracking location outside this document** — an item living only in
  the postmortem file is invisible to sprint planning.
- **A stated closing/verification condition** — "improve monitoring" is not
  closeable because "improved" was never defined; state what "done" looks
  like.

An action item missing any of these three is not done — ask the user (or
whoever owns it) to supply the missing field before treating the
postmortem as complete.

## What this skill does NOT do — and what it does instead, while waiting

The agent does not declare an incident resolved, does not roll back, and
does not appoint an Incident Commander on its own. Every source the
interaction research found puts a human in sole authority over rollback,
IC appointment, and calling an incident formally resolved — PagerDuty's IC
model splits decision from execution precisely so a human retains that
call, and no source describes any of these three as automated.

That is not license to sit idle during an incident. While waiting for a
human to make those calls, the agent:

- Builds and maintains the live incident timeline in real time — timestamp,
  event/observation, actor, and (for decision points) what was decided and
  by whom — the factual backbone this postmortem is written from
  afterward. This is the one artifact explicitly described as assembled
  live, not after the fact.
- Surfaces symptom/metric evidence as it arrives, so the human deciding
  rollback/resolution has current information rather than a stale
  snapshot.
- If severity is ambiguous, treats it as the higher severity rather than
  stalling to resolve the ambiguity first — "round up, not stall" is the
  converging default across sources.
- If no IC has been appointed yet, does not wait for one to be assigned by
  someone else before doing the above — it keeps building the timeline
  regardless of who currently holds command.
- Once the human confirms resolution, runs this skill: drafts the
  postmortem, asks for impact/root cause/action items, and tells the user
  the draft is ready for review — it does not move `incident -> steady`
  itself; that is a gated `actor: user` row requiring the human to confirm
  the postmortem has actually been reviewed and is satisfactory, not merely
  that the file exists.
